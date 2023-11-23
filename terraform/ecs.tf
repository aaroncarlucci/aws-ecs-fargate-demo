resource "aws_cloudwatch_log_group" "hello_world" {
  # TODO: add KMS policy to key and associate for encryption:
  #  https://docs.aws.amazon.com/AmazonCloudWatch/latest/logs/encrypt-log-data-kms.html
  # kms_key_id = aws_kms_key.primary.arn
  name              = "/ecs/${local.namespace}/hello-world"
  retention_in_days = 30
}

resource "aws_ecs_cluster" "cluster" {
  name = local.namespace
}

# Task execution assumed role
data "aws_iam_policy_document" "ecs_task_assume_role" {
  statement {
    actions = ["sts:AssumeRole"]
    effect  = "Allow"
    principals {
      identifiers = ["ecs-tasks.amazonaws.com"]
      type        = "Service"
    }
  }
}

resource "aws_iam_role" "ecs_task_execution" {
  name               = "${local.namespace}_ecs_task_execution"
  assume_role_policy = data.aws_iam_policy_document.ecs_task_assume_role.json
}

# Use the AWS-provided managed role for basic logging and ECR repository permissions
resource "aws_iam_role_policy_attachment" "legacy_listener_aws_task_execution_role_policy" {
  role       = aws_iam_role.ecs_task_execution.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

# Task definition featuring
#  * CloudWatch logs integration
resource "aws_ecs_task_definition" "hello_world" {
  container_definitions = jsonencode([
    {
      # TODO: parameterize cpu, or remove this value because it is not required
      #  for Fargate containers when assigned at the task level and we only have one task
      cpu = 256
      # TODO: specify image tag and eventually parameterize
      image = "nginx"
      logConfiguration = {
        logDriver = "awslogs"
        options = {
          "awslogs-group" : aws_cloudwatch_log_group.hello_world.name
          "awslogs-region" : var.aws_region
          "awslogs-stream-prefix" : local.namespace
        }
      },
      # TODO: parameterize memory, or remove this value because it is not required
      #  for Fargate containers when assigned at the task level and we only have one task
      memory      = 512
      name        = "hello-world"
      networkMode = "FARGATE"
      portMappings = [
        {
          hostPort      = 80,
          containerPort = 80,
          protocol      = "tcp"
        }
      ]
    }
  ])

  # TODO: parameterize cpu
  cpu                = 256
  execution_role_arn = aws_iam_role.ecs_task_execution.arn
  family             = "${local.namespace}-hello-world"
  # TODO: parameterize memory
  memory                   = 512
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
}

# Security group for the hello-world ECS service accepts HTTP
#  connections from the ALB security group
resource "aws_security_group" "app" {
  name   = "${local.namespace}-app"
  vpc_id = aws_vpc.vpc.id
}

resource "aws_security_group_rule" "app_ingress_http" {
  description              = "Allow HTTP from ALB"
  from_port                = 80
  protocol                 = "tcp"
  security_group_id        = aws_security_group.app.id
  source_security_group_id = aws_security_group.alb.id
  to_port                  = 80
  type                     = "ingress"
}

resource "aws_security_group_rule" "app_egress_all" {
  cidr_blocks       = ["0.0.0.0/0"]
  description       = "Allow all outbound traffic"
  from_port         = 0
  ipv6_cidr_blocks  = ["::/0"]
  protocol          = -1
  security_group_id = aws_security_group.app.id
  to_port           = 0
  type              = "egress"
}

# Hello World ECS service
resource "aws_ecs_service" "hello_world" {
  name = "${local.namespace}-hello-world"

  cluster       = aws_ecs_cluster.cluster.id
  desired_count = 1
  launch_type   = "FARGATE"

  # TODO: consider service encrypted internal traffic between
  #  ALB and ECS container on 443 - requires self-signed cert
  load_balancer {
    target_group_arn = aws_lb_target_group.alb.arn
    container_name   = "hello-world"
    container_port   = 80
  }

  network_configuration {
    security_groups = [aws_security_group.app.id]
    subnets         = local.private_subnet_ids
  }

  task_definition = aws_ecs_task_definition.hello_world.arn
}
