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
  vpc_id            = aws_vpc.ehealth_vpc.id
  cidr_block        = "10.0.1.0/24"
  availability_zone = "us-east-1a"
}

resource "aws_subnet" "public_b" {
  vpc_id            = aws_vpc.ehealth_vpc.id
  cidr_block        = "10.0.2.0/24"
  availability_zone = "us-east-1b"
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
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Sid       = "Enable Root Account Permissions"
      Effect    = "Allow"
      Principal = { AWS = "arn:aws:iam::996353668285:root" }
      Action    = "kms:*"
      Resource  = "*"
    }]
  })
}

resource "aws_secretsmanager_secret" "gracy_db_secret" {
  name       = "Gracy-App-Secrets-v10"
  kms_key_id = aws_kms_key.gracy_key.arn
}

# --- 3. S3 LOGGING (Hardened for Production) ---
resource "random_id" "bucket_suffix" {
  byte_length = 4
}

resource "aws_s3_bucket" "log_bucket" {
  bucket        = "gracy-ehealth-logs-${random_id.bucket_suffix.hex}"
  force_destroy = true
}

resource "aws_s3_bucket_versioning" "log_versioning" {
  bucket = aws_s3_bucket.log_bucket.id
  versioning_configuration { status = "Enabled" }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "log_enc" {
  bucket = aws_s3_bucket.log_bucket.id
  rule {
    apply_server_side_encryption_by_default {
      # Resolves AWS-0132
      kms_master_key_id = aws_kms_key.gracy_key.arn
      sse_algorithm     = "aws:kms"
    }
  }
}

resource "aws_s3_bucket_lifecycle_configuration" "log_lifecycle" {
  bucket = aws_s3_bucket.log_bucket.id
  rule {
    id     = "log_retention"
    status = "Enabled"
    filter {}
    expiration { days = 90 }
    abort_incomplete_multipart_upload {
      days_after_initiation = 7
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
    Statement = [{
      Sid       = "AWSLogDeliveryWrite"
      Effect    = "Allow"
      Principal = { Service = "delivery.logs.amazonaws.com" }
      Action    = "s3:PutObject"
      Resource  = "${aws_s3_bucket.log_bucket.arn}/AWSLogs/*"
      Condition = { StringEquals = { "s3:x-amz-acl" = "bucket-owner-full-control" } }
    }]
  })
}

# --- 4. S3 EVENT TRIGGER ---
resource "aws_lambda_permission" "allow_bucket" {
  statement_id  = "AllowExecutionFromS3Bucket"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.rotator.function_name
  principal     = "s3.amazonaws.com"
  source_arn    = aws_s3_bucket.log_bucket.arn
}

resource "aws_s3_bucket_notification" "bucket_notification" {
  bucket = aws_s3_bucket.log_bucket.id
  lambda_function {
    lambda_function_arn = aws_lambda_function.rotator.arn
    events              = ["s3:ObjectCreated:*"]
    filter_prefix       = "AWSLogs/"
  }
  depends_on = [aws_lambda_permission.allow_bucket]
}

# --- 5. ALB & SECURITY GROUP (Hardened for Production) ---
resource "aws_security_group" "alb_sg" {
  name        = "gracy-alb-sg"
  vpc_id      = aws_vpc.ehealth_vpc.id
  description = "ALB Security Group"

  ingress {
    description = "Allow HTTP"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    description = "Restricted Egress to Internal VPC"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    # Resolves AWS-0104: Restricting egress to VPC CIDR
    cidr_blocks = ["10.0.0.0/16"] 
  }
}



resource "aws_lb" "ehealth_alb" {
  name               = "gracy-ehealth-alb"
  internal           = false 
  load_balancer_type = "application"
  security_groups    = [aws_security_group.alb_sg.id]
  subnets            = [aws_subnet.public_a.id, aws_subnet.public_b.id]
  
  # Resolves AWS-0052
  drop_invalid_header_fields = true 
  # High Availability production requirement
  enable_deletion_protection = true 

  access_logs {
    bucket  = aws_s3_bucket.log_bucket.id
    prefix  = "alb-logs"
    enabled = true
  }
}

resource "aws_lb_target_group" "ehealth_tg" {
  name     = "gracy-tg"
  port     = 5000
  protocol = "HTTP"
  vpc_id   = aws_vpc.ehealth_vpc.id
  
  health_check {
    enabled             = true
    path                = "/"
    port                = "traffic-port"
    protocol            = "HTTP"
    healthy_threshold   = 3
    unhealthy_threshold = 3
  }
}

resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.ehealth_alb.arn
  port              = "80"
  protocol          = "HTTP"

  # Resolves AWS-0054: Forces redirection to secure protocol
  default_action {
    type = "redirect"
    redirect {
      port        = "443"
      protocol    = "HTTPS"
      status_code = "HTTP_301"
    }
  }
}

# --- 6. LAMBDA & SQS ---
resource "aws_sqs_queue" "lambda_dlq" {
  name              = "gracy-lambda-dlq"
  kms_master_key_id = aws_kms_key.gracy_key.id
}

resource "aws_lambda_function" "rotator" {
  filename                       = "lambda_function_payload.zip"
  function_name                  = "Gracy-Secret-Rotator"
  role                           = aws_iam_role.lambda_rotator_role.arn
  handler                        = "index.handler"
  runtime                        = "python3.11"
  reserved_concurrent_executions = 2
  tracing_config { mode = "Active" }
  dead_letter_config { target_arn = aws_sqs_queue.lambda_dlq.arn }
}

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

resource "aws_secretsmanager_secret_rotation" "rotation" {
  secret_id           = aws_secretsmanager_secret.gracy_db_secret.id
  rotation_lambda_arn = aws_lambda_function.rotator.arn
  rotation_rules { automatically_after_days = 30 }
}

# --- 7. WEB APPLICATION FIREWALL (WAF) ---
resource "aws_wafv2_web_acl" "ehealth_waf" {
  name        = "Gracy-Ehealth-WAF"
  description = "Production WAF for healthcare app"
  scope       = "REGIONAL"
  
  default_action { 
    allow {} 
  }

  visibility_config {
    cloudwatch_metrics_enabled = true
    metric_name                = "ehealthWAF"
    sampled_requests_enabled   = true
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
}

resource "aws_wafv2_web_acl_association" "waf_alb_assoc" {
  resource_arn = aws_lb.ehealth_alb.arn
  web_acl_arn  = aws_wafv2_web_acl.ehealth_waf.arn
}