output "poc_server_public_ip" {
  description = "IP publique du serveur POC (Phase 1 - pour migration)"
  value       = aws_instance.poc_server.public_ip
}

output "poc_server_private_ip" {
  description = "IP privee du serveur POC (utilisee dans Script-3 pour mysqldump)"
  value       = aws_instance.poc_server.private_ip
}

output "app_server_public_ip" {
  description = "IP publique du serveur app (Phase 2)"
  value       = aws_instance.app_server.public_ip
}

output "app_url" {
  description = "URL pour acceder a l application (Phase 2)"
  value       = "http://${aws_instance.app_server.public_ip}"
}

output "rds_endpoint" {
  description = "Endpoint RDS (utilise dans Script-1 et Script-3)"
  value       = aws_db_instance.mysql.address
}

output "cloud9_url" {
  description = "ID de l environnement Cloud9"
  value       = aws_cloud9_environment_ec2.cloud9.id
}

output "alb_url" {
  description = "URL de l application via l ALB (Phase 3)"
  value       = "http://${aws_lb.app.dns_name}"
}

output "ecr_repository_url" {
  description = "URL du repository ECR pour docker push (Phase 4)"
  value       = aws_ecr_repository.app.repository_url
}
