# Orchestrator AWS Setup Documentation


# 1. S3 Bucket Setup

*   **Order of Creation:** S3 buckets are the first AWS resources provisioned by the orchestrator's `setup` command.
*   **Naming Convention:**
    *   The primary identifier for the bucket name is taken from the `MADARA_ORCHESTRATOR_AWS_S3_BUCKET_IDENTIFIER` environment variable. For example, if set to `test-bucket`.
    *   If the `MADARA_ORCHESTRATOR_AWS_PREFIX` environment variable is set (e.g., to `mo`), this prefix is prepended to the bucket identifier, separated by a hyphen.
    *   The final bucket name follows the format: `{PREFIX}-{BUCKET_IDENTIFIER}`.
        *   Example: If `MADARA_ORCHESTRATOR_AWS_PREFIX="mo"` and `MADARA_ORCHESTRATOR_AWS_S3_BUCKET_IDENTIFIER="test-bucket"`, the resulting bucket name will be `mo-test-bucket`.
    *   If `MADARA_ORCHESTRATOR_AWS_S3_BUCKET_IDENTIFIER` is an ARN (e.g., `arn:aws:s3:::my-actual-bucket`), the prefixing logic is skipped, and the provided ARN's resource part is used as the bucket name.
*   **Creation Logic:**
    *   The setup process first checks if an S3 bucket with the determined name already exists.
    *   If the bucket exists, the creation step is skipped, and a warning message is logged.
    *   If the bucket does not exist, a new S3 bucket is created.
*   **Region Configuration:**
    *   When a new bucket is created, the AWS region for the bucket is determined by the AWS SDK's configuration. This is typically set via environment variables like `AWS_REGION` or through an AWS profile.
    *   If no specific region is configured in the SDK, it defaults to `us-east-1`. Buckets created in regions other than `us-east-1` will have a `CreateBucketConfiguration` specifying the location constraint.
*   **Bucket Policies:**
    *   The orchestrator's setup process, as analyzed, does not create or attach any specific S3 bucket policies (e.g., bucket policies for access control) during the initial provisioning of the bucket. Default AWS S3 permissions and settings will apply.


# 2. SQS Queue Setup

*   **Order of Creation:** SQS queues are provisioned after the S3 bucket setup is complete.
*   **Naming Convention:**
    *   Queue names are based on a template provided by the `MADARA_ORCHESTRATOR_AWS_SQS_QUEUE_IDENTIFIER` environment variable. For example, if set to `test_{}_queue`.
    *   If the `MADARA_ORCHESTRATOR_AWS_PREFIX` environment variable is set (e.g., to `mo`), this prefix is prepended to the queue identifier template, separated by an underscore.
    *   The final queue name template follows the format: `{PREFIX}_{QUEUE_IDENTIFIER_TEMPLATE}`.
        *   Example: If `MADARA_ORCHESTRATOR_AWS_PREFIX="mo"` and `MADARA_ORCHESTRATOR_AWS_SQS_QUEUE_IDENTIFIER="test_{}_queue"`, the resulting template will be `mo_test_{}_queue`.
    *   The `{}` placeholder in the template is replaced by specific queue types during the setup process. These types are defined internally by the orchestrator (e.g., `WorkerTrigger`, `BatchingQueue`, `SnosInputQueue`, `ProvingJobQueue`, `RegistrationJobQueue`, `DataSubmissionJobQueue`, `StateUpdateJobQueue`).
        *   Example: For the `WorkerTrigger` queue type, the name would become `mo_test_WorkerTrigger_queue`.
    *   If `MADARA_ORCHESTRATOR_AWS_SQS_QUEUE_IDENTIFIER` is an ARN, the prefixing logic is skipped. The resource part of the ARN is used as the base, and the queue type is appended to it to form the final queue name.
*   **Creation Logic:**
    *   The setup process iterates through a predefined list of internal queue types.
    *   For each type, it constructs the queue name and checks if an SQS queue with that name already exists.
    *   If the queue exists, its creation is skipped.
    *   If the queue does not exist, a new SQS queue is created.
*   **Dead Letter Queues (DLQs):**
    *   Certain queues are configured to have Dead Letter Queues (DLQs).
    *   If a main queue is configured with a DLQ, the setup process also creates this DLQ if it doesn't already exist.
    *   DLQ names are typically formed by taking the main queue's name and appending a `_dlq` suffix.
        *   Example: If the main queue is `mo_test_WorkerTrigger_queue`, its DLQ would be `mo_test_WorkerTrigger_queue_dlq`.
