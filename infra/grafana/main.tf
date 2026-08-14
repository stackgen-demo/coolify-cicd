resource "grafana_folder" "demo" {
  title = "Talkdesk Secure Delivery Demo"
}

resource "grafana_dashboard" "demo" {
  folder    = grafana_folder.demo.id
  overwrite = true
  config_json = templatefile("${path.module}/dashboards/demo.json.tftpl", {
    cloudwatch_uid      = var.cloudwatch_datasource_uid
    jaeger_uid          = var.jaeger_datasource_uid
    loki_uid            = var.logs_datasource_uid
    metrics_uid         = var.metrics_datasource_uid
    opsverse_query_json = jsonencode(var.opsverse_metric_query)
  })
}

resource "grafana_rule_group" "demo" {
  name             = "Talkdesk demo application health"
  folder_uid       = grafana_folder.demo.uid
  interval_seconds = 60

  rule {
    name           = "Talkdesk demo 5xx responses"
    condition      = "C"
    for            = "5m"
    no_data_state  = "OK"
    exec_err_state = "Error"

    annotations = {
      summary = "The Talkdesk demo application is returning HTTP 5xx responses."
    }

    labels = {
      service  = "talkdesk-coolify-demo"
      severity = "warning"
    }

    data {
      ref_id         = "A"
      datasource_uid = var.metrics_datasource_uid
      relative_time_range {
        from = 600
        to   = 0
      }
      model = jsonencode({
        editorMode    = "code"
        expr          = "sum(rate(talkdesk_demo_http_requests_total{http_response_status_code=~\"5..\"}[5m]))"
        instant       = false
        intervalMs    = 1000
        legendFormat  = "5xx rate"
        maxDataPoints = 43200
        range         = true
        refId         = "A"
      })
    }

    data {
      ref_id         = "B"
      datasource_uid = "__expr__"
      relative_time_range {
        from = 0
        to   = 0
      }
      model = jsonencode({
        conditions = [{
          evaluator = { params = [], type = "gt" }
          operator  = { type = "and" }
          query     = { params = ["B"] }
          reducer   = { params = [], type = "last" }
          type      = "query"
        }]
        datasource = { type = "__expr__", uid = "__expr__" }
        expression = "A"
        reducer    = "last"
        refId      = "B"
        type       = "reduce"
      })
    }

    data {
      ref_id         = "C"
      datasource_uid = "__expr__"
      relative_time_range {
        from = 0
        to   = 0
      }
      model = jsonencode({
        conditions = [{
          evaluator = { params = [0], type = "gt" }
          operator  = { type = "and" }
          query     = { params = ["C"] }
          reducer   = { params = [], type = "last" }
          type      = "query"
        }]
        datasource = { type = "__expr__", uid = "__expr__" }
        expression = "B"
        refId      = "C"
        type       = "threshold"
      })
    }
  }
}
