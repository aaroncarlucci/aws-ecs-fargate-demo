locals {
  account_id       = data.aws_caller_identity.current.account_id
  alb_ips          = [for v in aws_lb.alb.subnet_mapping : v.private_ipv4_address]
  application_name = "aws-ecs-fargate-demo"
  default_tags = {
    Application = local.application_name
    Environment = var.environment
  }
  ecs_hello_world_image = "${aws_ecr_repository.hello_world.repository_url}:${var.image_tag}"
  namespace             = "${local.application_name}-${var.environment}"
  private_subnet_ids    = [aws_subnet.private_1.id, aws_subnet.private_2.id]
  public_subnet_ids     = [aws_subnet.public_1.id, aws_subnet.public_2.id]
}
