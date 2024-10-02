locals {
  account_id = data.aws_caller_identity.current.account_id
  alb_ips    = [for v in aws_lb.alb.subnet_mapping : v.private_ipv4_address]
  default_tags = {
    Application = "aws-ecs-fargate-demo"
    Environment = var.environment
  }
  namespace          = "aws-ecs-fargate-demo-${var.environment}"
  private_subnet_ids = [aws_subnet.private_1.id, aws_subnet.private_2.id]
  public_subnet_ids  = [aws_subnet.public_1.id, aws_subnet.public_2.id]
}