*   **Queue Policies and Attributes:**
    *   **RedrivePolicy:** For main queues that have an associated DLQ, a `RedrivePolicy` is configured. This policy dictates how messages are moved from the main queue to the DLQ.
        *   `deadLetterTargetArn`: This is set to the ARN of the corresponding DLQ.
        *   `maxReceiveCount`: This specifies the maximum number of times a message can be received from the main queue before it is moved to the DLQ. The typical value observed in the codebase for this is 5.
        *   The JSON structure for this part of the policy attached to the main queue looks like:
            ```json
            {
              "RedrivePolicy": "{\"deadLetterTargetArn\":\"arn:aws:sqs:REGION:ACCOUNT_ID:DLQ_NAME\",\"maxReceiveCount\":\"5\"}"
            }
            ```
            *(Note: The above is a stringified JSON embedded within the queue attributes. `REGION`, `ACCOUNT_ID`, and `DLQ_NAME` would be substituted with actual values.)*
    *   **VisibilityTimeout:** Queue attributes such as `VisibilityTimeout` are also set based on internal configurations for each queue type. For example, the `WorkerTrigger` queue has a visibility timeout of 300 seconds.
*   **Checking for Existence:** The system checks for both main queues and their DLQs before attempting creation. If an ARN is provided as the identifier, it uses `GetQueueAttributes` to check; otherwise, it uses `GetQueueUrl`.


# 3. EventBridge (Scheduler/Rules) Setup

*   **Order of Creation:** EventBridge resources are provisioned after the SQS queues have been successfully set up and are ready. The system explicitly waits for queue readiness before proceeding with EventBridge setup.
*   **Prerequisite:** This setup assumes an SQS queue, specifically one for `WorkerTrigger` events, is available. The ARN of this queue will be used in the IAM policy.

*   **IAM Role and Policy for EventBridge:**
    *   An IAM role and an IAM policy are created to grant EventBridge (specifically the Scheduler service or standard EventBridge rules) permissions to send messages to the SQS `WorkerTrigger` queue.
    *   **IAM Role:**
        *   **Name Determination:** The role name is constructed using the `MADARA_ORCHESTRATOR_AWS_PREFIX` environment variable (if set) and a fixed suffix, along with a random short ID.
            *   Format: `{PREFIX}-mo-wt-role-{RANDOM_ID}` (e.g., `mo-mo-wt-role-1a2b`) or `mo-wt-role-{RANDOM_ID}` if no prefix is set. The `{RANDOM_ID}` is a 4-character hexadecimal string.
        *   **Trust Policy:** The role has a trust relationship policy that allows the `scheduler.amazonaws.com` and `events.amazonaws.com` services to assume this role.
            *   The JSON for this trust policy is:
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
    *   **IAM Policy:**
        *   **Name Determination:** The policy name is constructed similarly to the role name, using the `MADARA_ORCHESTRATOR_AWS_PREFIX` (if set) and a fixed suffix, plus the same random short ID.
            *   Format: `{PREFIX}-mo-wt-policy-{RANDOM_ID}` (e.g., `mo-mo-wt-policy-1a2b`) or `mo-wt-policy-{RANDOM_ID}`.
        *   **Policy Document:** This policy grants the `sqs:SendMessage` permission to the specific SQS queue used for worker triggers.
            *   The JSON for this policy document is (where `{TARGET_QUEUE_ARN}` is replaced with the actual ARN of the `WorkerTrigger` SQS queue):
                ```json
                {
                  "Version": "2012-10-17",
                  "Statement": [{
                    "Effect": "Allow",
                    "Action": ["sqs:SendMessage"],
                    "Resource": "{TARGET_QUEUE_ARN}"
                  }]
                }
                ```
        *   **Attachment:** This IAM policy is attached to the IAM role created above.

