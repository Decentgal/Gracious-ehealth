resource "aws_iam_policy" "app_runtime_policy" {
  name        = "Gracy-App-Runtime-Policy"
  description = "Least privilege access for the app"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid      = "AllowReadSecret"
        Effect   = "Allow"
        Action   = ["secretsmanager:GetSecretValue"]
        Resource = aws_secretsmanager_secret.gracy_secrets.arn
      },
      {
        Sid      = "AllowDecryptKMS"
        Effect   = "Allow"
        Action   = ["kms:Decrypt"]
        Resource = aws_kms_key.gracy_key.arn
      }
    ]
  })
}

output "kms_key_arn" { value = aws_kms_key.gracy_key.arn }
output "secret_arn"  { value = aws_secretsmanager_secret.gracy_secrets.arn }
