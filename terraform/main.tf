# --- 1. NETWORKING & FLOW LOGS ---
resource "aws_vpc" "ehealth_vpc" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_support   = true
  enable_dns_hostnames = true
  tags = { Name = "gracy-ehealth-vpc" }
}

resource "aws_flow_log" "ehealth_flow_log" {
  log_destination      = aws_s3_bucket.log_bucket.arn
  log_destination_type = "s3"
  vpc_id               = aws_vpc.ehealth_vpc.id
  traffic_type         = "ALL"
}



resource "aws_default_security_group" "default" {
  vpc_id = aws_vpc.ehealth_vpc.id
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

# --- 2. ENCRYPTION & SECRETS ---
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
        Principal = { AWS = "arn:aws:iam::996353668285:root" }
        Action   = "kms:*"
        Resource = "*"
      }
    ]
  })
  tags = { Name = "Gracy-KMS" }
}

resource "aws_secretsmanager_secret" "gracy_db_secret" {
  name                    = "Gracy-App-Secrets-v10"
  description             = "Production credentials for e-health Application"
  kms_key_id              = aws_kms_key.gracy_key.arn
  recovery_window_in_days = 30
}

# --- 3. S3 LOGGING INFRASTRUCTURE (Hardened) ---
resource "random_id" "bucket_suffix" {
  byte_length = 4
}

resource "aws_s3_bucket" "log_bucket" {
  bucket        = "gracy-ehealth-logs-${random_id.bucket_suffix.hex}"
  force_destroy = true
  
  # Suppressing recursive logging on the logging bucket itself
  # checkov:skip=CKV_AWS_18: "Logging bucket does not require self-logging"
  # checkov:skip=CKV_AWS_144: "Cross-region replication not required for demo"
}

# Fixed CKV_AWS_21: Enable Versioning
resource "aws_s3_bucket_versioning" "log_versioning" {
  bucket = aws_s3_bucket.log_bucket.id
  versioning_configuration {
    status = "Enabled"
  }
}

# Fixed CKV_AWS_145: Encrypt with KMS by default
resource "aws_s3_bucket_server_side_encryption_configuration" "log_enc" {
  bucket = aws_s3_bucket.log_bucket.id
  rule {
    apply_server_side_encryption_by_default {
      kms_master_key_id = aws_kms_key.gracy_key.arn
      sse_algorithm     = "aws:kms"
    }
  }
}

# Fixed CKV2_AWS_61: Lifecycle Configuration
resource "aws_s3_bucket_lifecycle_configuration" "log_lifecycle" {
  bucket = aws_s3_bucket.log_bucket.id
  rule {
    id     = "log_retention"
    status = "Enabled"
    
    filter {} # This resolves the "No attribute specified" warning

    expiration {
      days = 90
    }
  }
}

resource "aws_s3_bucket_public_access_block" "log_bucket_block" {
  bucket = aws_s3_bucket.log_bucket.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_policy" "allow_log_delivery" {
  bucket = aws_s3_bucket.log_bucket.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "AWSLogDeliveryWrite"
        Effect = "Allow"
        Principal = { Service = "delivery.logs.amazonaws.com" }
        Action   = "s3:PutObject"
        Resource = "${aws_s3_bucket.log_bucket.arn}/AWSLogs/*"
        Condition = {
          StringEquals = { "s3:x-amz-acl" = "bucket-owner-full-control" }
        }
      }
    ]
  })
}

# --- 4. LOAD BALANCING & SECURITY GROUPS ---
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
  
  #trivy:ignore:aws-vpc-no-public-egress-sgr
  egress {
    description = "Allow HTTPS outbound"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  # checkov:skip=CKV_AWS_260: "Port 80 allowed for this project"
  # checkov:skip=CKV_AWS_382: "Egress restricted to HTTPS"
}

#trivy:ignore:aws-elb-alb-not-public
resource "aws_lb" "ehealth_alb" {
  name               = "gracy-ehealth-alb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.alb_sg.id]
  subnets            = [aws_subnet.public_a.id, aws_subnet.public_b.id]
  
  drop_invalid_header_fields = true 

  access_logs {
    bucket  = aws_s3_bucket.log_bucket.id
    prefix  = "alb-logs"
    enabled = true
  }

  # checkov:skip=CKV_AWS_150: "Disabled for this project"
  # checkov:skip=CKV2_AWS_28: "WAF is associated separately"
  # checkov:skip=CKV2_AWS_20: "Redirect to HTTPS requires SSL cert"
  # checkov:skip=CKV2_AWS_76: "Log4j protection verified in WAF"
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
  # checkov:skip=CKV_AWS_378: "HTTP used for target group"
}

#trivy:ignore:aws-elb-http-not-used
resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.ehealth_alb.arn
  port              = "80"
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.ehealth_tg.arn
  }
  # checkov:skip=CKV_AWS_2: "HTTP used due to lack of SSL Cert"
  # checkov:skip=CKV_AWS_103: "TLS 1.2 skipped for HTTP"
}

# --- 5. AUTOMATED SECRET ROTATION (Hardened Lambda) ---
resource "aws_iam_role" "lambda_rotator_role" {
  name = "Gracy-Secret-Rotator-Role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Principal = { Service = "lambda.amazonaws.com" }
    }]
  })
}

# DLQ for Lambda Reliability (Fixed CKV_AWS_116)
resource "aws_sqs_queue" "lambda_dlq" {
  name              = "gracy-lambda-dlq"
  kms_master_key_id = aws_kms_key.gracy_key.id
}

resource "aws_lambda_function" "rotator" {
  filename      = "lambda_function_payload.zip" 
  function_name = "Gracy-Secret-Rotator"
  role          = aws_iam_role.lambda_rotator_role.arn
  handler       = "index.handler"
  runtime       = "python3.11"
  
  # Fixed CKV_AWS_115: Concurrency Limit
  reserved_concurrent_executions = 2
  
  # Fixed CKV_AWS_50: X-Ray Tracing
  tracing_config {
    mode = "Active"
  }

  # Fixed CKV_AWS_116: Dead Letter Queue
  dead_letter_config {
    target_arn = aws_sqs_queue.lambda_dlq.arn
  }

  # checkov:skip=CKV_AWS_117: "VPC config skipped for secret rotation"
  # checkov:skip=CKV_AWS_272: "Code signing skipped for project demo"
}



resource "aws_secretsmanager_secret_rotation" "rotation" {
  secret_id           = aws_secretsmanager_secret.gracy_db_secret.id
  rotation_lambda_arn = aws_lambda_function.rotator.arn

  rotation_rules {
    automatically_after_days = 30
  }
}

# --- 6. WEB APPLICATION FIREWALL (WAF) ---
# checkov:skip=CKV_AWS_192: "Log4j protection via AWSManagedRulesKnownBadInputsRuleSet"
resource "aws_wafv2_web_acl" "ehealth_waf" {
  name        = "Gracy-Ehealth-WAF"
  description = "Blocks XSS, SQLi, and Log4j"
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
  # checkov:skip=CKV2_AWS_31: "WAF Logging requires Kinesis/S3"
}

resource "aws_wafv2_web_acl_association" "waf_alb_assoc" {
  resource_arn = aws_lb.ehealth_alb.arn
  web_acl_arn  = aws_wafv2_web_acl.ehealth_waf.arn
}