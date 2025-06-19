variable "aws_region" {
  type        = string
  description = "AWS region where the resources will be deployed."
  default     = "us-east-1"
}

variable "madara_orchestrator_aws_prefix" {
  type        = string
  description = "A prefix string to be added to the names of most AWS resources."
  default     = "mo"
}

variable "s3_bucket_identifier" {
  type        = string
  description = "Base name for the S3 bucket. The prefix will be prepended (e.g., {prefix}-{identifier})."
  default     = "orchestrator-bucket"
}

variable "sqs_queue_identifier_template" {
  type        = string
  description = "Template for SQS queue names. '{}' will be replaced by the queue type (e.g., {prefix}_{template_base}_{type}_queue)."
  default     = "orchestrator_{}_queue" # Example: mo_orchestrator_WorkerTrigger_queue
}

variable "sns_topic_identifier" {
  type        = string
  description = "Base name for the SNS topic. The prefix will be prepended (e.g., {prefix}_{identifier})."
  default     = "orchestrator-alerts"
}

variable "event_bridge_type" {
  type        = string
  description = "Type of EventBridge trigger: 'Rule' or 'Schedule'."
  default     = "Schedule"
  validation {
    condition     = contains(["Rule", "Schedule"], var.event_bridge_type)
    error_message = "Allowed values for event_bridge_type are 'Rule' or 'Schedule'."
  }
}

variable "event_bridge_interval_seconds" {
  type        = number
  description = "Interval in seconds for EventBridge triggers. Min 60 for 'Rule' type using rate(X minutes)."
  default     = 60
  validation {
    condition     = var.event_bridge_interval_seconds >= 1
    error_message = "The EventBridge interval must be at least 1 second."
  }
  # Additional validation could be added if type is Rule and interval is < 60,
  # but rate expressions like rate(X seconds) are also valid for rules.
  # The setup code's conversion logic implies rules might often use minute rates.
}

variable "tags" {
  type        = map(string)
  description = "A map of tags to assign to all taggable resources."
  default = {
    Project     = "MadaraOrchestrator"
    Environment = "Development"
  }
}
