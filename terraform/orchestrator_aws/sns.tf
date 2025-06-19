# --- SNS Topic for Madara Orchestrator Alerts ---

locals {
  # Construct the SNS topic name using an underscore separator
  sns_topic_name = "${var.madara_orchestrator_aws_prefix}_${var.sns_topic_identifier}"
}

# Define the SNS topic resource
resource "aws_sns_topic" "orchestrator_alerts_topic" {
  name = local.sns_topic_name
  tags = var.tags

  # Optional: Define a display name (often same as name if not too long)
  # display_name = local.sns_topic_name

  # Optional: Configure delivery policy for HTTP/S, SQS, Lambda etc. (if needed by default)
  # For basic setup, default policies are often sufficient, and subscriptions handle specific delivery.
  # Example:
  # policy = data.aws_iam_policy_document.sns_topic_policy.json

  # Optional: Server-side encryption (SSE) for SNS topic
  # kms_master_key_id = "alias/aws/sns" # For AWS-managed KMS key for SNS
}

# Example of a topic policy if you need to define specific access,
# e.g., allowing other AWS services or accounts to publish.
# By default, only the topic owner can publish.
# data "aws_iam_policy_document" "sns_topic_policy" {
#   statement {
#     actions   = ["SNS:Publish"]
#     resources = ["arn:aws:sns:*:*:${local.sns_topic_name}"] # More specific ARN can be used once topic is created if needed
#     principals {
#       type        = "Service"
#       identifiers = ["events.amazonaws.com"] # Example: Allow EventBridge to publish
#     }
#   }
#   statement {
#     actions   = ["SNS:Subscribe", "SNS:Receive"]
#     resources = ["arn:aws:sns:*:*:${local.sns_topic_name}"]
#     principals { # Example: Allow current account's root user to manage subscriptions
#       type        = "AWS"
#       identifiers = ["arn:aws:iam::${data.aws_caller_identity.current.account_id}:root"]
#     }
#   }
# }
#
# data "aws_caller_identity" "current" {}