*   **EventBridge Rules or Schedules:**
    *   The orchestrator creates scheduled events to trigger various worker processes. This can be done via EventBridge Rules or EventBridge Scheduler, based on the `MADARA_ORCHESTRATOR_EVENT_BRIDGE_TYPE` environment variable (`Rule` or `Schedule`).
    *   **Name Determination:**
        *   The names for these rules/schedules are based on the `MADARA_ORCHESTRATOR_AWS_PREFIX` (if set) and the specific worker trigger type (e.g., `Snos`, `Proving`).
        *   Format: `{PREFIX}-mo-wt-rule-{TRIGGER_TYPE}` (e.g., `mo-mo-wt-rule-Snos`) or `mo-wt-rule-{TRIGGER_TYPE}`.
    *   **Configuration Details:**
        *   **Schedule Expression:** The schedule is determined by the `MADARA_ORCHESTRATOR_EVENT_BRIDGE_INTERVAL_SECONDS` environment variable (default is 60 seconds). This is converted into a rate expression, e.g., `rate(1 minute)`.
        *   **State:** Rules are created in an `ENABLED` state.
        *   **Target (for Rules and Schedules):**
            *   `Arn`: The ARN of the SQS `WorkerTrigger` queue.
            *   `RoleArn` (required for Scheduler): The ARN of the IAM role created earlier is used by the EventBridge Scheduler to authorize sending messages to the SQS target.
            *   `InputTransformer` (for Rules) / `Input` (for Schedules): The message sent to the SQS queue is customized. Typically, this is a string representing the trigger type (e.g., `"Snos"`).
                *   For Rules, an `InputTransformer` might be configured as: `{"inputPathsMap":{"time":"$.time"},"inputTemplate":"\"Snos\""}` (the exact template can vary per trigger).
                *   For Schedules, the `Input` is directly the message string, e.g., `"Snos"`.
    *   **Creation Logic:**
        *   The setup iterates through a predefined list of `WORKER_TRIGGERS` (e.g., `Snos`, `Proving`, `Batching`, `DataSubmission`, `UpdateState`, `ProofRegistration` - noting `ProofRegistration` might be layer-specific).
        *   For each trigger type, it checks if a rule/schedule with the determined name already exists.
        *   If it exists, creation is skipped. Otherwise, a new rule/schedule is created and the target is configured.
    *   A delay (e.g., 15 seconds) is introduced after creating the IAM role and policy before setting up the rules/schedules to allow for IAM propagation.


# 4. SNS Topic Setup

*   **Order of Creation:** SNS topics are provisioned after the SQS queues have been successfully set up and are ready. The system explicitly waits for SQS queue readiness before attempting to set up SNS topics.
*   **Naming Convention:**
    *   The primary identifier for the topic name is taken from the `MADARA_ORCHESTRATOR_AWS_SNS_TOPIC_IDENTIFIER` environment variable. For example, if set to `test`.
    *   If the `MADARA_ORCHESTRATOR_AWS_PREFIX` environment variable is set (e.g., to `mo`), this prefix is prepended to the topic identifier, separated by an underscore.
    *   The final topic name follows the format: `{PREFIX}_{TOPIC_IDENTIFIER}`.
        *   Example: If `MADARA_ORCHESTRATOR_AWS_PREFIX="mo"` and `MADARA_ORCHESTRATOR_AWS_SNS_TOPIC_IDENTIFIER="test"`, the resulting topic name will be `mo_test`.
    *   If `MADARA_ORCHESTRATOR_AWS_SNS_TOPIC_IDENTIFIER` is an ARN (e.g., `arn:aws:sns:us-east-1:123456789012:my-actual-topic`), the prefixing logic is skipped, and the provided ARN's resource part is used as the topic name.
*   **Creation Logic:**
    *   The setup process first determines the topic name based on the environment variables.
    *   It then validates the topic name to ensure it consists of letters, numbers, hyphens, and underscores.
    *   It checks if an SNS topic with the determined name (or specified ARN) already exists.
        *   If an ARN is provided, `GetTopicAttributes` is used.
        *   If a name is provided, the system attempts to fetch the topic ARN by its name.
    *   If the topic already exists, its creation is skipped, and a warning message is logged.
    *   If the topic does not exist and a name was provided (not an ARN), a new SNS topic is created with that name. If an ARN was provided, and it didn't exist, this would typically result in an error earlier, but the code path primarily focuses on creation via name if it's not found by ARN.
*   **Topic Policies:**
    *   The orchestrator's setup process, as analyzed for this specific documentation task, does not create or attach any custom SNS topic policies (e.g., access policies defining who can publish or subscribe). The topic will be created with default AWS SNS permissions and settings. Any necessary subscriptions or specific access controls would need to be configured separately after this initial setup.

# 5. General Information and Environment Variables

This document outlines the AWS resource provisioning process performed by the orchestrator's `setup` command. The setup is sequential, and certain resources depend on the prior creation and readiness of others.

**Key Environment Variables:**

The following environment variables are crucial for configuring the AWS resource setup:

*   `MADARA_ORCHESTRATOR_AWS_PREFIX`:
    *   **Description:** A prefix string that will be added to the names of most AWS resources created by the orchestrator. This helps in namespacing and identifying resources belonging to a specific deployment.
    *   **Example:** `mo`

