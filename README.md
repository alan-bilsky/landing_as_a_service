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

Before running Terragrunt you must set the bucket and region for storing
Terraform state. For example:

```bash
export TG_STATE_BUCKET=laas-dev-tfstate
export TG_REGION=us-west-2
```

Run `terragrunt run-all apply` from the desired environment directory to deploy.

## Web Frontend

A simple static web page for interacting with the service lives in `web/`.
It handles Cognito authentication, collects the desired modifications and
calls the API Gateway endpoint. The response should contain the path or URL
of the generated landing page, which is then opened in the browser.

### Setup
1. Deploy the infrastructure (`terragrunt run-all apply`) in the desired environment.
2. Retrieve the required values using `terragrunt output`:
   - `api_endpoint`
   - `user_pool_id`
   - `user_pool_client_id`
   - `distribution_domain_name`
3. Copy `web/config.example.js` to `web/config.js` and fill in the above values.

The web folder is static, so no build step is required. To make it
accessible you can upload it to the input S3 bucket created by the
infrastructure:

```bash
aws s3 sync web/ s3://<input-bucket-name>
```

Once uploaded, open `index.html` in a browser and sign in with your Cognito
credentials to generate a page.
