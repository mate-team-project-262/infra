output "instance_id" {
  description = "ID of the provisioned EC2 instance"
  value       = aws_instance.app_server.id
}

output "public_ip" {
  description = "Static Elastic IPv4 address of the EC2 instance"
  value       = aws_eip.app_eip.public_ip
}

output "public_dns" {
  description = "Public DNS name of the EC2 instance"
  value       = aws_eip.app_eip.public_dns
}

output "ssh_connection_command" {
  description = "Command to connect to the instance via SSH"
  value       = "ssh -i ~/.ssh/id_ed25519 ubuntu@${aws_eip.app_eip.public_ip}"
}

output "mysql_host" {
  description = "RDS hostname without port (use this value for MYSQL_HOST in .env)"
  value       = aws_db_instance.mysql.address
}

output "mysql_endpoint" {
  description = "Full RDS connection endpoint (hostname:port)"
  value       = aws_db_instance.mysql.endpoint
}

output "app_private_ip" {
  description = "Private VPC IPv4 of the App server (use as target in prometheus.yml)"
  value       = aws_instance.app_server.private_ip
}

output "monitoring_instance_id" {
  description = "ID of the Monitoring EC2 instance (add to aws-power-schedule.yml)"
  value       = aws_instance.monitoring_server.id
}

output "monitoring_public_ip" {
  description = "Public IPv4 address of the Monitoring EC2 instance"
  value       = aws_instance.monitoring_server.public_ip
}

output "grafana_url" {
  description = "URL to access Grafana Dashboard"
  value       = "http://${aws_instance.monitoring_server.public_ip}:3000/"
}

output "uptime_kuma_url" {
  description = "URL to access Uptime Kuma Status & Alerting UI"
  value       = "http://${aws_instance.monitoring_server.public_ip}:3001/"
}