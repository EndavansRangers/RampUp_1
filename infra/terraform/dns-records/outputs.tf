output "app_url" {
  description = "Frontend application URL"
  value       = "https://app.dev.tunefy.site"
}

output "grafana_url" {
  description = "Grafana monitoring URL"
  value       = "https://grafana.dev.tunefy.site"
}

output "dns_records_created" {
  description = "DNS records created"
  value = {
    app     = aws_route53_record.app.fqdn
    grafana = aws_route53_record.grafana.fqdn
  }
}
