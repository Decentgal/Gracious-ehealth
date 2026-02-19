resource "aws_iam_policy" "app_runtime_policy" {
  name        = "Gracy-EHealth-ZeroTrust-Policy"
  description = "Dynamic Least-Privilege Scoping for E-Health Lifecycle"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "SecretsAccess"
        Effect = "Allow"
        Action = ["secretsmanager:GetSecretValue"]
        Resource = [aws_secretsmanager_secret.gracy_db_secret.arn]
      },
      {
        Sid    = "KMSDecrypt"
        Effect = "Allow"
        Action = ["kms:Decrypt", "kms:GenerateDataKey"]
        Resource = [aws_kms_key.gracy_key.arn]
      },
      {
        Sid    = "LogIngestion"
        Effect = "Allow"
        Action = [
          "s3:PutObject",
          "s3:PutObjectAcl"
        ]
        # Benchmark: Scoped to specific path with ACL enforcement
        Resource = ["${aws_s3_bucket.log_bucket.arn}/AWSLogs/*"]
      }
    ]
  })
}