# Establish Trust with GitHub (No more static access keys, this is 2026 best practice)
resource "aws_iam_openid_connect_provider" "github" {
  url             = "https://token.actions.githubusercontent.com"
  client_id_list  = ["sts.amazonaws.com"]
  # Empty list allowed on your modern Terraform version
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
            # Verified for username: Decentgal
            "token.actions.githubusercontent.com:sub" = "repo:Decentgal/Gracious-ehealth:*"
          }
        }
      }
    ]
  })
}

# Attach Permissions
resource "aws_iam_role_policy_attachment" "admin_attach" {
  role       = aws_iam_role.github_oidc_role.name
  policy_arn = "arn:aws:iam::aws:policy/AdministratorAccess"
}

output "oidc_role_arn" {
  value = aws_iam_role.github_oidc_role.arn
}
