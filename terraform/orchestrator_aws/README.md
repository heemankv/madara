# Terraform Configuration for Madara Orchestrator AWS Resources

This directory contains Terraform configuration files to provision the necessary AWS infrastructure for the Madara Orchestrator.

## Structure

- `versions.tf`: Specifies Terraform version and required provider versions.
- `variables.tf`: Defines input variables for customization (e.g., prefixes, identifiers, region).
- `provider.tf`: Configures the AWS provider.
- `s3.tf`: Manages the S3 bucket creation.
- `sqs.tf`: Manages the SQS queues and their DLQs.
- `iam.tf`: Manages the IAM role and policy required for EventBridge to send messages to SQS.
- `eventbridge.tf`: Manages the EventBridge rules or schedules for triggering worker queues.
- `sns.tf`: Manages the SNS topic for alerts.
- `outputs.tf`: Defines outputs from the deployed infrastructure (e.g., ARNs of created resources).

## Usage

1.  **Initialize Terraform:**
    ```bash
    terraform init
    ```
2.  **Review Plan:**
    (Ensure you have configured your AWS credentials and set any required variables, typically in a `.tfvars` file or via environment variables)
    ```bash
    terraform plan -var-file="your-variables.tfvars"
    ```
3.  **Apply Configuration:**
    ```bash
    terraform apply -var-file="your-variables.tfvars"
    ```

Refer to the main Madara Orchestrator documentation for details on which variable values to use, based on the [Orchestrator AWS Setup Documentation](../docs/aws_setup_documentation.md).
