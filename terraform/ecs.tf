# Encrypt log data with KMS CMK: https://docs.aws.amazon.com/AmazonCloudWatch/latest/logs/encrypt-log-data-kms.html
resource "aws_cloudwatch_log_group" "hello_world" {
  kms_key_id        = aws_kms_key.primary.arn
  name              = "/ecs/${local.namespace}/hello-world"
  retention_in_days = 30
}

resource "aws_ecs_cluster" "cluster" {
  name = local.namespace
}

# ECR to hold our slightly customized Docker image
resource "aws_ecr_repository" "hello_world" {
  encryption_configuration {
    encryption_type = "KMS"
    kms_key         = aws_kms_key.primary.arn
  }

  image_scanning_configuration {
    scan_on_push = true
  }
  image_tag_mutability = "IMMUTABLE"

  name = "${local.namespace}/hello-world"
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
    condition {
      test     = "ArnLike"
      values   = ["arn:aws:ecs:${var.aws_region}:${local.account_id}:*"]
      variable = "aws:SourceArn"
    }
    condition {
      test     = "StringEquals"
      values   = [local.account_id]
      variable = "aws:SourceAccount"
    }
  }
}

resource "aws_iam_role" "ecs_task_execution" {
  name               = "${local.namespace}_ecs_task_execution"
  assume_role_policy = data.aws_iam_policy_document.ecs_task_assume_role.json
}

# Use the AWS-provided managed role for basic logging and ECR repository permissions
resource "aws_iam_role_policy_attachment" "hello_world_aws_task_execution_role_policy" {
  role       = aws_iam_role.ecs_task_execution.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

# Task definition for Hello World server featuring CloudWatch logs integration
resource "aws_ecs_task_definition" "hello_world" {
  # container_definitions = jsonencode([
  #   {
  #     # The same value is used for task and service because there is only one task.
  #     cpu = var.cpu
  #     # TODO: parameterize image and/or adjust for a customized container image
  #     image = "nginxdemos/hello:0.3"
  #     logConfiguration = {
  #       logDriver = "awslogs"
  #       options = {
  #         "awslogs-group" : aws_cloudwatch_log_group.hello_world.name
  #         "awslogs-region" : var.aws_region
  #         "awslogs-stream-prefix" : local.namespace
  #       }
  #     },
  #     # The same value is used for task and service because there is only one task.
  #     memory      = var.memory
  #     name        = "hello-world"
  #     networkMode = "FARGATE"
  #     portMappings = [
  #       {
  #         hostPort      = 80,
  #         containerPort = 80,
  #         protocol      = "tcp"
  #       }
  #     ]
  #   }
  # ])

  container_definitions = templatefile("${path.module}/templates/ecs-task-definition--hello-world.tpl", {
    cpu              = var.cpu
    git_sha          = data.external.git_checkout.result.sha
    memory           = var.memory
    namespace        = local.namespace
    log_group_name   = aws_cloudwatch_log_group.hello_world.name
    log_group_region = var.aws_region
    log_group_prefix = local.namespace
  })

  cpu                      = var.cpu
  execution_role_arn       = aws_iam_role.ecs_task_execution.arn
  family                   = "${local.namespace}-hello-world"
  memory                   = var.memory
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

  # Ignore changes to desired_count when autoscaling is configured
  lifecycle {
    ignore_changes = [desired_count]
  }

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

# Autoscaling
resource "aws_appautoscaling_target" "hello_world" {
  max_capacity       = 5
  min_capacity       = 1
  resource_id        = "service/${aws_ecs_cluster.cluster.name}/${aws_ecs_service.hello_world.name}"
  scalable_dimension = "ecs:service:DesiredCount"
  service_namespace  = "ecs"
}

resource "aws_appautoscaling_policy" "hello_world_memory" {
  name               = "${local.namespace}-hello-world-memory"
  policy_type        = "TargetTrackingScaling"
  resource_id        = aws_appautoscaling_target.hello_world.resource_id
  scalable_dimension = aws_appautoscaling_target.hello_world.scalable_dimension
  service_namespace  = aws_appautoscaling_target.hello_world.service_namespace

  target_tracking_scaling_policy_configuration {
    predefined_metric_specification {
      predefined_metric_type = "ECSServiceAverageMemoryUtilization"
    }

    # TODO: tune value for a "real" application
    target_value = 80
  }
}

resource "aws_appautoscaling_policy" "hello_world_cpu" {
  name               = "${local.namespace}-hello-world-cpu"
  policy_type        = "TargetTrackingScaling"
  resource_id        = aws_appautoscaling_target.hello_world.resource_id
  scalable_dimension = aws_appautoscaling_target.hello_world.scalable_dimension
  service_namespace  = aws_appautoscaling_target.hello_world.service_namespace

  target_tracking_scaling_policy_configuration {
    predefined_metric_specification {
      predefined_metric_type = "ECSServiceAverageCPUUtilization"
    }

    # TODO: tune value for a "real" application
    target_value = 60
  }
}
