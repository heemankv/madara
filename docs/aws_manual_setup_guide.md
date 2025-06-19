# Orchestrator AWS Manual Setup Guide (AWS CLI)

## 1. Introduction

This guide provides step-by-step instructions for manually provisioning the necessary AWS resources for the Madara Orchestrator using the AWS Command Line Interface (AWS CLI). It is intended for users who have at least intermediate proficiency with AWS and are comfortable using the AWS CLI.

**Purpose:** To offer a manual alternative to the orchestrator's automated `setup` command, giving users a transparent way to create and manage their AWS infrastructure.

**Disclaimer:**
*   This guide mirrors the functionality of the automated `setup` command. You are responsible for the resources created in your AWS account and any associated costs.
*   It is highly recommended to first read the **Orchestrator AWS Setup Documentation** (`aws_setup_documentation.md`) to understand the purpose, naming conventions, and configuration of each resource before proceeding with manual creation.
*   The commands and scripts provided are for guidance. You may need to adapt them based on your specific shell environment, AWS CLI version, or desired modifications.
*   Always ensure your AWS CLI is configured with the correct account and region before running commands that modify resources.

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

## 3. Step 1: S3 Bucket Setup

This section guides you through creating the S3 bucket required by the orchestrator.

**1. Bucket Name:**
The bucket name is derived from the environment variables you set in the Prerequisites section: `MADARA_ORCHESTRATOR_AWS_PREFIX` and `MADARA_ORCHESTRATOR_AWS_S3_BUCKET_IDENTIFIER`.
The combined name is stored in the `${S3_BUCKET_NAME}` variable.

**2. Create the S3 Bucket:**

*   **For `us-east-1` region:**
    ```bash
    if [ "${AWS_REGION}" == "us-east-1" ]; then
      aws s3api create-bucket \
        --bucket "${S3_BUCKET_NAME}" \
        --region "${AWS_REGION}"
    fi
    ```

