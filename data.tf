data "aws_caller_identity" "current" {}

locals {
    # Repo name and URIs
    repo_name           = "iac-snowflake-user-rsa_key_pairs_and_jwt_generator"
    repo_uri            = "${data.aws_caller_identity.current.account_id}.dkr.ecr.${var.aws_region}.amazonaws.com/${local.repo_name}:latest"
    ecr_repo_uri        = "arn:aws:ecr:${var.aws_region}:${data.aws_caller_identity.current.account_id}:repository/${local.repo_name}"
    
    now                 = timestamp()
    hour_count          = var.day_count*24

    # As of 2025-07-23, Snowflake only allows a max of two RSA key pairs that can be rotated for a given user
    key_pairs_to_retain = 2

    sorted_dates        = sort(time_rotating.rsa_key_pair_rotations.*.rfc3339)
    dates_and_count     = zipmap(time_rotating.rsa_key_pair_rotations.*.rfc3339, range(local.key_pairs_to_retain))
}
