terraform {
    cloud {
        organization ="signalroom"

        workspaces {
            name = "snowflake-resources-workspace"
        }
  }

  required_providers {
        aws = {
            source  = "hashicorp/aws"
            version = "~> 5.66.0"
        }
    }
}

locals {
    # Repo name and URIs
    repo_name    = "iac-snowflake-user-rsa_key_pairs_generator"
    repo_uri     = "${var.aws_account_id}.dkr.ecr.${var.aws_region}.amazonaws.com/${local.repo_name}:latest"
    ecr_repo_uri = "arn:aws:ecr:${var.aws_region}:${var.aws_account_id}:repository/${local.repo_name}"

    now        = timestamp()
    hour_count = var.day_count*24

    # As of 2024-08-28, Snowflake only allows a max of two RSA key pairs that can be rotated for a given user
    number_of_rsa_key_pairs_to_retain = 2

    sorted_dates                 = sort(time_rotating.rsa_key_pair_rotations.*.rfc3339)
    dates_and_count              = zipmap(time_rotating.rsa_key_pair_rotations.*.rfc3339, range(local.number_of_rsa_key_pairs_to_retain))
    latest_rsa_public_key_number = lookup(local.dates_and_count, local.sorted_dates[0])
}
