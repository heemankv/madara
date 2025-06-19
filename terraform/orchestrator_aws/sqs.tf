# --- SQS Queues for Madara Orchestrator ---

locals {
  # Define queue configurations based on orchestrator/src/setup/queue.rs
  # Note: 'dlq_target_type' refers to the 'QueueType' string of the DLQ.
  # 'supported_layers' is ignored for this Terraform config, all queues are defined.
  queue_configs = {
    "JobHandleFailure" = {
      visibility_timeout = 300
      dlq_target_type    = null # This queue is a DLQ itself, does not have one
      max_receive_count  = null
    }
    "WorkerTrigger" = { # This queue is targeted by EventBridge
      visibility_timeout = 300
      dlq_target_type    = null
      max_receive_count  = null
    }
    "SnosJobProcessing" = {
      visibility_timeout = 300
      dlq_target_type    = "JobHandleFailure"
      max_receive_count  = 5
    }
    "SnosJobVerification" = {
      visibility_timeout = 300
      dlq_target_type    = "JobHandleFailure"
      max_receive_count  = 5
    }
    "ProvingJobProcessing" = {
      visibility_timeout = 300
      dlq_target_type    = "JobHandleFailure"
      max_receive_count  = 5
    }
    "ProvingJobVerification" = {
      visibility_timeout = 300
      dlq_target_type    = "JobHandleFailure"
      max_receive_count  = 5
    }
    "ProofRegistrationJobProcessing" = { # Typically L3
      visibility_timeout = 300
      dlq_target_type    = "JobHandleFailure"
      max_receive_count  = 5
    }
    "ProofRegistrationJobVerification" = { # Typically L3
      visibility_timeout = 300
      dlq_target_type    = "JobHandleFailure"
      max_receive_count  = 5
    }
    "DataSubmissionJobProcessing" = {
      visibility_timeout = 300
      dlq_target_type    = "JobHandleFailure"
      max_receive_count  = 5
    }
    "DataSubmissionJobVerification" = {
      visibility_timeout = 300
      dlq_target_type    = "JobHandleFailure"
      max_receive_count  = 5
    }
    "UpdateStateJobProcessing" = {
      visibility_timeout = 900
      dlq_target_type    = "JobHandleFailure"
      max_receive_count  = 5
    }
    "UpdateStateJobVerification" = {
      visibility_timeout = 300
      dlq_target_type    = "JobHandleFailure"
      max_receive_count  = 5
    }
    # BatchingQueue is mentioned in EventBridge triggers but not in QUEUES static array
    # If needed, it should be added here. For now, following QUEUES definition.
  }

  # Helper to construct queue names
  # Example: mo_orchestrator_WorkerTrigger_queue
  sqs_queue_name = {
    for type, config in local.queue_configs :
    type => replace(
      "${var.madara_orchestrator_aws_prefix}_${var.sqs_queue_identifier_template}",
      "{}",
      type
    )
  }
}

# --- Dead Letter Queue (DLQ) ---
# This queue receives messages from other queues that fail processing.
resource "aws_sqs_queue" "job_handle_failure_q" {
  name                       = local.sqs_queue_name["JobHandleFailure"]
  visibility_timeout_seconds = local.queue_configs["JobHandleFailure"].visibility_timeout
  tags                       = var.tags
}

# --- Worker Trigger Queue ---
# This queue is targeted by EventBridge to trigger orchestrator workers.
resource "aws_sqs_queue" "worker_trigger_q" {
  name                       = local.sqs_queue_name["WorkerTrigger"]
  visibility_timeout_seconds = local.queue_configs["WorkerTrigger"].visibility_timeout
  tags                       = var.tags
  # No DLQ for WorkerTrigger queue as per current setup.
}

# --- Other Application Queues ---
# These queues are used for various job processing tasks within the orchestrator.
resource "aws_sqs_queue" "application_queues" {
  for_each = {
    for type, config in local.queue_configs : type => config
    if type != "JobHandleFailure" && type != "WorkerTrigger" # Exclude already created queues
  }

  name                       = local.sqs_queue_name[each.key]
  visibility_timeout_seconds = each.value.visibility_timeout
  tags                       = var.tags

  # Configure Redrive Policy (DLQ) if specified
  redrive_policy = each.value.dlq_target_type != null ? jsonencode({
    deadLetterTargetArn = aws_sqs_queue.job_handle_failure_q.arn # All DLQs point to JobHandleFailure
    maxReceiveCount     = each.value.max_receive_count
  }) : null
}
