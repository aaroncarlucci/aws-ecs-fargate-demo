# Security group for the ALB accepting HTTP connections on port 80
#
# TODO: implement SSL encrypted traffic and redirect HTTP to HTTPS
resource "aws_security_group" "alb" {
  name   = "${local.namespace}-alb"
  vpc_id = aws_vpc.vpc.id
}

resource "aws_security_group_rule" "alb_ingress_http" {
  cidr_blocks       = ["0.0.0.0/0"]
  description       = "Allow public HTTP traffic"
  from_port         = 80
  ipv6_cidr_blocks  = ["::/0"]
  protocol          = "tcp"
  security_group_id = aws_security_group.alb.id
  to_port           = 80
  type              = "ingress"
}

resource "aws_security_group_rule" "alb_ingress_https" {
  cidr_blocks       = ["0.0.0.0/0"]
  description       = "Allow public HTTPS traffic"
  from_port         = 443
  ipv6_cidr_blocks  = ["::/0"]
  protocol          = "tcp"
  security_group_id = aws_security_group.alb.id
  to_port           = 443
  type              = "ingress"
}

resource "aws_security_group_rule" "alb_egress_all" {
  cidr_blocks       = ["0.0.0.0/0"]
  description       = "Allow all outbound traffic"
  from_port         = 0
  ipv6_cidr_blocks  = ["::/0"]
  protocol          = -1
  security_group_id = aws_security_group.alb.id
  to_port           = 0
  type              = "egress"
}

# Currently SSL is terminated at the ALB and traffic is unencrypted
#  inside the VPC.
#
# TODO: adopt "Encryption Everywhere" policy by protecting internal traffic
#  between the ALB and the application service as well (#15)
resource "aws_lb_target_group" "alb" {
  # name not specified as it creates conflicts when resource needs to be replaced. Depend
  #  on tags to identify target groups in the console.
  port        = 443
  protocol    = "HTTPS"
  target_type = "ip"

  health_check {
    # TODO: review health check
    enabled  = true
    path     = "/"
    port     = 443
    protocol = "HTTPS"
  }

  vpc_id = aws_vpc.vpc.id

  lifecycle {
    # For if/when ports change
    create_before_destroy = true
  }
}

resource "aws_lb" "alb" {
  name               = local.namespace
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.alb.id]
  subnets            = local.public_subnet_ids
}

# Redirect HTTP traffic to HTTPS
resource "aws_lb_listener" "alb" {
  default_action {
    redirect {
      port        = 443
      protocol    = "HTTPS"
      status_code = "HTTP_301"
    }
    type = "redirect"
  }

  load_balancer_arn = aws_lb.alb.id
  port              = 80
  protocol          = "HTTP"
}

resource "aws_lb_listener" "https" {
  certificate_arn = aws_acm_certificate_validation.cert.certificate_arn
  default_action {
    target_group_arn = aws_lb_target_group.alb.id
    type             = "forward"
  }

  load_balancer_arn = aws_lb.alb.id
  port              = 443
  protocol          = "HTTPS"
}

# Support the assigment of external certificates by ARN
resource "aws_lb_listener_certificate" "additional" {
  for_each = var.additional_certificate_arns

  listener_arn    = aws_lb_listener.https.arn
  certificate_arn = each.value
}
