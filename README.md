# Landing as a Service Infrastructure

This repository contains a Terragrunt-based infrastructure setup for a serverless application that generates landing pages using AWS Bedrock. The infrastructure is organized under the `infrastructure/` directory with reusable Terraform modules and environment-specific configurations for `dev` and `prod` in `us-west-2`.

## Structure

```
infrastructure/
  terraform_modules/        # Reusable Terraform modules
  terraform/environment/
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

## Prerequisites

- AWS credentials configured (via the AWS CLI or environment variables).
- Terraform **1.3+** and Terragrunt **0.47+** installed.
- Access to the Amazon Bedrock service in your AWS account.

## Deploying environments

1. Change into the environment directory (`infrastructure/terraform/environment/dev` or `infrastructure/terraform/environment/prod`).
2. Run `terragrunt run-all init` followed by `terragrunt run-all apply`.

Terragrunt will provision all buckets, roles, the Lambda function, API Gateway, Cognito user pool and CloudFront distribution for that environment.

## Running the front-end and triggering the Lambda

Upload an HTML file to the `s3_input` bucket created during deployment. Then invoke the API Gateway endpoint to start the generation process. You can trigger the Lambda manually with `curl`:

```bash
curl -X POST -d @example.html $(terragrunt output -raw api_endpoint)
```

A minimal front-end could simply POST the HTML content to this API URL.

Create a `web/config.js` file by copying `web/config.example.js` and fill in
your values. The file should export a global `config` object with the following
fields:
`apiEndpoint`, `cloudfrontUrl`, `userPoolId` and `userPoolClientId`.

## Where to find the generated output

The Lambda writes the generated page to the `s3_output` bucket. It is also served via the CloudFront distribution. Obtain the distribution domain name with:

```bash
terragrunt output -raw distribution_domain_name
```

Navigate to that domain or open the object from the output S3 bucket to view the resulting landing page.

## Serving the sample web page

Follow these steps to try the simple front‑end included under `web/`:

1. Copy the example configuration and fill in the required values:

   ```bash
   cp web/config.example.js web/config.js
   ```

   Edit `web/config.js` and provide your `apiEndpoint`, `cloudfrontUrl`,
   `userPoolId` and `userPoolClientId` (these can be obtained with
   `terragrunt output`).

2. Serve `web/index.html` locally or upload the files to an S3 bucket
   and front it with CloudFront. For quick local testing you can run:

   ```bash
   npx http-server web
   # or
   python3 -m http.server --directory web 8080
   ```

   Then open the printed URL in your browser.

Submitting the form sends a JSON body containing your modifications to the
configured API Gateway endpoint. API Gateway invokes the Lambda function, which
returns the location of the generated page. The script in `main.js` redirects
the browser to that URL (using `cloudfrontUrl` if only a path is returned).

