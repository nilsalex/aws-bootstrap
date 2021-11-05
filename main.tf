terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 3.63"
    }
  }
}

provider "aws" {
  region = "eu-central-1"

  default_tags {
    tags = {
      Terraform = "Bootstrap"
    }
  }
}

resource "aws_s3_bucket" "terraform_state_bucket" {
  bucket = "nalex-state-bucket"
  acl    = "private"

  versioning {
    enabled = true
  }
}

resource "aws_s3_bucket_public_access_block" "terraform_state_bucket" {
  bucket = aws_s3_bucket.terraform_state_bucket.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_dynamodb_table" "terraform_lock_table" {
  name         = "state-lock-table"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "LockID"
  attribute {
    name = "LockID"
    type = "S"
  }
}

resource "aws_iam_user" "nils" {
  name = "nils"
}

data "aws_iam_policy_document" "manage_own_access_keys" {
  statement {
    sid = "ManageOwnAccessKeys"
    actions = [
      "iam:CreateAccessKey",
      "iam:DeleteAccessKey",
      "iam:GetAccessKeyLastUsed",
      "iam:GetUser",
      "iam:ListAccessKeys",
      "iam:UpdateAccessKey",
      "iam:ListMFADevices",
      "iam:CreateVirtualMFADevice",
      "iam:DeleteVirtualMFADevice",
      "iam:ListVirtualMFADevices",
      "iam:DeactivateMFADevice",
      "iam:EnableMFADevice",
      "iam:ResyncMFADevice",
    ]
    resources = [
      "arn:aws:iam::*:user/$${aws:username}",
      "arn:aws:iam::*:mfa/$${aws:username}",
    ]
  }
}

resource "aws_iam_user_policy" "manage_own_access_keys" {
  name   = "ManageOwnAccessKeys"
  user   = aws_iam_user.nils.name
  policy = data.aws_iam_policy_document.manage_own_access_keys.json
}


data "aws_iam_policy_document" "administrator_assume_role_policy" {
  statement {
    actions = ["sts:AssumeRole"]
    effect  = "Allow"
    principals {
      type        = "AWS"
      identifiers = [aws_iam_user.nils.arn]
    }
    condition {
      test     = "Bool"
      variable = "aws:MultiFactorAuthPresent"
      values   = ["true"]
    }
  }
}

resource "aws_iam_role" "administrator_role" {
  name = "Administrator"

  assume_role_policy = data.aws_iam_policy_document.administrator_assume_role_policy.json
}

data "aws_iam_policy" "administrator_policy" {
  arn = "arn:aws:iam::aws:policy/AdministratorAccess"
}

resource "aws_iam_role_policy_attachment" "administrator_policy_attachment" {
  role       = aws_iam_role.administrator_role.name
  policy_arn = data.aws_iam_policy.administrator_policy.arn
}
