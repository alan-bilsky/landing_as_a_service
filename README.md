# Landing as a Service (LaaS)

A comprehensive, production-ready web application that generates AI-powered landing pages tailored to specific industries and website themes. The system analyzes target websites, extracts design elements, and creates custom landing pages using AWS Bedrock AI technology.

## 🚀 Features

- **AI-Powered Content Generation**: Uses AWS Bedrock (Claude 3.5 Sonnet) for intelligent landing page creation
- **Advanced Website Analysis**: Enhanced Puppeteer-based scraping with 403 error bypass capabilities
- **Theme-Aware Design**: Automatically matches colors, fonts, and styling from target websites
- **Scalable Architecture**: Fully serverless with automatic scaling and monitoring
- **Professional UI**: Clean, modern chat interface for easy interaction
- **Comprehensive Testing**: Full test suite with pytest and mocking
- **Production Ready**: WAF protection, CloudFront CDN, and security best practices

## 🏗️ Architecture

The system uses a **4-Lambda microservices architecture** orchestrated through API Gateway:

### Core Components

1. **🔍 Fetch Site Lambda** (`fetch_site`)
   - **Technology**: Node.js 16 + Puppeteer (Docker-based)
   - **Purpose**: Fetches and analyzes target websites
   - **Features**: Enhanced 403 error handling, stealth browsing, cookie banner dismissal
   - **Deployment**: ECR container with automatic updates

2. **🤖 Gen Landing Lambda** (`gen_landing`)
   - **Technology**: Python 3.12 + AWS Bedrock
   - **Purpose**: Generates landing page content using Claude 3.5 Sonnet
   - **Features**: Industry-specific prompts, image generation, content optimization
   - **Models**: Anthropic Claude 3.5 Sonnet, Amazon Titan Image Generator

3. **🔧 Inject HTML Lambda** (`inject_html`)
   - **Technology**: Python 3.12 + BeautifulSoup4
   - **Purpose**: Merges generated content with original website HTML
   - **Features**: Smart CSS injection, responsive design, CloudFront invalidation
   - **Output**: Production-ready HTML pages

4. **🎯 Orchestrator Lambda** (`orchestrator`)
   - **Technology**: Python 3.12 + AWS SDK
   - **Purpose**: Coordinates workflow between all services
   - **Features**: Async job management, status tracking, error handling
   - **Integration**: API Gateway, S3 status storage

### Supporting Infrastructure

- **📡 API Gateway**: RESTful API with CORS, rate limiting, and logging
- **🌐 CloudFront**: Global CDN with WAF protection and custom domain support
- **🗄️ S3 Storage**: Organized buckets with `raw/`, `generated/`, and `public/` prefixes
- **🔐 IAM Security**: Least-privilege roles with comprehensive policy management
- **📊 CloudWatch**: Comprehensive logging, metrics, and alerting
- **⚙️ SSM Parameters**: Centralized configuration management
- **🔒 Cognito**: Optional user authentication and authorization

## 🚦 Quick Start

### Prerequisites

- **AWS CLI** configured with appropriate permissions
- **Docker** (for Puppeteer Lambda builds)
- **Terraform** >= 1.1 and **Terragrunt** >= 0.50
- **Node.js** >= 16 and **Python** >= 3.12

### One-Command Deployment

```bash
# Set AWS credentials
export AWS_ACCESS_KEY_ID="your_access_key"
export AWS_SECRET_ACCESS_KEY="your_secret_key"
export AWS_SESSION_TOKEN="your_session_token"  # If using temporary credentials

# Deploy everything
make deploy
```

This will:
- ✅ Build all Lambda functions (including Docker image for Puppeteer)
- ✅ Deploy complete infrastructure with Terragrunt
- ✅ Configure API Gateway, CloudFront, and S3
- ✅ Set up monitoring and security
- ✅ Deploy web interface

### Available Commands

```bash
make help              # Show all available commands
make build             # Build all Lambda functions
make test              # Run comprehensive test suite
make deploy            # Full deployment (build + infrastructure)
make deploy-confirm    # Deploy with manual confirmation
make validate          # Validate Terraform configuration
make clean             # Clean build artifacts
make status            # Show deployment status
make destroy           # Destroy all infrastructure (with confirmation)
make dev               # Start local development server
```

