# in a key policy, "*" refers to the key the policy is attached to
data "aws_iam_policy_document" "key_policy" {
  policy_id = "SecurityKeyPolicy"
  statement {
    sid = "AllowGuardDutyEncryption"
    actions = [
      "kms:GenerateDataKey"
    ]
    resources = ["*"]
    principals {
      type        = "Service"
      identifiers = ["guardduty.amazonaws.com"]
    }
    condition {
      test     = "StringEquals"
      variable = "aws:SourceAccount"
      values   = [local.account_id]
    }
    condition {
      test     = "ArnLike"
      variable = "aws:SourceArn"
      values   = [local.guardduty_detector_arn]
    }
  }
  statement {
    sid = "AllowKeyAdministration"
    actions = [
      "kms:*"
    ]
    resources = ["*"]
    principals {
      type        = "AWS"
      identifiers = ["arn:${local.partition}:iam::${local.account_id}:root"]
    }
  }
}
data "aws_iam_policy_document" "bucket_policy" {
  policy_id = "GuardDutyFindingsBucketPolicy"
  statement {
    sid = "AllowGuardDutyGetBucketLocation"
    actions = [
      "s3:GetBucketLocation"
    ]
    resources = [
      aws_s3_bucket.guardduty.arn
    ]
    principals {
      type        = "Service"
      identifiers = ["guardduty.amazonaws.com"]
    }
    condition {
      test     = "StringEquals"
      variable = "aws:SourceAccount"
      values   = [local.account_id]
    }
    condition {
      test     = "ArnLike"
      variable = "aws:SourceArn"
      values   = [local.guardduty_detector_arn]
    }
  }
  statement {
    sid = "AllowGuardDutyPutObject"
    actions = [
      "s3:PutObject"
    ]
    resources = [
      "${aws_s3_bucket.guardduty.arn}/*"
    ]
    principals {
      type        = "Service"
      identifiers = ["guardduty.amazonaws.com"]
    }
    condition {
      test     = "StringEquals"
      variable = "aws:SourceAccount"
      values   = [local.account_id]
    }
    condition {
      test     = "ArnLike"
      variable = "aws:SourceArn"
      values   = [local.guardduty_detector_arn]
    }
  }
  statement {
    sid    = "DenyUnencryptedGuardDutyUploads"
    effect = "Deny"
    actions = [
      "s3:PutObject"
    ]
    resources = [
      "${aws_s3_bucket.guardduty.arn}/*"
    ]
    principals {
      type        = "Service"
      identifiers = ["guardduty.amazonaws.com"]
    }
    condition {
      test     = "StringNotEquals"
      variable = "s3:x-amz-server-side-encryption"
      values   = ["aws:kms"]
    }
  }
  statement {
    sid    = "DenyIncorrectGuardDutyEncryptionKey"
    effect = "Deny"
    actions = [
      "s3:PutObject"
    ]
    resources = [
      "${aws_s3_bucket.guardduty.arn}/*"
    ]
    principals {
      type        = "Service"
      identifiers = ["guardduty.amazonaws.com"]
    }
    condition {
      test     = "StringNotEquals"
      variable = "s3:x-amz-server-side-encryption-aws-kms-key-id"
      values   = [aws_kms_key.security.arn]
    }
  }
  statement {
    sid    = "DenyNonHttpsAccess"
    effect = "Deny"
    actions = [
      "s3:*"
    ]
    resources = [
      aws_s3_bucket.guardduty.arn,
      "${aws_s3_bucket.guardduty.arn}/*"
    ]
    principals {
      type        = "*"
      identifiers = ["*"]
    }
    condition {
      test     = "Bool"
      variable = "aws:SecureTransport"
      values   = ["false"]
    }
  }
}
