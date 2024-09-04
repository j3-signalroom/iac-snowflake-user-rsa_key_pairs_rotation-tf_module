resource "aws_secretsmanager_secret" "public_keys" {
    name = "${local.root_secret_name}"
}

resource "aws_secretsmanager_secret_version" "public_keys" {
    secret_id     = aws_secretsmanager_secret.public_keys.id
    secret_string = jsonencode({"${root_secret_account_key}": "",
                                "${root_secret_user_key}": "",
                                "${root_secret_rsa_public_key_1}": "",
                                "${root_secret_rsa_public_key_2}": ""})
}

resource "aws_secretsmanager_secret" "private_key_1" {
    name = "${local.rsa_private_key_pem_1_branch_secret_name}"
}

resource "aws_secretsmanager_secret_version" "private_key_1" {
    secret_id     = aws_secretsmanager_secret.private_key_1.id
    secret_string = ""
}

resource "aws_secretsmanager_secret" "private_key_2" {
    name = "${local.rsa_private_key_pem_2_branch_secret_name}"
    description = "Kafka Cluster secrets"
}

resource "aws_secretsmanager_secret_version" "private_key_2" {
    secret_id     = aws_secretsmanager_secret.private_key_2.id
    secret_string = ""
}

resource "aws_iam_role" "generator_lambda" {
  name = "snowflake_rsa_key_pairs_generator_role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Action = "sts:AssumeRole",
        Effect = "Allow",
        Principal = {
          Service = "lambda.amazonaws.com"
        }
      }
    ]
  })
}

resource "aws_iam_policy" "generator_lambda_policy" {
  name        = "snowflake_rsa_key_pairs_generator_policy"
  description = "IAM policy for the Snowflake RSA key pairs Generator Lambda execution role."
  
  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ],
        Effect   = "Allow",
        Resource = "arn:aws:logs:*:*:*"
      },
      {
        Action = [
          "ecr:GetDownloadUrlForLayer",
          "ecr:BatchGetImage",
          "ecr:BatchCheckLayerAvailability"
        ],
        Effect   = "Allow",
        Resource = local.ecr_repo_uri
      },
      {
        Action = "ecr:GetAuthorizationToken",
        Effect = "Allow",
        Resource = "*"
      },
      {
        Action = "secretsmanager:*",
        Effect = "Allow",
        Resource = "*"
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "generator_lambda_policy_attachment" {
  role       = aws_iam_role.generator_lambda.name
  policy_arn = aws_iam_policy.generator_lambda_policy.arn
}

# Lambda function
resource "aws_lambda_function" "generator_lambda_function" {
  function_name = "snowflake_rsa_key_pairs_generator"
  role          = aws_iam_role.generator_lambda.arn
  package_type  = "Image"
  image_uri     = local.repo_uri
  memory_size   = var.aws_lambda_memory_size
  timeout       = var.aws_lambda_timeout
}

# Create a CloudWatch log group for the Lambda function
resource "aws_cloudwatch_log_group" "generator_lambda_function_log_group" {
  name              = "/aws/lambda/${aws_lambda_function.generator_lambda_function.function_name}"
  retention_in_days = var.aws_log_retention_in_days
}

# Lambda function invocation
resource "aws_lambda_invocation" "generator_lambda_function" {
  function_name = aws_lambda_function.generator_lambda_function.function_name

  input = jsonencode({
    user    = var.service_account_user
    account = var.snowflake_account
  })

  depends_on = [
    aws_secretsmanager_secret.public_keys,
    aws_secretsmanager_secret_version.public_keys,
    aws_secretsmanager_secret.private_key_1,
    aws_secretsmanager_secret_version.private_key_1,
    aws_secretsmanager_secret.private_key_2,
    aws_secretsmanager_secret_version.private_key_2    
  ]

  lifecycle {
    replace_triggered_by = [time_static.rsa_key_pair_rotations]
  }
}
