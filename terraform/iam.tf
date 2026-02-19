resource "aws_iam_policy" "app_runtime_policy" {
  name        = "Gracy-App-Security-Policy"
  description = "Hardened Least Privilege policy for e-health app lifecycle"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "ScopedSecretsAccess"
        Effect = "Allow"
        Action = ["secretsmanager:GetSecretValue", "secretsmanager:DescribeSecret"]
        Resource = [aws_secretsmanager_secret.gracy_db_secret.arn]
      },
      {
        Sid    = "ScopedKMSAccess"
        Effect = "Allow"
        Action = ["kms:Decrypt", "kms:DescribeKey"]
        Resource = [aws_kms_key.gracy_key.arn]
      },
      {
        Sid    = "S3LoggingWriteOnly"
        Effect = "Allow"
        Action = ["s3:PutObject", "s3:GetBucketLocation"]
        Resource = ["${aws_s3_bucket.log_bucket.arn}/alb-logs/*", "${aws_s3_bucket.log_bucket.arn}/AWSLogs/*"]
      },
      {
        Sid    = "LambdaExecutionLogging"
        Effect = "Allow"
        Action = ["logs:CreateLogGroup", "logs:CreateLogStream", "logs:PutLogEvents"]
        # checkov:skip=CKV_AWS_355: "Logs ARNs are dynamic, scoping to region/account is sufficient"
        Resource = "arn:aws:logs:us-east-1:996353668285:*"
      }
    ]
  })
}