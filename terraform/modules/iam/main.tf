data "aws_caller_identity" "current" {}
data "aws_region" "current" {}

data "aws_iam_policy_document" "irsa_assume" {
  statement {
    actions = ["sts:AssumeRoleWithWebIdentity"]
    effect  = "Allow"

    principals {
      type        = "Federated"
      identifiers = [var.oidc_provider_arn]
    }

    condition {
      test     = "StringEquals"
      variable = "${var.oidc_provider_url}:aud"
      values   = ["sts.amazonaws.com"]
    }

    condition {
      test     = "StringEquals"
      variable = "${var.oidc_provider_url}:sub"
      values   = ["system:serviceaccount:${var.namespace}:${var.service_account_name}"]
    }
  }
}

data "aws_iam_policy_document" "platform_api" {
  statement {
    sid     = "ReadNamespacedSecrets"
    actions = ["secretsmanager:GetSecretValue", "secretsmanager:DescribeSecret"]
    resources = [
      "arn:aws:secretsmanager:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:secret:${var.secrets_manager_prefix}*",
    ]
  }

  statement {
    sid       = "ListSecrets"
    actions   = ["secretsmanager:ListSecrets"]
    resources = ["*"]
  }
}

resource "aws_iam_role" "platform_api" {
  name               = "${var.name_prefix}-platform-api"
  assume_role_policy = data.aws_iam_policy_document.irsa_assume.json
  tags               = var.tags
}

resource "aws_iam_role_policy" "platform_api" {
  name   = "read-secrets"
  role   = aws_iam_role.platform_api.id
  policy = data.aws_iam_policy_document.platform_api.json
}

data "aws_iam_policy_document" "gha_assume" {
  count = var.gha_oidc_enabled ? 1 : 0

  statement {
    actions = ["sts:AssumeRoleWithWebIdentity"]
    effect  = "Allow"

    principals {
      type        = "Federated"
      identifiers = ["arn:aws:iam::${data.aws_caller_identity.current.account_id}:oidc-provider/token.actions.githubusercontent.com"]
    }

    condition {
      test     = "StringEquals"
      variable = "token.actions.githubusercontent.com:aud"
      values   = ["sts.amazonaws.com"]
    }

    condition {
      test     = "StringLike"
      variable = "token.actions.githubusercontent.com:sub"
      values   = ["repo:${var.gha_repository}:ref:refs/heads/${var.gha_branch}"]
    }
  }
}

data "aws_iam_policy_document" "gha_push" {
  count = var.gha_oidc_enabled ? 1 : 0

  statement {
    sid       = "EcrAuth"
    actions   = ["ecr:GetAuthorizationToken"]
    resources = ["*"]
  }

  statement {
    sid = "EcrPush"
    actions = [
      "ecr:BatchCheckLayerAvailability",
      "ecr:InitiateLayerUpload",
      "ecr:UploadLayerPart",
      "ecr:CompleteLayerUpload",
      "ecr:PutImage",
      "ecr:BatchGetImage",
      "ecr:GetDownloadUrlForLayer",
    ]
    resources = [var.ecr_repository_arn]
  }
}

resource "aws_iam_role" "gha" {
  count              = var.gha_oidc_enabled ? 1 : 0
  name               = "${var.name_prefix}-gha-ci"
  assume_role_policy = data.aws_iam_policy_document.gha_assume[0].json
  tags               = var.tags
}

resource "aws_iam_role_policy" "gha" {
  count  = var.gha_oidc_enabled ? 1 : 0
  name   = "ecr-push"
  role   = aws_iam_role.gha[0].id
  policy = data.aws_iam_policy_document.gha_push[0].json
}
