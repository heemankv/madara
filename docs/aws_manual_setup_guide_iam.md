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