*   **For other regions (e.g., `us-west-2`, `eu-central-1`, etc.):**
    S3 requires a `LocationConstraint` for regions other than `us-east-1`.
    ```bash
    if [ "${AWS_REGION}" != "us-east-1" ]; then
      aws s3api create-bucket \
        --bucket "${S3_BUCKET_NAME}" \
        --region "${AWS_REGION}" \
        --create-bucket-configuration LocationConstraint="${AWS_REGION}"
    fi
    ```

    *Example Output (Success):*
    ```json
    {
        "Location": "/your-bucket-name"
    }
    ```
    *(Note: For us-east-1, the location might be `http://your-bucket-name.s3.amazonaws.com/` in older CLI versions, or just the bucket name in newer ones. The command above produces no JSON output on success for `us-east-1` unless `--output json` is explicitly passed again by the user's AWS CLI config).*


**3. Verify Bucket Creation:**

You can verify that the bucket was created successfully by using the `head-bucket` command:

```bash
aws s3api head-bucket --bucket "${S3_BUCKET_NAME}"
```
*If successful, this command will return no output and have an exit code of 0. If it fails, you'll see an error message.*

*Alternative Verification (List Buckets - might show many if you have others):*
```bash
aws s3 ls | grep "${S3_BUCKET_NAME}"
```

**4. Basic Troubleshooting:**

*   **Error:** `An error occurred (BucketAlreadyOwnedByYou) when calling the CreateBucket operation: Your previous request to create the named bucket succeeded and you already own it.`
    *   **Cause:** You've already created a bucket with this name in your account.
    *   **Solution:** No action needed if you intend to use the existing bucket. Otherwise, choose a different `MADARA_ORCHESTRATOR_AWS_S3_BUCKET_IDENTIFIER` or `MADARA_ORCHESTRATOR_AWS_PREFIX`.

*   **Error:** `An error occurred (BucketAlreadyExists) when calling the CreateBucket operation: The requested bucket name is not available. The bucket namespace is shared by all users of the system. Please select a different name and try again.`
    *   **Cause:** S3 bucket names are globally unique. Someone else has already taken this bucket name.
    *   **Solution:** Choose a different (more unique) `MADARA_ORCHESTRATOR_AWS_S3_BUCKET_IDENTIFIER`. Adding a unique suffix or using a more specific prefix can help.

*   **Error:** `An error occurred (IllegalLocationConstraintException) when calling the CreateBucket operation: The unspecified location constraint is incompatible for the region specific endpoint this request was sent to.`
    *   **Cause:** You are trying to create a bucket in a region other than `us-east-1` without specifying the `LocationConstraint`, or you specified `us-east-1` as a location constraint which is not allowed.
    *   **Solution:** Ensure you are using the correct command block from step 2 based on your `${AWS_REGION}`. The script provided attempts to handle this.

*   **Permissions Error:** If you get an `AccessDenied` error.
    *   **Cause:** The IAM user/role whose credentials you are using does not have `s3:CreateBucket` permissions.
    *   **Solution:** Update the IAM user/role permissions to allow this action.
---

Next, you will set up the SQS queues.

## 4. Step 2: SQS Queues Setup

This section details the creation of Simple Queue Service (SQS) queues. The orchestrator uses multiple queues for different tasks. Some queues are configured with Dead Letter Queues (DLQs) to handle message processing failures.

**Important Notes:**
*   Queue names are constructed using the `${MADARA_ORCHESTRATOR_AWS_SQS_QUEUE_IDENTIFIER_TEMPLATE}` environment variable, where `{}` is replaced by the `QueueType` string.
    *   Example: If template is `my_orchestrator_{}_queue` and `QueueType` is `SnosJobProcessing`, the queue name becomes `my_orchestrator_SnosJobProcessing_queue`.
*   DLQ names also follow this pattern, e.g., `my_orchestrator_JobHandleFailure_queue_dlq` (though the code uses the `dlq_name` directly from `DlqConfig` which is another `QueueType`).
*   The commands below assume you have `jq` installed for extracting ARNs. If not, you'll need to copy ARNs manually from the AWS CLI output.
*   We will create the `JobHandleFailure` queue first, as it's used as the DLQ for many other queues.
*   For simplicity, this guide assumes you are setting up for a layer that supports all defined queues (e.g., L3, or L2 if not using ProofRegistration specific queues). Adjust if your target layer is different, by skipping queues not in `supported_layers` for your target. The `QUEUES` definition in the code specifies `supported_layers` for each queue.

```bash
# Helper function to construct queue names based on the template
get_queue_name() {
  local queue_type=$1
  echo "${MADARA_ORCHESTRATOR_AWS_SQS_QUEUE_IDENTIFIER_TEMPLATE//\{\}/${queue_type}}"
}

# --- 1. JobHandleFailure Queue (Common DLQ) ---
JOB_HANDLE_FAILURE_QUEUE_TYPE="JobHandleFailure"
JOB_HANDLE_FAILURE_QUEUE_NAME=$(get_queue_name "${JOB_HANDLE_FAILURE_QUEUE_TYPE}")
JOB_HANDLE_FAILURE_VISIBILITY_TIMEOUT=300 # From QueueConfig

echo "Creating JobHandleFailure queue: ${JOB_HANDLE_FAILURE_QUEUE_NAME}"
aws sqs create-queue \
  --queue-name "${JOB_HANDLE_FAILURE_QUEUE_NAME}" \
  --attributes VisibilityTimeout="${JOB_HANDLE_FAILURE_VISIBILITY_TIMEOUT}" \
  --region "${AWS_REGION}"

# Get JobHandleFailure Queue ARN and URL (used as DLQ Target ARN later)
JOB_HANDLE_FAILURE_QUEUE_URL=$(aws sqs get-queue-url --queue-name "${JOB_HANDLE_FAILURE_QUEUE_NAME}" --query 'QueueUrl' --output text --region "${AWS_REGION}")
JOB_HANDLE_FAILURE_QUEUE_ARN=$(aws sqs get-queue-attributes --queue-url "${JOB_HANDLE_FAILURE_QUEUE_URL}" --attribute-names QueueArn --query 'Attributes.QueueArn' --output text --region "${AWS_REGION}")
echo "JobHandleFailure Queue ARN: ${JOB_HANDLE_FAILURE_QUEUE_ARN}"
echo "JobHandleFailure Queue URL: ${JOB_HANDLE_FAILURE_QUEUE_URL}"

# --- 2. WorkerTrigger Queue ---
WORKER_TRIGGER_QUEUE_TYPE="WorkerTrigger"
WORKER_TRIGGER_QUEUE_NAME=$(get_queue_name "${WORKER_TRIGGER_QUEUE_TYPE}")
WORKER_TRIGGER_VISIBILITY_TIMEOUT=300 # From QueueConfig

echo "Creating WorkerTrigger queue: ${WORKER_TRIGGER_QUEUE_NAME}"
aws sqs create-queue \
  --queue-name "${WORKER_TRIGGER_QUEUE_NAME}" \
  --attributes VisibilityTimeout="${WORKER_TRIGGER_VISIBILITY_TIMEOUT}" \
  --region "${AWS_REGION}"

export WORKER_TRIGGER_QUEUE_URL=$(aws sqs get-queue-url --queue-name "${WORKER_TRIGGER_QUEUE_NAME}" --query 'QueueUrl' --output text --region "${AWS_REGION}")
export WORKER_TRIGGER_QUEUE_ARN=$(aws sqs get-queue-attributes --queue-url "${WORKER_TRIGGER_QUEUE_URL}" --attribute-names QueueArn --query 'Attributes.QueueArn' --output text --region "${AWS_REGION}")
echo "WorkerTrigger Queue URL: ${WORKER_TRIGGER_QUEUE_URL}"
echo "WorkerTrigger Queue ARN: ${WORKER_TRIGGER_QUEUE_ARN}"


# --- 3. Other Queues (with DLQ pointing to JobHandleFailure) ---
# Define arrays from the QueueConfig structure
QUEUE_TYPES=(
  "SnosJobProcessing"
  "SnosJobVerification"
  "ProvingJobProcessing"
  "ProvingJobVerification"
  "ProofRegistrationJobProcessing" # L3 only in provided config
  "ProofRegistrationJobVerification" # L3 only in provided config
  "DataSubmissionJobProcessing"
  "DataSubmissionJobVerification"
  "UpdateStateJobProcessing"
  "UpdateStateJobVerification"
)

VISIBILITY_TIMEOUTS=(
  300 # SnosJobProcessing
  300 # SnosJobVerification
  300 # ProvingJobProcessing
  300 # ProvingJobVerification
  300 # ProofRegistrationJobProcessing
  300 # ProofRegistrationJobVerification
  300 # DataSubmissionJobProcessing
  300 # DataSubmissionJobVerification
  900 # UpdateStateJobProcessing
  300 # UpdateStateJobVerification
)

# All these queues use JobHandleFailure as their DLQ with maxReceiveCount: 5
DLQ_TARGET_ARN="${JOB_HANDLE_FAILURE_QUEUE_ARN}"
MAX_RECEIVE_COUNT=5

for i in "${!QUEUE_TYPES[@]}"; do
  QUEUE_TYPE="${QUEUE_TYPES[$i]}"
  MAIN_QUEUE_NAME=$(get_queue_name "${QUEUE_TYPE}")
  VISIBILITY_TIMEOUT="${VISIBILITY_TIMEOUTS[$i]}"

  # Skip L3 queues if not setting up for L3 (manual check by user for now)
  # if [[ "${QUEUE_TYPE}" == "ProofRegistrationJobProcessing" || "${QUEUE_TYPE}" == "ProofRegistrationJobVerification" ]]; then
  #   echo "Skipping ${QUEUE_TYPE} as it is L3 specific. Adjust if needed."
  #   continue
  # fi

  echo "--- Creating Main Queue: ${MAIN_QUEUE_NAME} ---"

  # Create the main queue
  MAIN_QUEUE_URL=$(aws sqs create-queue \
    --queue-name "${MAIN_QUEUE_NAME}" \
    --attributes VisibilityTimeout="${VISIBILITY_TIMEOUT}" \
    --query 'QueueUrl' --output text --region "${AWS_REGION}")

  echo "Main Queue ${MAIN_QUEUE_NAME} URL: ${MAIN_QUEUE_URL}"

  # Set Redrive Policy
  REDRIVE_POLICY=$(cat <<EOF
{
  "deadLetterTargetArn": "${DLQ_TARGET_ARN}",
  "maxReceiveCount": "${MAX_RECEIVE_COUNT}"
}
EOF
)

  echo "Setting Redrive Policy for ${MAIN_QUEUE_NAME}..."
  aws sqs set-queue-attributes \
    --queue-url "${MAIN_QUEUE_URL}" \
    --attributes RedrivePolicy="${REDRIVE_POLICY}" \
    --region "${AWS_REGION}"

  echo "Configuration complete for queue: ${MAIN_QUEUE_NAME}"
  echo "-------------------------------------"
done

```

**Verification:**

For each queue created, you can verify its attributes:
```bash
# Example for SnosJobProcessing queue
QUEUE_NAME_TO_VERIFY=$(get_queue_name "SnosJobProcessing")
QUEUE_URL_TO_VERIFY=$(aws sqs get-queue-url --queue-name "${QUEUE_NAME_TO_VERIFY}" --query 'QueueUrl' --output text --region "${AWS_REGION}")

aws sqs get-queue-attributes \
  --queue-url "${QUEUE_URL_TO_VERIFY}" \
  --attribute-names All --region "${AWS_REGION}"
```
*   Check the `VisibilityTimeout` and `RedrivePolicy` (it will be a stringified JSON).

**Basic Troubleshooting:**

*   **Error:** `AWS.SimpleQueueService.NonExistentQueue: The specified queue does not exist...`
    *   **Cause:** Often occurs if a DLQ ARN is incorrect when setting the `RedrivePolicy`, or a queue name is mistyped.
    *   **Solution:** Double-check the queue names and ensure the DLQ (`JobHandleFailure` queue) was created successfully and its ARN is correctly used. Verify environment variables.
*   **Error:** `InvalidParameterValue: Value { ... } for parameter RedrivePolicy is invalid. Reason: Dead letter target does not exist.`
    *   **Cause:** The `deadLetterTargetArn` provided in the `RedrivePolicy` does not point to an existing SQS queue.
    *   **Solution:** Ensure `JobHandleFailure` queue is created and its ARN is correctly captured and used.
*   **Permissions Error:** `AccessDenied` when creating queues or setting attributes.
    *   **Cause:** IAM user/role lacks `sqs:CreateQueue`, `sqs:GetQueueUrl`, `sqs:GetQueueAttributes`, or `sqs:SetQueueAttributes` permissions.
    *   **Solution:** Update IAM permissions.

---
Next, you will set up the IAM Role and Policy required for EventBridge.

## 5. Step 3: IAM Role and Policy for EventBridge

EventBridge (or Scheduler) requires permissions to send messages to the SQS `WorkerTrigger` queue. This is achieved by creating an IAM policy with the necessary permissions and an IAM role that EventBridge can assume, with this policy attached.

**1. Define IAM Resource Names:**
The base names for the role and policy are defined by the `${EB_ROLE_NAME_BASE}` and `${EB_POLICY_NAME_BASE}` environment variables. A unique suffix (like a random ID or a specific chosen one) is often appended by AWS or can be added by you if you need to distinguish multiple instances. For this guide, we'll use the base names and let AWS handle unique ID generation or assume you'll ensure they are unique if you modify them. The orchestrator code appends a random 4-character hex string. For manual setup, you can choose a memorable suffix if needed, or use the base name if it's unique in your account for this purpose.

```bash
# You can add a unique suffix if you prefer, e.g., MySuffix123
# For simplicity, we'll use the base names here, assuming they are sufficiently unique
# or that you will manage uniqueness if creating multiple setups.
# The orchestrator code adds a random suffix like "-1a2b".
# Let's define a short random suffix for this manual guide for better uniqueness.
MANUAL_SUFFIX=$(head /dev/urandom | tr -dc A-Za-z0-9 | head -c 4) # Simple random suffix

export EB_POLICY_NAME="${EB_POLICY_NAME_BASE}-${MANUAL_SUFFIX}"
export EB_ROLE_NAME="${EB_ROLE_NAME_BASE}-${MANUAL_SUFFIX}"

echo "IAM Policy will be named: ${EB_POLICY_NAME}"
echo "IAM Role will be named: ${EB_ROLE_NAME}"
```

**2. Create IAM Policy for SQS SendMessage:**

*   **Create the policy document JSON file:**
    This policy allows the `sqs:SendMessage` action to your `WorkerTrigger` SQS queue.
    Ensure `${WORKER_TRIGGER_QUEUE_ARN}` (exported in the SQS setup step) is correctly set.

    ```bash
    cat <<EOF > eventbridge-sqs-policy.json
    {
      "Version": "2012-10-17",
      "Statement": [{
        "Effect": "Allow",
        "Action": "sqs:SendMessage",
        "Resource": "${WORKER_TRIGGER_QUEUE_ARN}"
      }]
    }
    EOF
    ```
    *Verify the content of `eventbridge-sqs-policy.json`.*

*   **Create the IAM policy using AWS CLI:**

    ```bash
    aws iam create-policy \
      --policy-name "${EB_POLICY_NAME}" \
      --policy-document file://eventbridge-sqs-policy.json \
      --description "Policy for EventBridge to send messages to orchestrator SQS WorkerTrigger queue"
    ```
    *Take note of the `Arn` from the output. You can also retrieve it later.*

    *Example Output (Success):*
    ```json
    {
        "Policy": {
            "PolicyName": "mo-mo-wt-policy-xxxx",
            "PolicyId": "ANPAEXAMPLEPOLICYID",
            "Arn": "arn:aws:iam::123456789012:policy/mo-mo-wt-policy-xxxx",
            "Path": "/",
            "DefaultVersionId": "v1",
            "AttachmentCount": 0,
            "PermissionsBoundaryUsageCount": 0,
            "IsAttachable": true,
            "CreateDate": "2023-10-27T10:00:00Z",
            "UpdateDate": "2023-10-27T10:00:00Z"
        }
    }
    ```
    ```bash
    # Export the Policy ARN (replace with your actual ARN if not using jq or if name is different)
    export EB_POLICY_ARN=$(aws iam list-policies --scope Local --query "Policies[?PolicyName=='${EB_POLICY_NAME}'].Arn" --output text --region "${AWS_REGION}")
    # Or, if your list-policies output is large, be more specific or use the ARN from create-policy output.
    # Example if you copied it: export EB_POLICY_ARN="arn:aws:iam::ACCOUNT_ID:policy/YOUR_POLICY_NAME"
    echo "EventBridge SQS Policy ARN: ${EB_POLICY_ARN}"
    ```

**3. Create IAM Role for EventBridge:**

*   **Create the role trust policy document JSON file:**
    This policy allows EventBridge (specifically `events.amazonaws.com`) and EventBridge Scheduler (`scheduler.amazonaws.com`) to assume this role.

    ```bash
    cat <<EOF > eventbridge-trust-policy.json
    {
      "Version": "2012-10-17",
      "Statement": [{
        "Effect": "Allow",
        "Principal": {
          "Service": [
            "events.amazonaws.com",
            "scheduler.amazonaws.com"
          ]
        },
        "Action": "sts:AssumeRole"
      }]
    }
    EOF
    ```
    *Verify the content of `eventbridge-trust-policy.json`.*

*   **Create the IAM role using AWS CLI:**

    ```bash
    aws iam create-role \
      --role-name "${EB_ROLE_NAME}" \
      --assume-role-policy-document file://eventbridge-trust-policy.json \
      --description "Role for EventBridge to interact with orchestrator SQS queues" \
      --region "${AWS_REGION}"
    ```
    *Take note of the `Arn` for the role from the output.*
    *Example Output (Success):*
    ```json
    {
        "Role": {
            "Path": "/",
            "RoleName": "mo-mo-wt-role-xxxx",
            "RoleId": "AROAEXAMPLE ROLEID",
            "Arn": "arn:aws:iam::123456789012:role/mo-mo-wt-role-xxxx",
            "CreateDate": "2023-10-27T10:05:00Z",
            "AssumeRolePolicyDocument": { ... }
        }
    }
    ```
    ```bash
    # Export the Role ARN (replace with your actual ARN if not using jq or if name is different)
    export EB_ROLE_ARN=$(aws iam get-role --role-name "${EB_ROLE_NAME}" --query 'Role.Arn' --output text --region "${AWS_REGION}")
    echo "EventBridge Role ARN: ${EB_ROLE_ARN}"
    ```

**4. Attach the Policy to the Role:**

```bash
aws iam attach-role-policy \
  --role-name "${EB_ROLE_NAME}" \
  --policy-arn "${EB_POLICY_ARN}" \
  --region "${AWS_REGION}"
```
*This command does not produce output on success.*

**5. Verification:**

*   **Check if policy is attached to the role:**
    ```bash
    aws iam list-attached-role-policies --role-name "${EB_ROLE_NAME}" --region "${AWS_REGION}"
    ```
    *You should see `${EB_POLICY_NAME}` or its ARN in the output.*

*   **Get Role details:**
    ```bash
    aws iam get-role --role-name "${EB_ROLE_NAME}" --region "${AWS_REGION}"
    ```

*   **Get Policy details:**
    ```bash
    aws iam get-policy --policy-arn "${EB_POLICY_ARN}" --region "${AWS_REGION}"
    ```

**6. Basic Troubleshooting:**

*   **Error:** `MalformedPolicyDocument`:
    *   **Cause:** Syntax error in your `eventbridge-sqs-policy.json` or `eventbridge-trust-policy.json`.
    *   **Solution:** Carefully validate the JSON structure. Ensure variables like `${WORKER_TRIGGER_QUEUE_ARN}` were correctly expanded if you manually created the file.
*   **Error:** `NoSuchEntity` when attaching policy or getting role/policy.
    *   **Cause:** The role or policy name/ARN is incorrect, or it wasn't created successfully.
    *   **Solution:** Verify the names/ARNs and check the creation step outputs. Ensure the `MANUAL_SUFFIX` or chosen names are consistent.
*   **Permissions Error:** `AccessDenied` for `iam:CreatePolicy`, `iam:CreateRole`, `iam:AttachRolePolicy`.
    *   **Cause:** IAM user/role lacks necessary permissions.
    *   **Solution:** Update IAM permissions.
*   **Delay for propagation:** IAM changes can sometimes take a few moments to propagate throughout AWS. If a newly created role/policy isn't immediately recognized in a subsequent step (like EventBridge setup), a short wait might be necessary. The orchestrator code includes a 15-second sleep for this.

---
Next, you will set up the EventBridge rules or schedules.

## 6. Step 4: EventBridge (Scheduler/Rules) Setup

This section guides you through creating EventBridge rules or schedules to periodically trigger the SQS `WorkerTrigger` queue for different tasks. The choice between "Rule" and "Schedule" depends on the `${MADARA_ORCHESTRATOR_EVENT_BRIDGE_TYPE}` environment variable you set.

**Important Notes:**
*   Ensure `${WORKER_TRIGGER_QUEUE_ARN}` (from SQS setup) and `${EB_ROLE_ARN}` (from IAM setup) are correctly set in your environment.
*   The `ProofRegistration` trigger is typically used for L3 setups. If you are setting up for L2, you might skip it. The orchestrator code handles this condition; for manual setup, you decide.
*   A short delay (e.g., 15-30 seconds) after creating IAM roles/policies is advisable before creating EventBridge resources that use them, to allow for IAM propagation. The orchestrator code includes a 15s sleep.

```bash
# Convert interval seconds to a rate expression (e.g., "rate(1 minute)")
# This is a simplified converter. AWS CLI's 'put-rule' and 'create-schedule'
# directly accept "rate(X units)" or "cron(...)" expressions.
INTERVAL_SECONDS=${MADARA_ORCHESTRATOR_EVENT_BRIDGE_INTERVAL_SECONDS}
if (( INTERVAL_SECONDS < 1 )); then
  echo "EventBridge interval must be at least 1 second."
  # Handle error or set a default
  INTERVAL_SECONDS=60 # Default to 60 seconds if invalid
fi

if (( INTERVAL_SECONDS == 1 )); then
  SCHEDULE_EXPRESSION="rate(1 second)"
elif (( INTERVAL_SECONDS < 60 && INTERVAL_SECONDS != 1 )); then
  SCHEDULE_EXPRESSION="rate(${INTERVAL_SECONDS} seconds)"
elif (( INTERVAL_SECONDS == 60 )); then
  SCHEDULE_EXPRESSION="rate(1 minute)"
elif (( INTERVAL_SECONDS < 3600 && (INTERVAL_SECONDS % 60) == 0 )); then
  MINUTES=$((INTERVAL_SECONDS / 60))
  SCHEDULE_EXPRESSION="rate(${MINUTES} minute$( ((MINUTES > 1)) && echo s ))"
elif (( INTERVAL_SECONDS == 3600 )); then
  SCHEDULE_EXPRESSION="rate(1 hour)"
elif (( INTERVAL_SECONDS < 86400 && (INTERVAL_SECONDS % 3600) == 0 )); then
  HOURS=$((INTERVAL_SECONDS / 3600))
  SCHEDULE_EXPRESSION="rate(${HOURS} hour$( ((HOURS > 1)) && echo s ))"
elif (( INTERVAL_SECONDS == 86400 )); then
  SCHEDULE_EXPRESSION="rate(1 day)"
elif (( (INTERVAL_SECONDS % 86400) == 0 )); then
  DAYS=$((INTERVAL_SECONDS / 86400))
  SCHEDULE_EXPRESSION="rate(${DAYS} day$( ((DAYS > 1)) && echo s ))"
else
  echo "Warning: EventBridge interval ${INTERVAL_SECONDS}s is not a clean multiple of minutes, hours, or days. AWS might not support all arbitrary second values for rates. Using raw seconds rate."
  SCHEDULE_EXPRESSION="rate(${INTERVAL_SECONDS} seconds)" # Fallback, check AWS docs for limitations
fi
echo "Using Schedule Expression: ${SCHEDULE_EXPRESSION}"

# Worker Triggers (from orchestrator codebase)
# Note: ProofRegistration is typically for L3.
WORKER_TRIGGERS=(
  "Snos"
  "Proving"
  "ProofRegistration"
  "DataSubmission"
  "UpdateState"
  "Batching"
)

# Loop through each worker trigger to create its rule/schedule
for TRIGGER_TYPE in "${WORKER_TRIGGERS[@]}"; do
  # Construct the rule/schedule name
  RULE_OR_SCHEDULE_NAME="${EB_RULE_NAME_BASE}-${TRIGGER_TYPE}"
  echo "--- Setting up EventBridge for Trigger: ${TRIGGER_TYPE} ---"
  echo "Rule/Schedule Name: ${RULE_OR_SCHEDULE_NAME}"

  # Input for the SQS message (the trigger type string)
  SQS_MESSAGE_INPUT="\"${TRIGGER_TYPE}\"" # Needs to be a JSON string

  if [ "${MADARA_ORCHESTRATOR_EVENT_BRIDGE_TYPE}" == "Rule" ]; then
    # --- Create EventBridge Rule ---
    echo "Creating EventBridge Rule..."
    aws events put-rule \
      --name "${RULE_OR_SCHEDULE_NAME}" \
      --schedule-expression "${SCHEDULE_EXPRESSION}" \
      --state ENABLED \
      --description "Orchestrator trigger for ${TRIGGER_TYPE}" \
      --region "${AWS_REGION}"

    # Prepare target configuration (InputTransformer for rules)
    TARGET_ID="1" # Arbitrary ID for the target
    # Ensure SQS_MESSAGE_INPUT is properly escaped for the InputTemplate
    INPUT_TRANSFORMER_JSON=$(printf '{"InputPathsMap":{"time":"$.time"},"InputTemplate":%s}' "${SQS_MESSAGE_INPUT}")


    echo "Adding target to EventBridge Rule..."
    aws events put-targets \
      --rule "${RULE_OR_SCHEDULE_NAME}" \
      --targets "Id=${TARGET_ID},Arn=${WORKER_TRIGGER_QUEUE_ARN},InputTransformer=${INPUT_TRANSFORMER_JSON}" \
      --region "${AWS_REGION}"

    echo "EventBridge Rule ${RULE_OR_SCHEDULE_NAME} created and target added."

  elif [ "${MADARA_ORCHESTRATOR_EVENT_BRIDGE_TYPE}" == "Schedule" ]; then
    # --- Create EventBridge Schedule ---
    echo "Creating EventBridge Schedule..."
    # Scheduler needs a 'group-name', using default if not specified
    # FlexibleTimeWindow is set to OFF as in orchestrator code
    # Ensure SQS_MESSAGE_INPUT is properly escaped for the target Input
    TARGET_INPUT_FOR_SCHEDULER="${SQS_MESSAGE_INPUT}"

    aws scheduler create-schedule \
      --name "${RULE_OR_SCHEDULE_NAME}" \
      --group-name "default" \
      --schedule-expression "${SCHEDULE_EXPRESSION}" \
      --schedule-expression-timezone "UTC" \
      --flexible-time-window '{ "Mode": "OFF" }' \
      --target "{ \"Arn\": \"${WORKER_TRIGGER_QUEUE_ARN}\", \"RoleArn\": \"${EB_ROLE_ARN}\", \"Input\": ${TARGET_INPUT_FOR_SCHEDULER} }" \
      --state ENABLED \
      --region "${AWS_REGION}"

    echo "EventBridge Schedule ${RULE_OR_SCHEDULE_NAME} created."
  else
    echo "Unsupported MADARA_ORCHESTRATOR_EVENT_BRIDGE_TYPE: ${MADARA_ORCHESTRATOR_EVENT_BRIDGE_TYPE}. Choose 'Rule' or 'Schedule'."
    # Optionally, exit here or skip
  fi
  echo "-------------------------------------"
done
```

**Verification:**

*   **If using EventBridge Rules:**
    For each trigger type (e.g., `Snos`):
    ```bash
    RULE_NAME_TO_VERIFY="${EB_RULE_NAME_BASE}-Snos" # Example
    aws events describe-rule --name "${RULE_NAME_TO_VERIFY}" --region "${AWS_REGION}"
    aws events list-targets-by-rule --rule "${RULE_NAME_TO_VERIFY}" --region "${AWS_REGION}"
    ```
*   **If using EventBridge Scheduler:**
    For each trigger type (e.g., `Snos`):
    ```bash
    SCHEDULE_NAME_TO_VERIFY="${EB_RULE_NAME_BASE}-Snos" # Example
    aws scheduler get-schedule --name "${SCHEDULE_NAME_TO_VERIFY}" --group-name "default" --region "${AWS_REGION}"
    ```

**Basic Troubleshooting:**

*   **Error:** `ValidationException` when creating rule/schedule.
    *   **Cause:** Invalid schedule expression, malformed target JSON, or incorrect ARNs.
    *   **Solution:** Double-check the `${SCHEDULE_EXPRESSION}` format (e.g., `rate(5 minutes)`, `cron(0 12 * * ? *)`). Verify `${WORKER_TRIGGER_QUEUE_ARN}` and `${EB_ROLE_ARN}`. Ensure JSON for targets or input transformers is correct. For `InputTransformer`, `InputTemplate` must be a valid JSON string.
*   **Error:** `RoleArn is required for SQS targets` (for EventBridge Rules, if not using `InputTransformer` and relying on resource-based policy on SQS, which we are not doing here as we created an IAM role).
    *   **Cause:** This setup uses an IAM role for EventBridge Scheduler. For EventBridge Rules, the permission to send to SQS is usually via the rule's own execution role (if created) or relies on SQS resource-based policies. Our IAM role `${EB_ROLE_ARN}` is primarily for the *Scheduler*. EventBridge Rules, when targeting SQS directly without a specified role, often rely on resource-based policies on the SQS queue. The current orchestrator code uses `InputTransformer` for Rules and an explicit Role for Scheduler.
    *   **Note for Rules:** The `put-targets` command for rules *does not* use the `${EB_ROLE_ARN}` directly in the `aws events put-targets` call in this script. The permissions for rules to send to SQS are often implicitly handled by EventBridge if the SQS queue has a resource policy allowing `events.amazonaws.com` or if the target configuration is simple. However, if complex transformations or specific roles are needed for rules, the `RoleArn` can be added to the target structure. The guide currently reflects the simpler path for rules with `InputTransformer`.
*   **Error:** `The role provided does not have sufficient permissions` (especially for Scheduler).
    *   **Cause:** The IAM role (`${EB_ROLE_ARN}`) does not have the `sqs:SendMessage` permission for the target SQS queue, or the trust policy is incorrect.
    *   **Solution:** Verify the IAM policy attached to the role and the role's trust policy (Step 3).
*   **Permissions Error:** `AccessDenied` for `events:PutRule`, `events:PutTargets`, `scheduler:CreateSchedule`.
    *   **Cause:** IAM user/role lacks these permissions.
    *   **Solution:** Update IAM permissions.

---
Next, you will set up the SNS Topic.

## 7. Step 5: SNS Topic Setup

This section guides you through creating the Simple Notification Service (SNS) topic used by the orchestrator, typically for alerts.

**1. Topic Name:**
The SNS topic name is derived from the environment variables you set in the Prerequisites section: `MADARA_ORCHESTRATOR_AWS_PREFIX` and `MADARA_ORCHESTRATOR_AWS_SNS_TOPIC_IDENTIFIER`.
The combined name is stored in the `${SNS_TOPIC_NAME}` variable.

**2. Create the SNS Topic:**

```bash
echo "Creating SNS Topic: ${SNS_TOPIC_NAME}"
SNS_TOPIC_ARN_OUTPUT=$(aws sns create-topic --name "${SNS_TOPIC_NAME}" --region "${AWS_REGION}")
```

*Example Output (Success):*
```json
{
    "TopicArn": "arn:aws:sns:us-east-1:123456789012:mo_my-orchestrator-alerts"
}
```

*   **Export the Topic ARN (Optional, for reference or if needed by other configurations not covered here):**
    You can capture the ARN from the output.
    ```bash
    # Check if SNS_TOPIC_ARN_OUTPUT contains an error before parsing
    if echo "${SNS_TOPIC_ARN_OUTPUT}" | grep -q "TopicArn"; then
      export SNS_TOPIC_ARN=$(echo "${SNS_TOPIC_ARN_OUTPUT}" | jq -r .TopicArn)
      echo "SNS Topic ARN: ${SNS_TOPIC_ARN}"
    else
      # It might be that the topic already exists (create-topic is idempotent), try to get its ARN
      echo "Topic might already exist or there was an issue with creation command. Attempting to fetch ARN for: ${SNS_TOPIC_NAME}"
      # Construct the expected ARN pattern for the current account and region
      ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
      EXPECTED_ARN_PATTERN="arn:aws:sns:${AWS_REGION}:${ACCOUNT_ID}:${SNS_TOPIC_NAME}"

      EXISTING_SNS_TOPIC_ARN=$(aws sns list-topics --region "${AWS_REGION}" --query "Topics[?TopicArn=='${EXPECTED_ARN_PATTERN}'].TopicArn" --output text)

      if [ -n "${EXISTING_SNS_TOPIC_ARN}" ]; then
        export SNS_TOPIC_ARN="${EXISTING_SNS_TOPIC_ARN}"
        echo "Existing SNS Topic ARN: ${SNS_TOPIC_ARN}"
      else
        echo "Could not determine SNS Topic ARN. Check AWS console or previous logs. Last command output: ${SNS_TOPIC_ARN_OUTPUT}"
      fi
    fi
    ```
    *(Note: The `create-topic` command is idempotent. If the topic with the same name already exists in the same region and account, it will return the existing TopicArn. The script above tries to handle this.)*


**3. Verify Topic Creation:**

You can verify that the topic was created successfully by listing its attributes:
```bash
# Ensure SNS_TOPIC_ARN is set from the previous step's output
if [ -z "${SNS_TOPIC_ARN}" ]; then
  echo "Error: SNS_TOPIC_ARN is not set. Cannot verify topic. Please check the output of the creation step."
else
  aws sns get-topic-attributes --topic-arn "${SNS_TOPIC_ARN}" --region "${AWS_REGION}"
fi
```
*If successful, this command will return a JSON object with the topic's attributes.*

*Alternative Verification (List Topics):*
```bash
aws sns list-topics --region "${AWS_REGION}" | grep "${SNS_TOPIC_NAME}"
```

**4. Basic Troubleshooting:**

*   **Error:** `InvalidParameter: Invalid parameter: Topic Name` or `TopicName fails to satisfy constraint: Topic names must be made up of only uppercase and lowercase ASCII letters, numbers, underscores, and hyphens, and must be between 1 and 256 characters long.`
    *   **Cause:** The `${SNS_TOPIC_NAME}` contains invalid characters or does not meet length requirements. The orchestrator code specifically validates this.
    *   **Solution:** Ensure your `MADARA_ORCHESTRATOR_AWS_PREFIX` and `MADARA_ORCHESTRATOR_AWS_SNS_TOPIC_IDENTIFIER` result in a valid name (letters, numbers, hyphens, underscores).
*   **Error:** `AuthorizationError: User ... is not authorized to perform: sns:CreateTopic`
    *   **Cause:** The IAM user/role whose credentials you are using does not have `sns:CreateTopic` permissions.
    *   **Solution:** Update the IAM user/role permissions.
*   **Topic Already Exists:** If the topic already exists with the same name, the `create-topic` command will succeed and return the ARN of the existing topic. No error will be thrown.

---
All core AWS resources for the orchestrator should now be set up. The next section provides a brief verification summary.

## 8. Verification Summary

After completing all the steps, you can use these commands to quickly check the status or existence of the key resources. Ensure your environment variables (like `${S3_BUCKET_NAME}`, `${WORKER_TRIGGER_QUEUE_URL}`, etc.) are still set from the previous steps.

*   **S3 Bucket:**
    ```bash
    aws s3api head-bucket --bucket "${S3_BUCKET_NAME}" --region "${AWS_REGION}" && echo "S3 Bucket ${S3_BUCKET_NAME} exists." || echo "S3 Bucket ${S3_BUCKET_NAME} not found or access denied."
    ```

*   **SQS Queues (example for WorkerTrigger and JobHandleFailure):**
    ```bash
    # Helper function (if not already in session from SQS setup)
    get_queue_name() {
      local queue_type=$1
      echo "${MADARA_ORCHESTRATOR_AWS_SQS_QUEUE_IDENTIFIER_TEMPLATE//\{\}/${queue_type}}"
    }

    # WorkerTrigger Queue
    aws sqs get-queue-attributes --queue-url "${WORKER_TRIGGER_QUEUE_URL}" --attribute-names QueueArn --region "${AWS_REGION}" && echo "WorkerTrigger Queue exists." || echo "WorkerTrigger Queue not found."

    # JobHandleFailure Queue
    JOB_HANDLE_FAILURE_QUEUE_NAME_FOR_VERIFY=$(get_queue_name "JobHandleFailure")
    JOB_HANDLE_FAILURE_QUEUE_URL_FOR_VERIFY=$(aws sqs get-queue-url --queue-name "${JOB_HANDLE_FAILURE_QUEUE_NAME_FOR_VERIFY}" --query 'QueueUrl' --output text --region "${AWS_REGION}")
    aws sqs get-queue-attributes --queue-url "${JOB_HANDLE_FAILURE_QUEUE_URL_FOR_VERIFY}" --attribute-names QueueArn --region "${AWS_REGION}" && echo "JobHandleFailure Queue exists." || echo "JobHandleFailure Queue not found."
    ```
    *(Verify other SQS queues as needed using their derived names)*

*   **IAM Role for EventBridge:**
    ```bash
    aws iam get-role --role-name "${EB_ROLE_NAME}" --region "${AWS_REGION}" && echo "IAM Role ${EB_ROLE_NAME} exists." || echo "IAM Role ${EB_ROLE_NAME} not found."
    ```

*   **IAM Policy for EventBridge:**
    ```bash
    # Ensure EB_POLICY_ARN is set (it was exported during IAM setup)
    if [ -z "${EB_POLICY_ARN}" ]; then echo "Warning: EB_POLICY_ARN is not set."; fi
    aws iam get-policy --policy-arn "${EB_POLICY_ARN}" --region "${AWS_REGION}" && echo "IAM Policy ${EB_POLICY_ARN} exists." || echo "IAM Policy ${EB_POLICY_ARN} not found."
    # Check attachment
    aws iam list-attached-role-policies --role-name "${EB_ROLE_NAME}" --region "${AWS_REGION}" | grep "${EB_POLICY_ARN}" && echo "Policy attached to role." || echo "Policy NOT attached or names mismatch."
    ```

*   **EventBridge Rule/Schedule (example for Snos trigger):**
    ```bash
    RULE_OR_SCHEDULE_NAME_TO_VERIFY="${EB_RULE_NAME_BASE}-Snos"
    if [ "${MADARA_ORCHESTRATOR_EVENT_BRIDGE_TYPE}" == "Rule" ]; then
      aws events describe-rule --name "${RULE_OR_SCHEDULE_NAME_TO_VERIFY}" --region "${AWS_REGION}" && echo "EventBridge Rule ${RULE_OR_SCHEDULE_NAME_TO_VERIFY} exists." || echo "EventBridge Rule not found."
    elif [ "${MADARA_ORCHESTRATOR_EVENT_BRIDGE_TYPE}" == "Schedule" ]; then
      aws scheduler get-schedule --name "${RULE_OR_SCHEDULE_NAME_TO_VERIFY}" --group-name "default" --region "${AWS_REGION}" && echo "EventBridge Schedule ${RULE_OR_SCHEDULE_NAME_TO_VERIFY} exists." || echo "EventBridge Schedule not found."
    fi
    ```

*   **SNS Topic:**
    ```bash
    # Ensure SNS_TOPIC_ARN is set (it was exported during SNS setup)
    if [ -z "${SNS_TOPIC_ARN}" ]; then echo "Warning: SNS_TOPIC_ARN is not set."; fi
    aws sns get-topic-attributes --topic-arn "${SNS_TOPIC_ARN}" --region "${AWS_REGION}" && echo "SNS Topic ${SNS_TOPIC_ARN} exists." || echo "SNS Topic ${SNS_TOPIC_ARN} not found."
    ```

## 9. Cleanup (Optional)

If you need to remove the resources created by following this guide, you can do so using the AWS CLI. It's generally best to delete resources in the reverse order of creation, especially if there are dependencies (though for this set, most can be deleted independently after EventBridge rules/schedules are handled).

**Important:** Double-check resource names and ensure you are deleting the correct resources, especially in an account with other infrastructure. The environment variables set during the setup (`${EB_RULE_NAME_BASE}`, `${EB_ROLE_NAME}`, `${EB_POLICY_ARN}`, `${WORKER_TRIGGER_QUEUE_URL}`, `${JOB_HANDLE_FAILURE_QUEUE_URL}`, `${SNS_TOPIC_ARN}`, `${S3_BUCKET_NAME}`) should ideally still be available in your session. If not, you will need to retrieve or reconstruct these names/ARNs.

1.  **Delete EventBridge Rules/Schedules:**
    (Loop through `${WORKER_TRIGGERS}` as in the setup script. Ensure `WORKER_TRIGGERS` array and `EB_RULE_NAME_BASE` are set.)
    ```bash
    # WORKER_TRIGGERS array should be defined as in EventBridge setup:
    # WORKER_TRIGGERS=("Snos" "Proving" "ProofRegistration" "DataSubmission" "UpdateState" "Batching")

    echo "--- Deleting EventBridge Resources ---"
    for TRIGGER_TYPE_TO_DELETE in "${WORKER_TRIGGERS[@]}"; do
      RULE_OR_SCHEDULE_NAME_TO_DELETE="${EB_RULE_NAME_BASE}-${TRIGGER_TYPE_TO_DELETE}"
      echo "Attempting to delete EventBridge resource: ${RULE_OR_SCHEDULE_NAME_TO_DELETE}"
      if [ "${MADARA_ORCHESTRATOR_EVENT_BRIDGE_TYPE}" == "Rule" ]; then
        # Remove targets first for rules
        TARGET_IDS_JSON=$(aws events list-targets-by-rule --rule "${RULE_OR_SCHEDULE_NAME_TO_DELETE}" --query "Targets[].Id" --output json --region "${AWS_REGION}" 2>/dev/null)
        if [ -n "${TARGET_IDS_JSON}" ] && [ "${TARGET_IDS_JSON}" != "null" ] && [ "${TARGET_IDS_JSON}" != "[]" ]; then
          echo "Removing targets from rule ${RULE_OR_SCHEDULE_NAME_TO_DELETE}..."
          # The IDs need to be passed as a list of strings
          IDS_TO_REMOVE=$(echo ${TARGET_IDS_JSON} | jq -r '. | join(" ")')
          if [ -n "${IDS_TO_REMOVE}" ]; then
             aws events remove-targets --rule "${RULE_OR_SCHEDULE_NAME_TO_DELETE}" --ids ${IDS_TO_REMOVE} --region "${AWS_REGION}"
          fi
        fi
        aws events delete-rule --name "${RULE_OR_SCHEDULE_NAME_TO_DELETE}" --region "${AWS_REGION}" && echo "Deleted rule ${RULE_OR_SCHEDULE_NAME_TO_DELETE}" || echo "Rule ${RULE_OR_SCHEDULE_NAME_TO_DELETE} not found or error."
      elif [ "${MADARA_ORCHESTRATOR_EVENT_BRIDGE_TYPE}" == "Schedule" ]; then
        aws scheduler delete-schedule --name "${RULE_OR_SCHEDULE_NAME_TO_DELETE}" --group-name "default" --region "${AWS_REGION}" && echo "Deleted schedule ${RULE_OR_SCHEDULE_NAME_TO_DELETE}" || echo "Schedule ${RULE_OR_SCHEDULE_NAME_TO_DELETE} not found or error."
      fi
    done
    ```

2.  **Detach and Delete IAM Policy for EventBridge:**
    ```bash
    echo "--- Deleting IAM Resources ---"
    if [ -n "${EB_ROLE_NAME}" ] && [ -n "${EB_POLICY_ARN}" ]; then
      echo "Detaching policy ${EB_POLICY_ARN} from role ${EB_ROLE_NAME}"
      aws iam detach-role-policy --role-name "${EB_ROLE_NAME}" --policy-arn "${EB_POLICY_ARN}" --region "${AWS_REGION}" 2>/dev/null
      echo "Deleting policy ${EB_POLICY_ARN}"
      aws iam delete-policy --policy-arn "${EB_POLICY_ARN}" --region "${AWS_REGION}" && echo "Policy ${EB_POLICY_ARN} deleted." || echo "Policy not found or error."
    else
      echo "EB_ROLE_NAME or EB_POLICY_ARN not set. Skipping IAM policy detachment/deletion."
    fi
    ```

3.  **Delete IAM Role for EventBridge:**
    ```bash
    if [ -n "${EB_ROLE_NAME}" ]; then
      echo "Deleting role ${EB_ROLE_NAME}"
      aws iam delete-role --role-name "${EB_ROLE_NAME}" --region "${AWS_REGION}" && echo "Role ${EB_ROLE_NAME} deleted." || echo "Role not found or error."
    else
      echo "EB_ROLE_NAME not set. Skipping IAM role deletion."
    fi
    ```

4.  **Delete SQS Queues:**
    (Loop through all created queue URLs or names. URLs are safer.)
    ```bash
    echo "--- Deleting SQS Queues ---"
    # Helper function (if not already in session)
    get_queue_name() {
      local queue_type=$1
      echo "${MADARA_ORCHESTRATOR_AWS_SQS_QUEUE_IDENTIFIER_TEMPLATE//\{\}/${queue_type}}"
    }

    # WorkerTrigger Queue
    if [ -n "${WORKER_TRIGGER_QUEUE_URL}" ]; then
      echo "Deleting SQS Queue: ${WORKER_TRIGGER_QUEUE_URL}"
      aws sqs delete-queue --queue-url "${WORKER_TRIGGER_QUEUE_URL}" --region "${AWS_REGION}"
    else
      echo "WORKER_TRIGGER_QUEUE_URL not set. Skipping."
    fi

    # JobHandleFailure Queue
    if [ -n "${JOB_HANDLE_FAILURE_QUEUE_URL}" ]; then # This was exported during SQS setup
      echo "Deleting SQS Queue: ${JOB_HANDLE_FAILURE_QUEUE_URL}"
      aws sqs delete-queue --queue-url "${JOB_HANDLE_FAILURE_QUEUE_URL}" --region "${AWS_REGION}"
    else
      # Fallback if URL not set, try to get it by name
      JHF_QUEUE_NAME_CLEANUP=$(get_queue_name "JobHandleFailure")
      JHF_URL_CLEANUP=$(aws sqs get-queue-url --queue-name "${JHF_QUEUE_NAME_CLEANUP}" --query 'QueueUrl' --output text --region "${AWS_REGION}" 2>/dev/null)
      if [ -n "${JHF_URL_CLEANUP}" ]; then
        aws sqs delete-queue --queue-url "${JHF_URL_CLEANUP}" --region "${AWS_REGION}"
      else
        echo "JobHandleFailure queue URL not found. Skipping."
      fi
    fi

    # Other Queues (defined in SQS setup)
    # QUEUE_TYPES array should be defined as in SQS setup
    # QUEUE_TYPES=("SnosJobProcessing" "SnosJobVerification" ...)
    if [ ${#QUEUE_TYPES[@]} -gt 0 ]; then
      for QUEUE_TYPE_TO_DELETE in "${QUEUE_TYPES[@]}"; do
        SQS_QUEUE_NAME_TO_DELETE=$(get_queue_name "${QUEUE_TYPE_TO_DELETE}")
        SQS_QUEUE_URL_TO_DELETE=$(aws sqs get-queue-url --queue-name "${SQS_QUEUE_NAME_TO_DELETE}" --query 'QueueUrl' --output text --region "${AWS_REGION}" 2>/dev/null)
        if [ -n "${SQS_QUEUE_URL_TO_DELETE}" ]; then
          echo "Deleting SQS Queue: ${SQS_QUEUE_URL_TO_DELETE}"
          aws sqs delete-queue --queue-url "${SQS_QUEUE_URL_TO_DELETE}" --region "${AWS_REGION}"
        else
          echo "Queue ${SQS_QUEUE_NAME_TO_DELETE} not found. Skipping."
        fi
      done
    else
      echo "QUEUE_TYPES array not defined. Skipping deletion of other queues."
    fi
    ```

5.  **Delete SNS Topic:**
    ```bash
    echo "--- Deleting SNS Topic ---"
    if [ -n "${SNS_TOPIC_ARN}" ]; then
      echo "Deleting SNS Topic: ${SNS_TOPIC_ARN}"
      aws sns delete-topic --topic-arn "${SNS_TOPIC_ARN}" --region "${AWS_REGION}" && echo "SNS Topic ${SNS_TOPIC_ARN} deleted." || echo "SNS Topic not found or error."
    else
      echo "SNS_TOPIC_ARN not set. Skipping SNS topic deletion."
    fi
    ```

6.  **Delete S3 Bucket:**
    *   Buckets must be empty before deletion. The `aws s3 rb --force` command attempts to empty and then remove the bucket.
    ```bash
    echo "--- Deleting S3 Bucket ---"
    if [ -n "${S3_BUCKET_NAME}" ]; then
      echo "Attempting to remove all objects from bucket ${S3_BUCKET_NAME} and delete bucket..."
      aws s3 rb "s3://${S3_BUCKET_NAME}" --force --region "${AWS_REGION}"
      # Verify deletion, as 'rb --force' might fail silently on permissions or if objects are versioned/locked
      aws s3api head-bucket --bucket "${S3_BUCKET_NAME}" --region "${AWS_REGION}" 2>/dev/null
      if [ $? -eq 0 ]; then
          echo "Bucket ${S3_BUCKET_NAME} still exists. Manual intervention may be required (e.g., versioned objects, lifecycle policies)."
      else
          echo "S3 Bucket ${S3_BUCKET_NAME} deleted or does not exist anymore."
      fi
    else
      echo "S3_BUCKET_NAME not set. Skipping S3 bucket deletion."
    fi
    ```

## 10. Conclusion

You have now manually provisioned the core AWS infrastructure required for the Madara Orchestrator using the AWS CLI. This includes an S3 bucket for storage, several SQS queues for job management (with DLQ configurations), an IAM role and policy for EventBridge, EventBridge rules/schedules for automated triggers, and an SNS topic for notifications.

**Next Steps:**
*   Ensure your orchestrator application is configured with the names/ARNs of these created resources (usually via the same environment variables you used in this guide, which the application would also consume).
*   Deploy and run the Madara Orchestrator application according to its specific deployment instructions.

Refer to the main Madara Orchestrator documentation for application-specific configuration and operational details.
It's recommended to verify that all environment variables used by the orchestrator application correctly point to the resources you have just created.

---
