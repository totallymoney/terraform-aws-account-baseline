# Short lived credentials for CI. No IAM users, no static access keys.
#
# Two things go wrong here often enough to be worth calling out:
#
#  1. The trust policy must pin the `sub` claim to a repository and usually to
#     a branch or environment. A policy that only checks `aud` trusts every
#     workflow on GitHub, including a fork.
#  2. GitHub now issues immutable subject claims that include numeric org and
#     repo ids for repositories created recently, for example
#     `repo:my-org/my-repo:ref:refs/heads/main` alongside an id based form.
#     Keep the older pattern in place when you add the new one, or existing
#     repositories stop being able to assume the role.

resource "aws_iam_openid_connect_provider" "github" {
  count = var.create_github_oidc_provider ? 1 : 0

  url             = "https://token.actions.githubusercontent.com"
  client_id_list  = ["sts.amazonaws.com"]
  thumbprint_list = []
  tags            = local.tags
}

locals {
  github_provider_arn = "arn:${local.partition}:iam::${local.account_id}:oidc-provider/token.actions.githubusercontent.com"
}

data "aws_iam_policy_document" "github_trust" {
  for_each = var.github_oidc_roles

  statement {
    actions = ["sts:AssumeRoleWithWebIdentity"]
    effect  = "Allow"

    principals {
      type        = "Federated"
      identifiers = [local.github_provider_arn]
    }

    condition {
      test     = "StringEquals"
      variable = "token.actions.githubusercontent.com:aud"
      values   = ["sts.amazonaws.com"]
    }

    condition {
      test     = "StringLike"
      variable = "token.actions.githubusercontent.com:sub"
      values   = each.value.subjects
    }
  }
}

resource "aws_iam_role" "github" {
  for_each = var.github_oidc_roles

  name                 = each.key
  assume_role_policy   = data.aws_iam_policy_document.github_trust[each.key].json
  max_session_duration = each.value.max_session_seconds
  tags                 = local.tags

  depends_on = [aws_iam_openid_connect_provider.github]
}

resource "aws_iam_role_policy_attachment" "github" {
  for_each = {
    for pair in flatten([
      for role_name, role in var.github_oidc_roles : [
        for arn in role.managed_policy_arns : {
          key    = "${role_name}:${arn}"
          role   = role_name
          policy = arn
        }
      ]
    ]) : pair.key => pair
  }

  role       = aws_iam_role.github[each.value.role].name
  policy_arn = each.value.policy
}

resource "aws_iam_role_policy" "github" {
  for_each = {
    for role_name, role in var.github_oidc_roles : role_name => role
    if role.inline_policy_json != null
  }

  name   = "inline"
  role   = aws_iam_role.github[each.key].id
  policy = each.value.inline_policy_json
}