## 🌐 Web Interface

### Local Development

```bash
# Start local development server
make dev

# Or manually:
cd web
python3 -m http.server 8080
```

Navigate to `http://localhost:8080` to access the interface.

### Production Usage

1. **Access the Interface**: Use your deployed API Gateway URL
2. **Enter Details**: 
   - Website URL to analyze
   - Industry or landing page description
3. **Generate**: Click "Generate Landing Page"
4. **Track Progress**: Monitor real-time status updates
5. **View Result**: Access your generated landing page via CloudFront

## 📁 Project Structure

```
landing_as_a_service/
├── 📋 Makefile                           # Main deployment commands
├── 🚀 build_and_deploy_all.sh           # Complete deployment script
├── 📦 package.json                       # Node.js dependencies
├── 📄 README.md                          # This file
├── 🔧 infrastructure/                    # Infrastructure as Code
│   ├── terraform_modules/               # Reusable Terraform modules
│   │   ├── 🔍 puppeteer_lambda/         # Fetch Site Lambda (Docker)
│   │   │   ├── main.tf                  # Lambda + ECR configuration
│   │   │   ├── Dockerfile               # Container definition
│   │   │   └── build/                   # Lambda source code
│   │   │       ├── index.js             # Main handler
│   │   │       ├── package.json         # Dependencies
│   │   │       └── rebuild_and_deploy.sh # Build script
│   │   ├── 🤖 lambda/                   # Gen Landing Lambda
│   │   │   └── build/                   # Python source code
│   │   │       ├── handler.py           # Main handler
│   │   │       ├── requirements.txt     # Dependencies
│   │   │       └── build.sh             # Build script
│   │   ├── 🔧 inject_html_lambda/       # Inject HTML Lambda
│   │   │   └── build/                   # Python source code
│   │   ├── 🎯 orchestrator_lambda/      # Orchestrator Lambda
│   │   │   └── build/                   # Python source code
│   │   ├── 📡 api_gateway/              # API Gateway configuration
│   │   ├── 🌐 cloudfront/               # CloudFront + WAF
│   │   ├── 🗄️ s3_bucket/                # S3 storage
│   │   ├── 🔐 iam_roles/                # IAM policies
│   │   ├── 🔒 cognito/                  # User authentication
│   │   └── ⚙️ ssm_parameters/           # Configuration management
│   └── terraform/                       # Environment configurations
│       ├── globals/                     # Global Terraform settings
│       │   ├── versions.tf              # Provider versions (AWS ~> 6.2.0)
│       │   ├── provider.tf              # AWS provider configuration
│       │   └── variables.tf             # Global variables
│       └── environment/prod/            # Production environment
│           ├── environment.hcl          # Environment variables
│           └── */terragrunt.hcl         # Service configurations
├── 🌐 web/                              # Frontend application
│   ├── index.html                       # Main interface
│   ├── index-with-auth.html             # Authenticated interface
│   ├── chat.js                          # Frontend logic
│   ├── config.js                        # API configuration
│   ├── styles.css                       # Styling
│   └── landing_template.html            # Template for generation
├── 🧪 tests/                            # Comprehensive test suite
│   ├── conftest.py                      # Test configuration
│   ├── pytest.ini                       # Pytest settings
│   ├── requirements.txt                 # Test dependencies
│   └── test_*.py                        # Individual test files
├── 📜 scripts/                          # Helper scripts
│   └── run_tests.sh                     # Test runner
└── 🎯 .cursor/                          # Project-specific IDE rules
    └── rules/laas.mdc                   # Development guidelines
```

## 🔧 Configuration

### Environment Variables

The system uses `ENV=prod` by default. Key configuration:

```bash
# Always exported by Makefile
ENV=prod
AWS_REGION=us-west-2
AWS_ACCOUNT_ID=767397808556
```

### API Configuration

The web interface uses `web/config.js`:

```javascript
const config = {
    apiEndpoint: 'https://your-api-id.execute-api.us-west-2.amazonaws.com',
    maxRetries: 3,
    retryDelay: 1000,
    statusCheckInterval: 2000,
    timeout: 300000 // 5 minutes
};
```

