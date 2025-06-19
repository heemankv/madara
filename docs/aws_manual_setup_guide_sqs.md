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
