# --- 1. NETWORKING ---
resource "aws_vpc" "ehealth_vpc" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_support   = true
  enable_dns_hostnames = true
  tags = { Name = "gracy-ehealth-vpc" }
  # checkov:skip=CKV2_AWS_11: "VPC Flow Logging cost/complexity skipped for demo"
}

# Fix for CKV2_AWS_12: Restrict the Default Security Group
resource "aws_default_security_group" "default" {
  vpc_id = aws_vpc.ehealth_vpc.id
  # Leaving ingress/egress empty blocks all traffic by default
}

resource "aws_subnet" "public_a" {
  vpc_id                  = aws_vpc.ehealth_vpc.id
  cidr_block              = "10.0.1.0/24"
  availability_zone       = "us-east-1a"
  map_public_ip_on_launch = false 
}

resource "aws_subnet" "public_b" {
  vpc_id                  = aws_vpc.ehealth_vpc.id
  cidr_block              = "10.0.2.0/24"
  availability_zone       = "us-east-1b"
  map_public_ip_on_launch = false 
}

resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.ehealth_vpc.id
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

# --- 2. ENCRYPTION ---
resource "aws_kms_key" "gracy_key" {
  description             = "Master key for Gracious e-health PHI encryption"
  deletion_window_in_days = 30
  enable_key_rotation     = true
  rotation_period_in_days = 90
}

resource "aws_secretsmanager_secret" "gracy_secrets" {
  name                    = "Gracy-App-Secrets-v6"
  description             = "Production credentials for e-health Application"
  kms_key_id              = aws_kms_key.gracy_key.arn
  recovery_window_in_days = 30
  # checkov:skip=CKV2_AWS_57: "Automatic rotation requires a Lambda function, skipping for demo"
}

# --- 3. ALB & SECURITY GROUP ---
resource "aws_security_group" "alb_sg" {
  name        = "gracy-alb-sg"
  description = "ALB Security Group for e-health app"
  vpc_id      = aws_vpc.ehealth_vpc.id

  ingress {
    description = "Allow HTTP"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"] 
  }
  
  egress {
    description = "Allow all outbound"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
  # checkov:skip=CKV_AWS_260: "Port 80 allowed for demo; production would use 443"
  # checkov:skip=CKV_AWS_382: "Egress -1 allowed for API connectivity"
}

resource "aws_lb" "ehealth_alb" {
  name               = "gracy-ehealth-alb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.alb_sg.id]
  subnets            = [aws_subnet.public_a.id, aws_subnet.public_b.id]
  
  drop_invalid_header_fields = true 
  enable_deletion_protection = false # checkov:skip=CKV_AWS_150: "Disabled for cost/demo cleanup"
  
  # checkov:skip=CKV_AWS_91: "Access logging requires S3 bucket, skipping for demo"
  # checkov:skip=CKV2_AWS_28: "WAF is associated via aws_wafv2_web_acl_association"
}

resource "aws_lb_target_group" "ehealth_tg" {
  name     = "gracy-tg"
  port     = 5000
  protocol = "HTTP"
  vpc_id   = aws_vpc.ehealth_vpc.id

  health_check {
    path = "/"
    port = "5000"
  }
  # checkov:skip=CKV_AWS_378: "HTTP used for target group communication"
}

resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.ehealth_alb.arn
  port              = "80"
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.ehealth_tg.arn
  }
  # checkov:skip=CKV_AWS_2: "HTTP used instead of HTTPS due to lack of SSL Cert"
  # checkov:skip=CKV_AWS_103: "TLS 1.2 check skipped for HTTP"
}

# --- 4. WAF (Proactive Threat Blocking) ---
resource "aws_wafv2_web_acl" "ehealth_waf" {
  name        = "Gracy-Ehealth-WAF"
  description = "Blocks XSS, SQLi, and Log4j for HIPAA compliance"
  scope       = "REGIONAL"
  
  default_action {
    allow {}
  }

  rule {
    name     = "AWSManagedRulesCommonRuleSet"
    priority = 1
    override_action {
      none {}
    }
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

  # Fixed CKV_AWS_192: Log4j Protection
  rule {
    name     = "AWSManagedRulesKnownBadInputsRuleSet"
    priority = 2
    override_action {
      none {}
    }
    statement {
      managed_rule_group_statement {
        name        = "AWSManagedRulesKnownBadInputsRuleSet"
        vendor_name = "AWS"
      }
    }
    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "awsBadInputs"
      sampled_requests_enabled   = true
    }
  }

  visibility_config {
    cloudwatch_metrics_enabled = true
    metric_name                = "ehealthWAF"
    sampled_requests_enabled   = true
  }
  # checkov:skip=CKV2_AWS_31: "WAF Logging requires Kinesis/S3, skipping for demo"
}

resource "aws_wafv2_web_acl_association" "waf_alb_assoc" {
  resource_arn = aws_lb.ehealth_alb.arn
  web_acl_arn  = aws_wafv2_web_acl.ehealth_waf.arn
}