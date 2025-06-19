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
