output "dashboard_uid" {
  value = grafana_dashboard.demo.uid
}

output "dashboard_url" {
  value = "${var.grafana_url}/d/${grafana_dashboard.demo.uid}"
}

output "folder_uid" {
  value = grafana_folder.demo.uid
}
