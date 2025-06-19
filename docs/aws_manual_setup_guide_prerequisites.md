## 2. Prerequisites

Before you begin, ensure you have the following:

1.  **AWS Command Line Interface (AWS CLI):**
    *   Installed on your system. If not, follow the official AWS documentation: [Installing or updating the latest version of the AWS CLI](https://docs.aws.amazon.com/cli/latest/userguide/getting-started-install.html)
    *   Configured with your AWS account credentials and a default region. Run `aws configure` if you haven't already.
        ```bash
        aws configure
        # AWS Access Key ID [None]: YOUR_ACCESS_KEY
        # AWS Secret Access Key [None]: YOUR_SECRET_KEY
        # Default region name [None]: YOUR_AWS_REGION (e.g., us-east-1)
        # Default output format [None]: json
        ```
    *   Ensure the IAM user associated with your credentials has sufficient permissions to create S3 buckets, SQS queues, IAM roles and policies, EventBridge rules/schedules, and SNS topics. Administrator access is generally sufficient for a personal/test account, but for production environments, adhere to the principle of least privilege.

2.  **Define and Export Environment Variables:**
    *   The following environment variables are used throughout this guide to refer to resource names and configurations. Decide on the values you want to use for your setup, then `export` them in your terminal session. This will allow you to copy and paste the AWS CLI commands directly.
    *   Replace the example values with your desired configuration.

    ```bash
    # --- Configuration Variables ---

    # Prefix for most AWS resources (helps in namespacing)
    # Example: mo
    export MADARA_ORCHESTRATOR_AWS_PREFIX="mo"

    # Base name for the S3 bucket
    # Example: my-orchestrator-bucket
    export MADARA_ORCHESTRATOR_AWS_S3_BUCKET_IDENTIFIER="my-orchestrator-bucket"

    # Template for SQS queue names. {} is replaced by queue type.
    # Example: my_orchestrator_{}_queue
    export MADARA_ORCHESTRATOR_AWS_SQS_QUEUE_IDENTIFIER_TEMPLATE="my_orchestrator_{}_queue"

    # Base name for the SNS topic
    # Example: my-orchestrator-alerts
    export MADARA_ORCHESTRATOR_AWS_SNS_TOPIC_IDENTIFIER="my-orchestrator-alerts"

    # Type of EventBridge trigger: 'Rule' or 'Schedule'
    # The orchestrator codebase supports both. 'Schedule' is generally newer.
    export MADARA_ORCHESTRATOR_EVENT_BRIDGE_TYPE="Schedule"

    # Interval in seconds for EventBridge triggers
    # Example: 60 (for 1 minute)
    export MADARA_ORCHESTRATOR_EVENT_BRIDGE_INTERVAL_SECONDS="60"

    # AWS Region where resources will be created
    # This should match your AWS CLI default region if possible.
    # Example: us-east-1
    export AWS_REGION="us-east-1"

    # --- Helper Variables (Derived from above) ---
    # These are constructed here for convenience and used in later commands.

    export S3_BUCKET_NAME="${MADARA_ORCHESTRATOR_AWS_PREFIX}-${MADARA_ORCHESTRATOR_AWS_S3_BUCKET_IDENTIFIER}"
    export SNS_TOPIC_NAME="${MADARA_ORCHESTRATOR_AWS_PREFIX}_${MADARA_ORCHESTRATOR_AWS_SNS_TOPIC_IDENTIFIER}"

    # EventBridge names (will have a random suffix added by AWS or during creation for role/policy)
    export EB_ROLE_NAME_BASE="${MADARA_ORCHESTRATOR_AWS_PREFIX}-mo-wt-role"
    export EB_POLICY_NAME_BASE="${MADARA_ORCHESTRATOR_AWS_PREFIX}-mo-wt-policy"
    export EB_RULE_NAME_BASE="${MADARA_ORCHESTRATOR_AWS_PREFIX}-mo-wt-rule" # Trigger type will be appended

    echo "Variables set. Your S3 bucket will be named: ${S3_BUCKET_NAME}"
    echo "Your SNS topic will be named: ${SNS_TOPIC_NAME}"
    ```
    *   **Important:** Ensure `AWS_REGION` is a region where all required services (S3, SQS, IAM, EventBridge, SNS) are available.

3.  **(Optional) `jq` Utility:**
    *   A command-line JSON processor. It's helpful for extracting ARNs or other specific values from AWS CLI JSON outputs.
    *   Installation instructions can be found at [stedolan.github.io/jq/download/](https://stedolan.github.io/jq/download/).

Once these prerequisites are met, you can proceed with the resource creation steps.
