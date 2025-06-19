# AWS Resource Setup Guide for Orchestrator

This document details how the orchestrator's `setup` command provisions and configures AWS resources.

## 1. S3 Bucket Setup

The orchestrator can be configured to use an AWS S3 bucket for storage purposes. The setup process for S3 is as follows:

*   **Trigger**: S3 resources are configured when the `setup` command is run with S3-specific arguments (e.g., bucket name or ARN).
*   **Resource Specification**: The S3 bucket to be used is specified via `storage_args` (e.g., `--aws-s3-bucket-name <bucket-name>` or `--aws-s3-bucket-arn <bucket-arn>`).

### Bucket Creation Logic:

1.  **Existence Check**: Before attempting to create a bucket, the system first checks if the specified bucket already exists.
    *   If a bucket ARN is provided (`--aws-s3-bucket-arn`), the system uses this ARN to check.
    *   If a bucket name is provided (`--aws-s3-bucket-name`), the system uses this name to check.
2.  **Creation Skipping**:
    *   If the existence check is positive (the bucket already exists), the setup process for S3 skips the creation step, logging a warning that the bucket already exists.
3.  **New Bucket Creation**:
    *   If the bucket does not exist and was specified by **name**:
        *   The system proceeds to create a new S3 bucket using the provided name.
        *   **Region Configuration**:
            *   If the AWS region for the orchestrator is `us-east-1`, the bucket is created without explicit location constraints.
            *   If the AWS region is other than `us-east-1`, the bucket is created with a `CreateBucketConfiguration` that sets the `BucketLocationConstraint` to the specified region. This ensures the bucket is created in the correct geographical location.
    *   If the bucket was specified by **ARN** but was found not to exist during the check, the setup for S3 effectively does nothing further for bucket creation itself, as an ARN implies an existing resource. The orchestrator would expect a valid, existing bucket ARN.

## 2. SQS Queue Setup

The orchestrator utilizes AWS SQS queues for managing various job types and message flows. These queues are defined with specific configurations, including Dead Letter Queues (DLQs) for handling message failures.

*   **Trigger**: SQS resources are configured when the `setup` command is run with SQS-specific arguments (e.g., queue name template or ARN template).
*   **Resource Specification**: The SQS queues are identified by a template name (`--aws-sqs-queue-name-template <template-name>`) or an ARN template (`--aws-sqs-queue-arn-template <template-arn>`). The actual queue names are derived by appending a suffix based on the `QueueType`.

### Predefined Queue Configurations:

The system uses a predefined list of queue configurations found in `orchestrator/src/setup/queue.rs`. For each queue, the configuration specifies:
*   `name`: The `QueueType` enum value (e.g., `SnosJobProcessing`, `WorkerTrigger`).
*   `visibility_timeout`: The duration (in seconds) that a message received from the queue will be hidden from subsequent an immediate receive requests.
*   `dlq_config`: An optional configuration for a Dead Letter Queue.
    *   `dlq_name`: The `QueueType` of the DLQ (often `JobHandleFailure`).
    *   `maxReceiveCount`: The number of times a message can be received before being sent to the DLQ.
*   `supported_layers`: Specifies if the queue is for `L2`, `L3`, or both.

### Queue Creation Logic:

1.  **Iteration**: The setup process iterates through the predefined `QUEUES` list.
2.  **Layer Check**: For each queue configuration, it first checks if the queue is supported for the `layer` (L2 or L3) specified during the `setup` command execution. If not, this queue configuration is skipped.
3.  **Existence Check**:
    *   The system checks if the main queue already exists. The actual queue name is derived using the provided template and the `QueueType` (e.g., `<template-name>-SnosJobProcessing`).
    *   If a `dlq_config` is present, it also checks if the DLQ (e.g., `<template-name>-JobHandleFailure`) exists.
    *   If an ARN template is used, ARNs are constructed similarly for the check.
