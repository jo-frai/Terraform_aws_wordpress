output "web_public_ip" {
  description = "IP publique wp web"
  value       = aws_eip.wp_web_eip.public_ip
  depends_on = [aws_eip.wp_web_eip]
}

output "web_public_dns" {
  description = "DNS public wp web"
  value       = aws_eip.wp_web_eip.public_dns
  depends_on = [aws_eip.wp_web_eip]
}

output "database_endpoint" {
  description = "Endpoint de la BDD"
  value       = aws_db_instance.wp_database.address
}

output "database_port" {
  description = "Port de la BDD"
  value       = aws_db_instance.wp_database.port
}