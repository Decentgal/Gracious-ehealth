# Gracy-App-Security-Policy
resource "aws_iam_policy" "app_runtime_policy" {
  name        = "Gracy-App-Security-Policy"
  description = "Least Privilege policy for e-health app and lifecycle management (S3 logging and Lambda function)"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "SecretsAndKMSAccess"
        Effect = "Allow"
        Action = [
          "secretsmanager:GetSecretValue",
          "secretsmanager:PutSecretValue",
          "kms:Decrypt",
          "kms:GenerateDataKey",
          "kms:DescribeKey"
        ]
        Resource = "*" 
      },
      {
        Sid    = "S3LoggingAccess"
        Effect = "Allow"
        Action = [
          "s3:PutObject",
          "s3:GetBucketLocation",
          "s3:ListBucket"
        ]
        Resource = [
          "arn:aws:s3:::gracy-ehealth-logs-*",
          "arn:aws:s3:::gracy-ehealth-logs-*/*"
        ]
      },
      {
        Sid    = "LambdaManagement"
        Effect = "Allow"
        Action = [
          "lambda:UpdateFunctionCode",
          "lambda:UpdateFunctionConfiguration",
          "lambda:GetFunction",
          "lambda:InvokeFunction",
          "lambda:AddPermission"
        ]
        Resource = "arn:aws:lambda:*:*:function:Gracy-Secret-Rotator"
      }
    ]
  })
}