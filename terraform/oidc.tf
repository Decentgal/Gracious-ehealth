# Establish Trust with GitHub
resource "aws_iam_openid_connect_provider" "github" {
  url             = "https://token.actions.githubusercontent.com"
  client_id_list  = ["sts.amazonaws.com"]
  thumbprint_list = [] 
}

# Create the Role for your Pipeline
resource "aws_iam_role" "github_oidc_role" {
  name = "Gracy-GitHub-OIDC-Role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRoleWithWebIdentity"
        Effect = "Allow"
        Principal = {
          Federated = aws_iam_openid_connect_provider.github.arn
        }
        Condition = {
          StringLike = {
            "token.actions.githubusercontent.com:sub" = "repo:Decentgal/Gracious-ehealth:*"
          }
        }
      }
    ]
  })
}

# Attach Scoped Runtime Permissions (Fixed CKV_AWS_274)
resource "aws_iam_role_policy_attachment" "oidc_attach" {
  role       = aws_iam_role.github_oidc_role.name
  policy_arn = aws_iam_policy.app_runtime_policy.arn
}

output "oidc_role_arn" {
  value = aws_iam_role.github_oidc_role.arn
}