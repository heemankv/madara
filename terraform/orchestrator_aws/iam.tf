# --- IAM Role and Policy for EventBridge to send messages to SQS ---

locals {
  # Construct names for IAM resources
  iam_policy_name = "${var.madara_orchestrator_aws_prefix}-eventbridge-sqs-policy"
  iam_role_name   = "${var.madara_orchestrator_aws_prefix}-eventbridge-role"
}

# IAM Policy Document: Allows sending messages to the WorkerTrigger SQS queue
data "aws_iam_policy_document" "eventbridge_sqs_send_policy_doc" {
  statement {
    actions   = ["sqs:SendMessage"]
    resources = [aws_sqs_queue.worker_trigger_q.arn] # Reference WorkerTrigger queue ARN from sqs.tf
    effect    = "Allow"
  }
}

# IAM Policy Resource
resource "aws_iam_policy" "eventbridge_sqs_send_policy" {
  name        = local.iam_policy_name
  path        = "/"
  description = "IAM policy for EventBridge to send messages to the SQS WorkerTrigger queue."
  policy      = data.aws_iam_policy_document.eventbridge_sqs_send_policy_doc.json
  tags        = var.tags
}

# IAM Role Trust Policy Document: Allows EventBridge and Scheduler services to assume this role
data "aws_iam_policy_document" "eventbridge_assume_role_policy_doc" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["events.amazonaws.com", "scheduler.amazonaws.com"]
    }
    effect = "Allow"
  }
}

# IAM Role Resource
resource "aws_iam_role" "eventbridge_role" {
  name               = local.iam_role_name
  assume_role_policy = data.aws_iam_policy_document.eventbridge_assume_role_policy_doc.json
  description        = "IAM role for EventBridge to trigger SQS queues."
  tags               = var.tags
}

# Attach the policy to the role
resource "aws_iam_role_policy_attachment" "eventbridge_sqs_policy_attachment" {
  role       = aws_iam_role.eventbridge_role.name
  policy_arn = aws_iam_policy.eventbridge_sqs_send_policy.arn
}
