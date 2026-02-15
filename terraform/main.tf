# KMS Key  for PHI Encryption at rest (NIST/HIPAA Compliant)
resource "aws_kms_key" "gracy_key" {
  description             = "Master key for Gracious e-health PHI encryption"
  deletion_window_in_days = 30   # NIST 800-53 Best Practice
  enable_key_rotation     = true 
  rotation_period_in_days = 90   # NIST standard

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

# Secrets Manager (30-day recovery window for HIPAA compliance)
resource "aws_secretsmanager_secret" "gracy_secrets" {
  name        = "Gracy-App-Secrets-v3"
  description = "Production credentials for e-health Application"
  kms_key_id  = aws_kms_key.gracy_key.arn
  
  recovery_window_in_days = 30 # GDPR/ISO 27001 Availability standard
}