4.  **Creation Skipping**:
    *   If the main queue (and its DLQ, if applicable, and already checked as existing) is found, its setup might be skipped or updated. The code indicates that if the main queue exists, it logs this and continues, implying it doesn't re-configure if not necessary. *(Note: The code mentions a "Good first issue" to improve this to check DLQ and policy inclusion even if the main queue exists.)*
5.  **New Queue Creation**:
    *   If a queue name template (not ARN) was provided and the queue doesn't exist:
        *   **Main Queue**: `CreateQueue` is called to create the main SQS queue.
        *   **Dead Letter Queue (DLQ)**:
            *   If `dlq_config` is specified and the DLQ doesn't exist, `CreateQueue` is called to create the DLQ.
            *   The ARN of the created (or existing) DLQ is fetched.
            *   A `RedrivePolicy` is constructed in JSON format:
                ```json
                {
                  "deadLetterTargetArn": "<DLQ_ARN>",
                  "maxReceiveCount": "<maxReceiveCount_from_config>"
                }
                ```
        *   **Queue Attributes**:
            *   `SetQueueAttributes` is called on the main queue.
            *   The `VisibilityTimeout` is set based on the queue's configuration.
            *   If a DLQ is configured, the `RedrivePolicy` (as JSON string) is set.
    *   If an ARN template was provided: The setup process assumes ARNs point to existing, correctly configured queues. If the check shows they don't exist, creation is skipped as ARNs are identifiers of existing resources.

### List of Standard Queues:

(This list is based on the `QUEUES` definition in `orchestrator/src/setup/queue.rs` at the time of this documentation.)

| QueueType                         | Visibility Timeout (s) | DLQ Name (Type)      | Max Receive Count | Supported Layers |
| --------------------------------- | ---------------------- | -------------------- | ----------------- | ---------------- |
| `JobHandleFailure`                | 300                    | None                 | N/A               | L2, L3           |
| `SnosJobProcessing`               | 300                    | `JobHandleFailure`   | 5                 | L2, L3           |
| `SnosJobVerification`             | 300                    | `JobHandleFailure`   | 5                 | L2, L3           |
| `ProvingJobProcessing`            | 300                    | `JobHandleFailure`   | 5                 | L2, L3           |
| `ProvingJobVerification`          | 300                    | `JobHandleFailure`   | 5                 | L2, L3           |
| `ProofRegistrationJobProcessing`  | 300                    | `JobHandleFailure`   | 5                 | L3               |
| `ProofRegistrationJobVerification`| 300                    | `JobHandleFailure`   | 5                 | L3               |
| `DataSubmissionJobProcessing`     | 300                    | `JobHandleFailure`   | 5                 | L2, L3           |
| `DataSubmissionJobVerification`   | 300                    | `JobHandleFailure`   | 5                 | L2, L3           |
| `UpdateStateJobProcessing`        | 900                    | `JobHandleFailure`   | 5                 | L2, L3           |
| `UpdateStateJobVerification`      | 300                    | `JobHandleFailure`   | 5                 | L2, L3           |
| `WorkerTrigger`                   | 300                    | None                 | N/A               | L2, L3           |

## 3. SNS Topic Setup

AWS Simple Notification Service (SNS) topics are used by the orchestrator for sending alerts and notifications.

*   **Trigger**: SNS resources are configured when the `setup` command is run with SNS-specific arguments (e.g., topic name or ARN).
*   **Resource Specification**: The SNS topic is specified via `alert_args` (e.g., `--aws-sns-topic-name <topic-name>` or `--aws-sns-topic-arn <topic-arn>`).

### Topic Creation Logic:

