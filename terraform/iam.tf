resource "aws_iam_policy" "app_runtime_policy" {
  name        = "Gracy-App-Security-Policy"
  description = "Hardened Least Privilege policy for e-health app"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "ScopedSecretsAccess"
        Effect = "Allow"
        Action = [
          "secretsmanager:GetSecretValue",
          "secretsmanager:DescribeSecret"
        ]
        # Fixed CKV_AWS_355 & 288: Restricted to specific secret
        Resource = [aws_secretsmanager_secret.gracy_db_secret.arn]
      },
      {
        Sid    = "ScopedKMSAccess"
        Effect = "Allow"
        Action = [
          "kms:Decrypt",
          "kms:DescribeKey"
        ]
        # Fixed CKV_AWS_355 & 288: Restricted to specific key
        Resource = [aws_kms_key.gracy_key.arn]
      },
      {
        Sid    = "S3LoggingWriteOnly"
        Effect = "Allow"
        Action = [
          "s3:PutObject",
          "s3:GetBucketLocation"
        ]
        # Fixed CKV_AWS_290: Constrained write access to the log path
        Resource = [
          "${aws_s3_bucket.log_bucket.arn}/alb-logs/*",
          "${aws_s3_bucket.log_bucket.arn}/AWSLogs/*"
        ]
      }
    ]
  })
}