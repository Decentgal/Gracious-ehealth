# --- 1. NETWORKING & VPC creation
resource "aws_vpc" "ehealth_vpc" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_support   = true
  enable_dns_hostnames = true
  tags = { Name = "gracy-ehealth-vpc" }
}

resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.ehealth_vpc.id
}

# Multi-AZ Subnets for High Availability
resource "aws_subnet" "public_a" {
  vpc_id                  = aws_vpc.ehealth_vpc.id
  cidr_block              = "10.0.1.0/24"
  availability_zone       = "us-east-1a"
  map_public_ip_on_launch = true
}

resource "aws_subnet" "public_b" {
  vpc_id                  = aws_vpc.ehealth_vpc.id
  cidr_block              = "10.0.2.0/24"
  availability_zone       = "us-east-1b"
  map_public_ip_on_launch = true
}

resource "aws_route_table" "public_rt" {
  vpc_id = aws_vpc.ehealth_vpc.id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw.id
  }
}

resource "aws_route_table_association" "a" {
  subnet_id      = aws_subnet.public_a.id
  route_table_id = aws_route_table.public_rt.id
}

resource "aws_route_table_association" "b" {
  subnet_id      = aws_subnet.public_b.id
  route_table_id = aws_route_table.public_rt.id
}

# --- 2. ENCRYPTION (NIST/HIPAA Compliant) ---
resource "aws_kms_key" "gracy_key" {
  description             = "Master key for Gracious e-health PHI encryption"
  deletion_window_in_days = 30
  enable_key_rotation     = true
  rotation_period_in_days = 90

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "Enable Root Account Permissions"
        Effect = "Allow"
        Principal = {
          AWS = "arn:aws:iam::996353668285:root"
        }
        Action   = "kms:*"
        Resource = "*"
      }
    ]
  })
}

resource "aws_kms_alias" "gracy_key_alias" {
  name          = "alias/gracy-health-key"
  target_key_id = aws_kms_key.gracy_key.id
}

resource "aws_secretsmanager_secret" "gracy_secrets" {
  name                    = "Gracy-App-Secrets-v4" # Incremented for fresh deployment
  description             = "Production credentials for e-health Application"
  kms_key_id              = aws_kms_key.gracy_key.arn
  recovery_window_in_days = 30 
}

# --- 3. ALB & SECURITY GROUP ---
resource "aws_security_group" "alb_sg" {
  name   = "gracy-alb-sg"
  vpc_id = aws_vpc.ehealth_vpc.id

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_lb" "ehealth_alb" {
  name               = "gracy-ehealth-alb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.alb_sg.id]
  subnets            = [aws_subnet.public_a.id, aws_subnet.public_b.id]
}

resource "aws_lb_target_group" "ehealth_tg" {
  name     = "gracy-tg"
  port     = 5000
  protocol = "HTTP"
  vpc_id   = aws_vpc.ehealth_vpc.id
}

resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.ehealth_alb.arn
  port              = "80"
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.ehealth_tg.arn
  }
}

# --- 4. WAF (Proactive Defense) ---
resource "aws_wafv2_web_acl" "ehealth_waf" {
  name        = "Gracy-Ehealth-WAF"
  description = "Blocks XSS and SQLi for HIPAA compliance"
  scope       = "REGIONAL"
  
  default_action { allow {} }

  rule {
    name     = "AWSManagedRulesCommonRuleSet"
    priority = 1
    override_action { none {} }
    statement {
      managed_rule_group_statement {
        name        = "AWSManagedRulesCommonRuleSet"
        vendor_name = "AWS"
      }
    }
    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "awsCommonRules"
      sampled_requests_enabled   = true
    }
  }

  visibility_config {
    cloudwatch_metrics_enabled = true
    metric_name                = "ehealthWAF"
    sampled_requests_enabled   = true
  }
}

resource "aws_wafv2_web_acl_association" "waf_alb_assoc" {
  resource_arn = aws_lb.ehealth_alb.arn
  web_acl_arn  = aws_wafv2_web_acl.ehealth_waf.arn
}