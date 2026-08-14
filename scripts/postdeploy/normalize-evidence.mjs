import fs from "node:fs";

const read = (path) => JSON.parse(fs.readFileSync(path, "utf8"));
const securityGroups = read("evidence/aws/security-groups.json").SecurityGroups ?? [];
const ec2SecurityGroup = securityGroups.find((group) => group.GroupId === process.env.EC2_SECURITY_GROUP_ID) ?? {};
const albSecurityGroup = securityGroups.find((group) => group.GroupId === process.env.ALB_SECURITY_GROUP_ID) ?? {};
const listeners = read("evidence/aws/listeners.json").Listeners ?? [];
const waf = read("evidence/aws/waf.json");
const ports = read("evidence/network/ports.json");
const https = read("evidence/http/https.json");
const wafProbe = read("evidence/http/waf.json");
const authentication = read("evidence/http/authentication.json");
const observability = read("evidence/observability/status.json");

const ingress = ec2SecurityGroup.IpPermissions ?? [];
const egress = ec2SecurityGroup.IpPermissionsEgress ?? [];
const albIngress = albSecurityGroup.IpPermissions ?? [];
const albEgress = albSecurityGroup.IpPermissionsEgress ?? [];
const managementPortPublic = ingress.some((rule) => {
  const from = rule.FromPort ?? -1;
  const to = rule.ToPort ?? -1;
  const management = [22, 8000].some((port) => from <= port && port <= to);
  const publicRange = (rule.IpRanges ?? []).some((range) => range.CidrIp === "0.0.0.0/0");
  return management && publicRange;
});
const ingressFromAlbOnly =
  ingress.length > 0 &&
  ingress.every((rule) => {
    const sourceGroups = (rule.UserIdGroupPairs ?? []).map((pair) => pair.GroupId);
    return (
      sourceGroups.length > 0 &&
      sourceGroups.every((groupId) => groupId === process.env.ALB_SECURITY_GROUP_ID) &&
      rule.IpProtocol === "tcp" &&
      rule.FromPort === 3000 &&
      rule.ToPort === 3000 &&
      (rule.IpRanges ?? []).length === 0 &&
      (rule.Ipv6Ranges ?? []).length === 0
    );
  });
const egressRestricted = egress.length === 3 && egress.every((rule) => {
  const from = rule.FromPort ?? -1;
  const to = rule.ToPort ?? -1;
  const ranges = rule.IpRanges ?? [];
  const hasNoOtherDestinations = (rule.Ipv6Ranges ?? []).length === 0 && (rule.UserIdGroupPairs ?? []).length === 0;
  const httpsAllowed =
    rule.IpProtocol === "tcp" && from === 443 && to === 443 && ranges.length === 1 && ranges[0].CidrIp === "0.0.0.0/0";
  const internalDnsAllowed =
    ["tcp", "udp"].includes(rule.IpProtocol) &&
    from === 53 &&
    to === 53 &&
    ranges.length === 1 &&
    ranges[0].CidrIp !== "0.0.0.0/0";
  return hasNoOtherDestinations && (httpsAllowed || internalDnsAllowed);
});
const albIngressRestricted =
  albIngress.length === 2 &&
  albIngress.every((rule) =>
    rule.IpProtocol === "tcp" &&
    [80, 443].includes(rule.FromPort) &&
    rule.FromPort === rule.ToPort &&
    (rule.IpRanges ?? []).every((range) => range.CidrIp === "0.0.0.0/0") &&
    (rule.Ipv6Ranges ?? []).length === 0 &&
    (rule.UserIdGroupPairs ?? []).length === 0
  );
const albEgressRestricted =
  albEgress.length === 1 &&
  albEgress.every((rule) => {
    const destinationGroups = (rule.UserIdGroupPairs ?? []).map((pair) => pair.GroupId);
    return (
      rule.IpProtocol === "tcp" &&
      rule.FromPort === 3000 &&
      rule.ToPort === 3000 &&
      destinationGroups.length === 1 &&
      destinationGroups[0] === process.env.EC2_SECURITY_GROUP_ID &&
      (rule.IpRanges ?? []).length === 0 &&
      (rule.Ipv6Ranges ?? []).length === 0
    );
  });
const listenerPorts = listeners.map((listener) => listener.Port).sort();

const normalized = {
  demo_run_id: process.env.DEMO_RUN_ID,
  image_digest: process.env.DEMO_IMAGE_DIGEST,
  source_commit_sha: process.env.SOURCE_COMMIT_SHA,
  deployment_uuid: process.env.DEPLOYMENT_UUID,
  network: ports,
  https: { ...https, listener_ports: listenerPorts },
  waf: wafProbe,
  authentication,
  aws: {
    alb_egress_restricted: albEgressRestricted,
    alb_ingress_restricted: albIngressRestricted,
    egress_restricted: egressRestricted,
    ingress_from_alb_only: ingressFromAlbOnly,
    management_port_public: managementPortPublic,
    waf_attached: Boolean(waf.WebACL?.ARN),
  },
  collectors: {
    application_otel_healthy: observability.correlation_complete,
    opsverse_agent_healthy: observability.opsverse_agent_healthy,
  },
  observability,
};

fs.writeFileSync("evidence/postdeploy.json", `${JSON.stringify(normalized, null, 2)}\n`, { mode: 0o600 });