1.  **Name Validation**: If a topic name is provided, it's first validated to ensure it contains only letters, numbers, hyphens, and underscores. Invalid names will result in a setup error.
2.  **Existence Check**: The system checks if the SNS topic already exists.
    *   If an ARN is provided (`--aws-sns-topic-arn`), the system uses this ARN to check via `GetTopicAttributes`.
    *   If a name is provided (`--aws-sns-topic-name`), the system attempts to fetch the topic ARN by its name (likely using an internal helper that might list topics or use a known naming convention to find its ARN, then `GetTopicAttributes`).
3.  **Creation Skipping**:
    *   If the existence check is positive (the topic already exists), the setup process for SNS skips the creation step, logging a warning that the topic already exists.
4.  **New Topic Creation**:
    *   If the topic does not exist and was specified by **name**:
        *   The system proceeds to create a new SNS topic using `CreateTopic` with the validated name.
        *   The ARN of the newly created topic is logged.
    *   If the topic was specified by **ARN** but was found not to exist during the check, the setup for SNS effectively does nothing further for topic creation itself, as an ARN implies an existing resource. The orchestrator would expect a valid, existing topic ARN.

## 4. EventBridge (Cron Job) Setup

The orchestrator uses AWS EventBridge (supporting both EventBridge Rules and EventBridge Scheduler) to create cron-like jobs. These jobs periodically send messages to an SQS queue (typically the `WorkerTrigger` queue) to initiate various automated tasks.

*   **Trigger**: EventBridge resources are configured when the `setup` command is run with cron-specific arguments (e.g., target queue, role names, schedule expression).
*   **Resource Specification**:
    *   `--aws-event-bridge-type <Rule|Schedule>`: Specifies whether to use EventBridge Rules or Scheduler.
    *   `--aws-sqs-target-queue-name <queue-name>` or `--aws-sqs-target-queue-arn <queue-arn>`: Specifies the SQS queue to send trigger messages to (usually the `WorkerTrigger` queue).
    *   `--aws-event-bridge-trigger-role-name <role-name-template>`: Template for the IAM role name.
    *   `--aws-event-bridge-trigger-policy-name <policy-name-template>`: Template for the IAM policy name.
    *   `--aws-event-bridge-trigger-rule-name <rule-name-template>`: Template for the EventBridge rule/schedule name.
    *   `--aws-event-bridge-cron-time <seconds>`: The interval for the cron job (e.g., 300 for 5 minutes).

### IAM Role and Policy for EventBridge/Scheduler:

Before creating the actual EventBridge rules or schedules, the system sets up an IAM role and an associated policy to grant EventBridge/Scheduler the necessary permissions to send messages to the target SQS queue.

1.  **Target Queue ARN Retrieval**: The ARN of the target SQS queue (e.g., `WorkerTrigger` queue) is fetched. If a queue name is provided, its ARN is looked up.
2.  **Unique ID Generation**: A short, random 4-character hexadecimal ID (e.g., `a1b2`) is generated. This ID is appended to the role and policy names to ensure uniqueness if multiple orchestrator instances are set up.
3.  **IAM Role Creation**:
    *   **Name**: The role name is constructed as `<trigger_role_name_template>-<short_id>`.
    *   **Trust Policy (AssumeRolePolicyDocument)**: An IAM role is created with a trust policy that allows the EventBridge and Scheduler services to assume this role. The policy document is:
        ```json
        {
            "Version": "2012-10-17",
            "Statement": [{
                "Effect": "Allow",
                "Principal": {
                    "Service": ["scheduler.amazonaws.com", "events.amazonaws.com"]
                },
                "Action": "sts:AssumeRole"
            }]
        }
        ```
    *   The ARN of this created role is stored for later use.
4.  **IAM Policy Creation and Attachment**:
    *   **Name**: The policy name is constructed as `<trigger_policy_name_template>-<short_id>`.
    *   **Policy Document**: An IAM policy is created that grants permission to send messages (`sqs:SendMessage`) to the specific target SQS queue. The policy document is:
        ```json
        {
            "Version": "2012-10-17",
            "Statement": [{
                "Effect": "Allow",
                "Action": ["sqs:SendMessage"],
                "Resource": "<target_sqs_queue_arn>"
            }]
        }
        ```
        (Replace `<target_sqs_queue_arn>` with the actual ARN of the SQS queue, e.g., the `WorkerTrigger` queue ARN).
    *   **Attachment**: This policy is then attached to the IAM role created in the previous step.

