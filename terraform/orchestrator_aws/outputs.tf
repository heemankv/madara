# --- Outputs for Madara Orchestrator AWS Resources ---

output "s3_orchestrator_bucket_name" {
  description = "The name of the S3 bucket created for the orchestrator."
  value       = aws_s3_bucket.orchestrator_bucket.bucket
}

output "s3_orchestrator_bucket_arn" {
  description = "The ARN of the S3 bucket created for the orchestrator."
  value       = aws_s3_bucket.orchestrator_bucket.arn
}

output "sqs_worker_trigger_queue_arn" {
  description = "The ARN of the WorkerTrigger SQS queue."
  value       = aws_sqs_queue.worker_trigger_q.arn
}

output "sqs_worker_trigger_queue_url" {
  description = "The URL of the WorkerTrigger SQS queue."
  value       = aws_sqs_queue.worker_trigger_q.id # .id attribute gives the URL for aws_sqs_queue
}

output "sqs_job_handle_failure_queue_arn" {
  description = "The ARN of the JobHandleFailure SQS queue (common DLQ)."
  value       = aws_sqs_queue.job_handle_failure_q.arn
}

output "sqs_job_handle_failure_queue_url" {
  description = "The URL of the JobHandleFailure SQS queue (common DLQ)."
  value       = aws_sqs_queue.job_handle_failure_q.id # .id attribute gives the URL for aws_sqs_queue
}

output "iam_eventbridge_role_arn" {
  description = "The ARN of the IAM role created for EventBridge."
  value       = aws_iam_role.eventbridge_role.arn
}

output "sns_orchestrator_alerts_topic_arn" {
  description = "The ARN of the SNS topic created for orchestrator alerts."
  value       = aws_sns_topic.orchestrator_alerts_topic.arn
}

# Optionally, output ARNs for all application queues if needed
# output "sqs_application_queues_arns" {
#   description = "ARNs of all application SQS queues."
#   value = {
#     for k, v in aws_sqs_queue.application_queues : k => v.arn
#   }
# }
#
# output "sqs_application_queues_urls" {
#   description = "URLs of all application SQS queues."
#   value = {
#     for k, v in aws_sqs_queue.application_queues : k => v.id
#   }
# }

# Output for EventBridge rules/schedules can also be added if specific ARNs are needed.
# Example for schedules:
# output "eventbridge_schedules_arns" {
#   description = "ARNs of the EventBridge schedules created."
#   value = var.event_bridge_type == "Schedule" ? {
#     for k, v in aws_scheduler_schedule.orchestrator_trigger_schedules : k => v.arn
#   } : {}
#   sensitive = true # Depending on whether you consider schedule ARNs sensitive
# }
# Example for rules:
# output "eventbridge_rules_arns" {
#   description = "ARNs of the EventBridge rules created."
#   value = var.event_bridge_type == "Rule" ? {
#     for k, v in aws_cloudwatch_event_rule.orchestrator_trigger_rules : k => v.arn
#   } : {}
# }