*   `MADARA_ORCHESTRATOR_AWS_S3_BUCKET_IDENTIFIER`:
    *   **Description:** Specifies the base name or ARN for the S3 bucket used for storage.
    *   **Example (Name):** `test-bucket` (results in `mo-test-bucket` if prefix is `mo`)
    *   **Example (ARN):** `arn:aws:s3:::my-specific-bucket` (prefix is ignored)
    *   **Default (from code):** `mo-bucket` (this is the CLI default, if the env var is not set, this base name is used, and the prefix applies if present)

*   `MADARA_ORCHESTRATOR_AWS_SQS_QUEUE_IDENTIFIER`:
    *   **Description:** A template string for naming SQS queues. The `{}` placeholder will be replaced with specific queue types (e.g., `WorkerTrigger`, `BatchingQueue`).
    *   **Example (Name Template):** `test_{}_queue` (results in `mo_test_WorkerTrigger_queue` for the WorkerTrigger queue if prefix is `mo`)
    *   **Example (ARN Template):** `arn:aws:sqs:us-east-1:123456789012:my_base_queue_{}` (prefix is ignored, but type substitution still occurs on the resource part)
    *   **Default (from code):** `mo_{}_queue` (CLI default, prefix applies if present)

*   `MADARA_ORCHESTRATOR_AWS_SNS_TOPIC_IDENTIFIER`:
    *   **Description:** Specifies the base name or ARN for the SNS topic used for alerts/notifications.
    *   **Example (Name):** `test` (results in `mo_test` if prefix is `mo`)
    *   **Example (ARN):** `arn:aws:sns:us-east-1:123456789012:my-specific-topic` (prefix is ignored)
    *   **Default (from code):** `alerts` (CLI default, prefix applies if present)

*   `MADARA_ORCHESTRATOR_EVENT_BRIDGE_TYPE`:
    *   **Description:** Determines whether to use EventBridge Rules or EventBridge Scheduler for cron-like job triggers.
    *   **Possible Values:** `Rule`, `Schedule`
    *   **Default:** Not explicitly defaulted in `AWSEventBridgeCliArgs` parsing, so it must be provided if `aws_event_bridge` is true. The `SetupCmd` makes it a required group.

*   `MADARA_ORCHESTRATOR_EVENT_BRIDGE_INTERVAL_SECONDS`:
    *   **Description:** The interval in seconds at which the EventBridge rules/schedules will trigger. This is converted into a rate expression (e.g., 60 seconds becomes `rate(1 minute)`).
    *   **Default:** `60`

**AWS SDK Environment Variables:**

The orchestrator uses the standard AWS SDK for Rust. Therefore, AWS credentials and region configuration are typically handled by the SDK using environment variables like:

*   `AWS_ACCESS_KEY_ID`: Your AWS access key.
*   `AWS_SECRET_ACCESS_KEY`: Your AWS secret key.
*   `AWS_SESSION_TOKEN` (if using temporary credentials).
*   `AWS_REGION`: The AWS region where resources should be provisioned (e.g., `us-east-1`). This is important for services that are region-specific.
*   Alternatively, configuration can be managed via shared AWS configuration files (`~/.aws/config` and `~/.aws/credentials`).

**Setup Command Miscellaneous Arguments:**

The `setup` command also accepts the following arguments (which can be set via environment variables):

*   `MADARA_ORCHESTRATOR_SETUP_TIMEOUT` (`--timeout`):
    *   **Description:** The maximum time (in seconds) to wait for certain resources (like SQS queues) to become ready during setup polling.
    *   **Default:** `300` seconds.

*   `MADARA_ORCHESTRATOR_SETUP_RESOURCE_POLL_INTERVAL` (`--poll-interval`):
    *   **Description:** The interval (in seconds) at which the system polls for resource readiness during setup.
    *   **Default:** `5` seconds.

**Resource Naming Summary:**

*   **S3 Buckets:** `{PREFIX}-{BUCKET_IDENTIFIER}`
*   **SQS Queues:** `{PREFIX}_{QUEUE_IDENTIFIER_TEMPLATE_BASE}_{QUEUE_TYPE}_queue` (assuming template includes `{}_queue`)
*   **SNS Topics:** `{PREFIX}_{TOPIC_IDENTIFIER}`
*   **EventBridge Role:** `{PREFIX}-mo-wt-role-{RANDOM_ID}`
*   **EventBridge Policy:** `{PREFIX}-mo-wt-policy-{RANDOM_ID}`
*   **EventBridge Rule/Schedule:** `{PREFIX}-mo-wt-rule-{TRIGGER_TYPE}`

*(If `MADARA_ORCHESTRATOR_AWS_PREFIX` is not set, the `{PREFIX}-` or `{PREFIX}_` part is omitted from the names.)*


