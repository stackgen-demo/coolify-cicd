variable "grafana_url" {
  description = "ObserveNow Grafana base URL."
  type        = string
  default     = "https://opsverse-demo-us.us-east4.gcp.opsverse.cloud"
}

variable "grafana_auth" {
  description = "Dedicated Grafana provisioning service-account token. Set with TF_VAR_grafana_auth."
  type        = string
  sensitive   = true
}

variable "metrics_datasource_uid" {
  type    = string
  default = "metrics"
}

variable "logs_datasource_uid" {
  type    = string
  default = "loki"
}

variable "jaeger_datasource_uid" {
  type    = string
  default = "jaeger"
}

variable "cloudwatch_datasource_uid" {
  type    = string
  default = "afimxw4vghbeoc"
}

variable "opsverse_metric_query" {
  description = "PromQL expression used by the host-health panel."
  type        = string
  default     = "up{job=~\".*opsverse.*\"}"
}
