# --- EventBridge (CloudWatch Events / Scheduler) for Madara Orchestrator Triggers ---

locals {
  # List of worker trigger types.
  # Note: "ProofRegistration" is typically for L3 setups.
  # Users can modify this list or add conditional logic if specific triggers are not needed.
  worker_triggers = toset([
    "Snos",
    "Proving",
    "ProofRegistration",
    "DataSubmission",
    "UpdateState",
    "Batching"
  ])

  # Determine schedule expression format based on interval_seconds
  # EventBridge rate expressions: rate(value unit) where unit can be minute(s), hour(s), day(s).
  # For seconds, cron expressions are more typical for CloudWatch Event Rules,
  # but rate(X seconds) can sometimes be used if the value is > 1 and specific to the service.
  # Scheduler supports rate(X seconds) more directly.
  # This logic prioritizes minutes if cleanly divisible, else seconds.
  schedule_expression = var.event_bridge_interval_seconds % 60 == 0 ? (
    var.event_bridge_interval_seconds / 60 == 1 ? "rate(1 minute)" : format("rate(%d minutes)", var.event_bridge_interval_seconds / 60)
    ) : format("rate(%d seconds)", var.event_bridge_interval_seconds) # Fallback to seconds, ensure var.event_bridge_interval_seconds >= 1 (validated in variables.tf)
  # For more complex logic (hours, days), additional tiers of conditional logic could be added.
  # Example for CloudWatch Event Rule if strict minute/hour/day rates are required:
  # schedule_expression_cw_event = var.event_bridge_interval_seconds == 60 ? "rate(1 minute)" : (
  #   var.event_bridge_interval_seconds % 60 == 0 && var.event_bridge_interval_seconds > 60 ? format("rate(%d minutes)", var.event_bridge_interval_seconds / 60) : (
  #     var.event_bridge_interval_seconds % 3600 == 0 && var.event_bridge_interval_seconds >= 3600 ? format("rate(%d hours)", var.event_bridge_interval_seconds / 3600 ) :
  #     # Fallback or error if not fitting simple rate(X minutes/hours)
  #     # CloudWatch Events are more restrictive with 'rate' than EventBridge Scheduler.
  #     # For simplicity, using the broader expression; adjust if specific CW Event limitations are hit.
  #     format("cron(0/%d * * * ? *)", var.event_bridge_interval_seconds / 60) # Example: every X minutes using cron
  #   )
  # )
}

# --- EventBridge Rules (if var.event_bridge_type == "Rule") ---
resource "aws_cloudwatch_event_rule" "orchestrator_trigger_rules" {
  for_each = var.event_bridge_type == "Rule" ? local.worker_triggers : toset([]) # Create only if type is Rule

  name                = "${var.madara_orchestrator_aws_prefix}-event-rule-${each.key}"
  description         = "Orchestrator trigger rule for ${each.key}"
  schedule_expression = local.schedule_expression # Using the simplified expression
  is_enabled          = true
  tags                = var.tags
}

resource "aws_cloudwatch_event_target" "orchestrator_trigger_targets" {
  for_each = var.event_bridge_type == "Rule" ? local.worker_triggers : toset([]) # Create only if type is Rule

  rule      = aws_cloudwatch_event_rule.orchestrator_trigger_rules[each.key].name
  arn       = aws_sqs_queue.worker_trigger_q.arn # From sqs.tf
  target_id = "${each.key}Target"

  input_transformer {
    input_paths = {
      "time" = "$.time" # Standard path from EventBridge event
    }
    # Input template is the trigger type string, e.g., "Snos"
    input_template = jsonencode(each.key)
  }
}

# --- EventBridge Scheduler (if var.event_bridge_type == "Schedule") ---
resource "aws_scheduler_schedule" "orchestrator_trigger_schedules" {
  for_each = var.event_bridge_type == "Schedule" ? local.worker_triggers : toset([]) # Create only if type is Schedule

  name       = "${var.madara_orchestrator_aws_prefix}-event-schedule-${each.key}"
  group_name = "default" # Default group, or can be customized

  schedule_expression          = local.schedule_expression # Using the simplified expression
  schedule_expression_timezone = "UTC"

  flexible_time_window {
    mode = "OFF"
  }

  target {
    arn      = aws_sqs_queue.worker_trigger_q.arn # From sqs.tf
    role_arn = aws_iam_role.eventbridge_role.arn  # From iam.tf
    # Input is the trigger type string, e.g., "Snos"
    input = jsonencode(each.key)
  }

  # tags are not directly supported on aws_scheduler_schedule in some early provider versions.
  # If your AWS provider version supports tags for this resource, you can add:
  # tags = var.tags
}
