# Puppeteer Lambda Module

This module deploys a Node.js Lambda function that uses Puppeteer to render dynamic websites and return the fully rendered HTML.

## Build & Deploy Instructions

1. Place your Node.js Lambda code (index.js, package.json) in `build/`.
2. Run `npm install` in the `build/` directory to install dependencies.
3. Zip the contents of `build/` (including `node_modules`) as `lambda-puppeteer.zip`:
   
   ```bash
   cd build
   npm install
   zip -r lambda-puppeteer.zip index.js package.json node_modules/
   ```
4. Place `lambda-puppeteer.zip` in this module's `build/` directory.
5. Run `terragrunt apply` in the appropriate environment directory to deploy.

## Docker Deployment Checklist

1. Ensure your Lambda handler (index.js) is implemented and tested locally.
2. In the `build/` directory, run:
   ```bash
   npm install
   ```
3. From the `puppeteer_lambda` module root, run:
   ```bash
   ./build/build.sh
   ```
   This will build the Docker image and push it to ECR.
4. Run `terragrunt apply` in your environment directory (e.g., `environment/prod/puppeteer_lambda/`) to deploy the updated Lambda.
5. Verify deployment:
   - Check the AWS Lambda console for the function image update.
   - Test the Lambda via API Gateway or the AWS console with an event like:
     ```json
     { "url": "https://example.com", "screenshot": false }
     ```
   - Confirm you receive the rendered HTML or a screenshot (if `screenshot: true`).
6. Troubleshoot any errors by checking Lambda logs in CloudWatch.

## Handler
- Handler: `index.handler`
- Runtime: `nodejs18.x`

## Environment Variables
- Add any required environment variables to `main.tf` as needed. 