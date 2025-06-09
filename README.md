# Landing as a Service Infrastructure

This repository contains a Terragrunt-based infrastructure setup for a serverless application that generates landing pages using AWS Bedrock. The infrastructure is organized under the `infrastructure/` directory with reusable Terraform modules and environment-specific configurations for `dev` and `prod` in `us-west-2`.

## Structure

```
infrastructure/
  modules/        # Reusable Terraform modules
  live/
    dev/          # Development environment
    prod/         # Production environment
```

Each environment deploys:
- S3 buckets for input HTML and generated output
- IAM roles for the Lambda function
- A Lambda function that calls Bedrock
- API Gateway for invoking the Lambda
- Cognito user pool for authentication
- CloudFront distribution to serve generated pages

Run `terragrunt run-all apply` from the desired environment directory to deploy.

## Prerequisites

- AWS credentials configured (via the AWS CLI or environment variables).
- Terraform **1.3+** and Terragrunt **0.47+** installed.
- Access to the Amazon Bedrock service in your AWS account.

## Deploying environments

1. Change into the environment directory (`infrastructure/live/dev` or `infrastructure/live/prod`).
2. Run `terragrunt run-all init` followed by `terragrunt run-all apply`.

Terragrunt will provision all buckets, roles, the Lambda function, API Gateway, Cognito user pool and CloudFront distribution for that environment.

## Running the front-end and triggering the Lambda

Upload an HTML file to the `s3_input` bucket created during deployment. Then invoke the API Gateway endpoint to start the generation process. You can trigger the Lambda manually with `curl`:

```bash
curl -X POST -d @example.html $(terragrunt output -raw api_endpoint)
```

A minimal front-end could simply POST the HTML content to this API URL.

## Where to find the generated output

The Lambda writes the generated page to the `s3_output` bucket. It is also served via the CloudFront distribution. Obtain the distribution domain name with:

```bash
terragrunt output -raw distribution_domain_name
```

Navigate to that domain or open the object from the output S3 bucket to view the resulting landing page.
