# Landing as a Service (LaaS)

A plug-and-play web application that generates themed landing pages based on industry prompts and target website URLs. The system uses AWS Bedrock to create landing pages that match the look and feel of existing websites.

## 🚀 Quick Start - Fully Automated Deployment

### Prerequisites
- AWS CLI configured with appropriate permissions
- Docker (for building Puppeteer Lambda)
- Node.js and Python (for building other Lambdas)

### One-Command Deployment

1. **Set AWS credentials:**
```bash
export AWS_ACCESS_KEY_ID="your_access_key"
export AWS_SECRET_ACCESS_KEY="your_secret_key" 
export AWS_SESSION_TOKEN="your_session_token"  # If using temporary credentials
export AWS_REGION="us-west-2"
```

2. **Deploy everything:**
```bash
bash build_and_deploy_all.sh
```

This single command will:
- Build and deploy the Puppeteer Lambda (Docker-based)
- Build and deploy the Orchestrator Lambda (Python)
- Build and deploy the Bedrock Lambda (Python)
- Deploy all infrastructure (S3, IAM, API Gateway, etc.)

**No manual AWS Console steps required!**

## 🎯 How It Works

1. **User Input:** Enter an industry prompt and target website URL
2. **Puppeteer Lambda:** Extracts theme information (colors, fonts, logos) from the target site
3. **Orchestrator Lambda:** Coordinates the workflow between services
4. **Bedrock Lambda:** Generates a themed landing page using AWS Bedrock
5. **Output:** Returns a complete landing page that matches the target site's theme

## 📁 Project Structure

```
landing_as_a_service/
├── build_and_deploy_all.sh          # Main deployment script
├── infrastructure/
│   ├── terraform_modules/           # Reusable Terraform modules
│   │   ├── puppeteer_lambda/        # Puppeteer Lambda (Docker)
│   │   ├── orchestrator_lambda/     # Orchestrator Lambda (Python)
│   │   ├── lambda/                  # Bedrock Lambda (Python)
│   │   ├── api_gateway/             # API Gateway
│   │   ├── cognito/                 # User authentication
│   │   ├── cloudfront/              # CDN for serving pages
│   │   └── s3_bucket/               # S3 buckets
│   └── terraform/environment/prod/  # Production environment
└── web/                             # Frontend application
    ├── index.html                   # Main web interface
    ├── main.js                      # Frontend logic
    └── config.example.js            # Configuration template
```

## 🌐 Running the Web App Locally

1. **Configure the web app:**
   - Copy the example config and update with your values:
     ```bash
     cd web
     cp config.example.js config.js
     ```
   - Edit `config.js` and fill in your API endpoint, Cognito info, etc.

2. **Start a local web server:**
   - With Python 3:
```bash
     python3 -m http.server 8000
     ```
   - Or with Node.js:
     ```bash
     npx http-server -p 8000
     ```

3. **Open your browser:**
   - Go to [http://localhost:8000](http://localhost:8000)

4. **Use the app:**
   - Enter your prompt and target URL in the web form.
   - Submit and see the generated landing page!

## 🔧 Configuration

Get the required values from your deployment:
```bash
cd infrastructure/terraform/environment/prod
terragrunt output
```

## 🏗️ Architecture

- **Frontend:** Simple HTML/JS interface
- **API Gateway:** RESTful API endpoint
- **Lambda Functions:** 
  - Puppeteer: Web scraping and theme extraction
  - Orchestrator: Workflow coordination
  - Bedrock: AI-powered content generation
- **S3:** Storage for input/output files
- **CloudFront:** CDN for serving generated pages
- **Cognito:** User authentication (optional)

## 🚨 Troubleshooting

### Common Issues

1. **AWS Credentials Expired:** Refresh your temporary credentials
2. **Docker Build Fails:** Ensure Docker is running and has sufficient resources
3. **Terragrunt Errors:** Check that the `ENV=prod` variable is set

### Manual Steps (if needed)

If the automated script fails, you can run individual components:

   ```bash
# Build Puppeteer Lambda
cd infrastructure/terraform_modules/puppeteer_lambda
./build/rebuild_and_deploy.sh

# Build Orchestrator Lambda  
cd infrastructure/terraform_modules/orchestrator_lambda
./build/build.sh

# Build Bedrock Lambda
cd infrastructure/terraform_modules/lambda/build
./build.sh

# Deploy infrastructure
cd infrastructure/terraform/environment/prod
terragrunt run-all apply
```

## 📄 License

This project is licensed under the [MIT License](LICENSE).

