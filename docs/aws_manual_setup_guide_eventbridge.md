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