### AWS Bedrock Models

- **Primary**: `anthropic.claude-3-5-sonnet-20241022-v2:0`
- **Image Generation**: `amazon.titan-image-generator-v2:0`
- **Fallback**: `anthropic.claude-3-sonnet-20240229`

## 🔒 Security Features

- **WAF Protection**: AWS managed rule sets for CloudFront
- **IAM Least Privilege**: Role-based access with minimal permissions
- **S3 Security**: Private buckets with OAI/OAC access control
- **API Rate Limiting**: Configured through API Gateway
- **Encryption**: At-rest and in-transit encryption for all data
- **Network Security**: VPC endpoints and private subnets where applicable

## 🧪 Testing

### Run Tests

```bash
# Run all tests
make test

# Run specific test categories
cd tests
python -m pytest test_fetch_site_lambda.py -v
python -m pytest test_gen_landing_lambda.py -v
python -m pytest test_inject_html_lambda.py -v
```

### Test Coverage

- **Unit Tests**: All Lambda functions
- **Integration Tests**: API Gateway endpoints
- **Mocking**: AWS services with moto/boto3
- **Performance Tests**: Load testing scenarios

## 📊 Monitoring & Logs

### CloudWatch Logs

```bash
# View recent logs
make logs

# Manual log access
aws logs tail /aws/lambda/lpgen-prod-us-west-2-orchestrator --since 1h
aws logs tail /aws/lambda/lpgen-prod-us-west-2-fetch-site --since 1h
aws logs tail /aws/lambda/lpgen-prod-us-west-2-gen-landing --since 1h
aws logs tail /aws/lambda/lpgen-prod-us-west-2-inject-html --since 1h
```

### Status Monitoring

```bash
# Check deployment status
make status

# Get API endpoint
make get-endpoint

# Get CloudFront URL
make get-cloudfront
```

## 🚨 Troubleshooting

### Common Issues

1. **AWS Provider Version**: Ensure `~> 6.2.0` is configured in `versions.tf`
2. **ENV Variable**: System requires `ENV=prod` for all operations
3. **Docker Issues**: Ensure Docker is running for Puppeteer Lambda builds
4. **Credentials**: Use fresh AWS credentials for deployments
5. **403 Errors**: System includes advanced bypass techniques, but some sites may still block

### Debug Mode

```bash
# Enable debug logging
export TF_LOG=DEBUG
export TERRAGRUNT_DEBUG=true

# Run with verbose output
make deploy 2>&1 | tee deployment.log
```

### Support

For issues related to:
- **Infrastructure**: Check CloudWatch logs and Terraform state
- **Lambda Functions**: Review function logs and error messages
- **API Gateway**: Verify endpoint configuration and CORS settings
- **Frontend**: Check browser console and network requests

## 📈 Performance

### Lambda Specifications

- **Fetch Site**: 1536MB memory, 60s timeout, ARM64 architecture
- **Gen Landing**: 256MB memory, 60s timeout, ARM64 architecture  
- **Inject HTML**: 256MB memory, 60s timeout, ARM64 architecture
- **Orchestrator**: 256MB memory, 120s timeout, ARM64 architecture

### Expected Performance

- **Site Fetch**: 5-30 seconds (depending on site complexity)
- **Content Generation**: 10-45 seconds (AI processing time)
- **HTML Injection**: 2-10 seconds (content merging)
- **Total Workflow**: 30-120 seconds end-to-end

## 🔄 Workflow

1. **User Request** → API Gateway → Orchestrator Lambda
2. **Orchestrator** → Fetch Site Lambda → Extract HTML/CSS
3. **Orchestrator** → Gen Landing Lambda → Generate AI content
4. **Orchestrator** → Inject HTML Lambda → Merge & deploy
5. **Result** → CloudFront → User receives final landing page

## 📄 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## 🤝 Contributing

1. Fork the repository
2. Create a feature branch
3. Add comprehensive tests
4. Ensure all tests pass
5. Submit a pull request

## 📞 Support

For questions or support, please create an issue in the GitHub repository.

---

**🎉 Ready to deploy?** Run `make deploy` and start generating AI-powered landing pages in minutes!

