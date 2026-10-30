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