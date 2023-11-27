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

output "test_task_def_tpl" {
  value = templatefile("${path.module}/templates/ecs-task-definition--hello-world.tpl", {
    cpu              = var.cpu
    git_sha          = data.external.git_checkout.result.sha
    memory           = var.memory
    namespace        = local.namespace
    log_group_name   = aws_cloudwatch_log_group.hello_world.name
    log_group_region = var.aws_region
    log_group_prefix = local.namespace
  })
}

output "git_sha" {
  value = data.external.git_checkout.result.sha
}
