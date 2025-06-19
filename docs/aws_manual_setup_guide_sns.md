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
