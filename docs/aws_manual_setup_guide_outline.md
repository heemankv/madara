# Orchestrator AWS Manual Setup Guide (AWS CLI) - Outline

1.  **Introduction:**
    *   Purpose of the guide: To provide step-by-step instructions for manually provisioning the necessary AWS resources for the Madara Orchestrator using the AWS CLI.
    *   Target audience: Users with intermediate AWS proficiency comfortable with using the AWS CLI.
    *   Disclaimer: This guide mirrors the automated `setup` command. Users should ensure they understand the implications of creating these resources in their AWS account. Reference to the *Orchestrator AWS Setup Documentation* for conceptual understanding.

2.  **Prerequisites:**
    *   AWS CLI: Installed and configured with an AWS account and appropriate permissions to create S3, SQS, IAM roles/policies, EventBridge rules/schedules, and SNS topics.
    *   Environment Variables (User Decision): Instruct users to decide on values for the following environment variables and set them in their shell session (e.g., using `export VAR_NAME="value"`). These will be used throughout the guide as placeholders (e.g., `${MADARA_ORCHESTRATOR_AWS_PREFIX}`).
        *   `MADARA_ORCHESTRATOR_AWS_PREFIX` (e.g., `mo`)
        *   `MADARA_ORCHESTRATOR_AWS_S3_BUCKET_IDENTIFIER` (e.g., `my-orchestrator-bucket`)
        *   `MADARA_ORCHESTRATOR_AWS_SQS_QUEUE_IDENTIFIER_TEMPLATE` (e.g., `my_orchestrator_{}_queue`)
        *   `MADARA_ORCHESTRATOR_AWS_SNS_TOPIC_IDENTIFIER` (e.g., `my-orchestrator-alerts`)
        *   `MADARA_ORCHESTRATOR_EVENT_BRIDGE_TYPE` (`Rule` or `Schedule`)
        *   `MADARA_ORCHESTRATOR_EVENT_BRIDGE_INTERVAL_SECONDS` (e.g., `60`)
        *   `AWS_REGION` (e.g., `us-east-1`) - Emphasize this needs to be a region where all required services are available.
    *   (Optional) JSON processor like `jq` for easier extraction of ARNs from CLI outputs.

3.  **Step 1: S3 Bucket Setup:**
    *   Instructions for deriving the bucket name.
    *   AWS CLI command for creation.
    *   Verification command.
    *   Basic troubleshooting.

4.  **Step 2: SQS Queues Setup:**
    *   List of required queue types (e.g., `WorkerTrigger`, `BatchingQueue`, etc. - this list needs to be extracted from the codebase, specifically `orchestrator/src/setup/queue.rs`).
    *   For each queue type:
        *   Instructions for deriving main queue name and DLQ name (if applicable).
        *   CLI command for main queue creation with attributes.
        *   CLI command for DLQ creation (if applicable).
        *   CLI command for getting DLQ ARN (if applicable).
        *   CLI command for setting RedrivePolicy on the main queue (if applicable).
        *   Verification commands.
    *   Basic troubleshooting.

5.  **Step 3: IAM Role and Policy for EventBridge:**
    *   Instructions for deriving policy and role names.
    *   Creating the policy document (JSON file).
    *   CLI command for IAM policy creation.
    *   Creating the role trust policy document (JSON file).
    *   CLI command for IAM role creation.
    *   CLI command for attaching policy to role.
    *   Verification commands.
    *   Basic troubleshooting.

6.  **Step 4: EventBridge (Scheduler/Rules) Setup:**
    *   User choice: `Rule` vs. `Schedule`.
    *   List of `WORKER_TRIGGERS` (from `orchestrator/src/setup/aws/event_bus.rs`).
    *   For each trigger:
        *   Instructions for deriving rule/schedule name.
        *   CLI commands for creation (specific to Rule or Schedule).
        *   CLI commands for adding targets (specific to Rule or Schedule, including Input/InputTransformer).
        *   Verification commands.
    *   Basic troubleshooting.

7.  **Step 5: SNS Topic Setup:**
    *   Instructions for deriving topic name.
    *   CLI command for creation.
    *   Verification command.
    *   Basic troubleshooting.

8.  **Verification Summary:**
    *   Brief list of commands to check all created resources.

9.  **Cleanup (Optional):**
    *   Brief guidance or AWS CLI commands on how to delete the created resources if needed (reverse order of creation).

10. **Conclusion:**
    *   Recap of resources created.
    *   Next steps (e.g., running the orchestrator).
