output "public_dns_name" {
  description = "Public DNS names of the load balancer for this project"
  value       = module.RabbitMQ-Cluster.alb_dns_name
}
output "rabbitmq_management_url" {
  description = "The URL to access the RabbitMQ Management Interface"
  value       = "http://${module.RabbitMQ-Cluster.alb_dns_name}:15672"
}

output "rabbitmq_admin_credentials" {
  description = "Credentials for the RabbitMQ Admin user"
  value       = "User: admin | Password: admin123"
}