*A delay (e.g., 15 seconds) is introduced after IAM resource creation to allow for propagation before these resources are used by EventBridge.*

### EventBridge Rule/Schedule Creation:

After the IAM setup, the system iterates through a predefined list of `WORKER_TRIGGERS` to create a corresponding EventBridge Rule or Schedule for each. The standard worker triggers are:
*   `Snos`
*   `Proving`
*   `ProofRegistration` (Note: This trigger is typically set up only if the orchestrator `layer` is `L3`)
*   `DataSubmission`
*   `UpdateState`
*   `Batching`

For each `WorkerTriggerType`:

1.  **Name Construction**: The name for the EventBridge Rule or Schedule is derived from the `trigger_rule_template_name` argument and the specific `WorkerTriggerType` (e.g., `<rule-template-name>-Snos`).
2.  **Existence Check**: The system checks if a rule or schedule with this constructed name already exists (using `DescribeRule` for rules or `GetSchedule` for schedules).
3.  **Creation Skipping**: If the rule/schedule already exists, its creation is skipped, and a message is logged.
4.  **New Rule/Schedule Creation**: If it doesn't exist, a new EventBridge Rule or Schedule is created:
    *   **Schedule Expression**: The `cron_time` argument (in seconds) is converted into a rate expression string (e.g., `rate(5 minutes)`, `rate(1 hour)`).
    *   **State/Status**: Enabled.
    *   **Target Configuration**:
        *   **ARN**: The ARN of the target SQS queue (e.g., `WorkerTrigger` queue ARN).
        *   **Role ARN**: The ARN of the IAM role created specifically for EventBridge/Scheduler.
        *   **Input/Message**: The message sent to the SQS queue is the string representation of the `WorkerTriggerType` (e.g., `"Snos"`, `"Proving"`).
        *   **InputTransformer (for EventBridgeType::Rule only)**:
            *   If using EventBridge Rules, an `InputTransformer` is configured.
            *   `InputPathsMap`: `{"time": "$.time"}` (to pass the event timestamp).
            *   `InputTemplate`: The string representation of the `WorkerTriggerType` (e.g., `"Snos"`). This becomes the body of the message sent to SQS.
        *   **FlexibleTimeWindow (for EventBridgeType::Schedule only)**:
            *   Mode is set to `OFF`.
    *   The rule/schedule is created using `PutRule` (and `PutTargets`) for rules, or `CreateSchedule` for schedules.

This setup ensures that each worker type is periodically triggered by sending a specific message to the central `WorkerTrigger` SQS queue, which then presumably routes these messages to appropriate handlers.

## 5. Order of Operations

While the setup command handles dependencies implicitly to some extent, the general order of resource provisioning and dependency is:

1.  **S3 Buckets and SQS Queues**: These are generally foundational and can be set up first or in parallel. SQS Queues, especially the Dead Letter Queues (DLQs), are established with their policies.
2.  **SNS Topics**: These are independent and can be set up.
3.  **IAM Roles and Policies for EventBridge**: These must be created *before* the EventBridge rules/schedules that use them. This includes creating the role with its trust policy and the permission policy granting SQS access.
4.  **EventBridge Rules/Schedules**: These are typically set up last as they depend on:
    *   An existing SQS queue to target (e.g., `WorkerTrigger` queue).
    *   An existing IAM role that EventBridge/Scheduler can assume to send messages to the SQS queue.

The setup script ensures that necessary components like SQS queue ARNs are available before attempting to create resources that depend on them (e.g., EventBridge targets or IAM policies referencing queue ARNs).
