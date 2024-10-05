output "alb_dns_name" {
  description = "The application load balancer DNS name."
  value       = aws_lb.alb.dns_name
}

output "dns_name" {
  description = "The DNS name of the application."
  value       = var.dns_name
}

output "namespace" {
  description = "The namespace of the application."
  value       = local.namespace
}
