# Landing as a Service - Makefile
# Comprehensive deployment and management commands

.PHONY: help deploy build test clean lint format check-deps validate

# Default environment and region
ENV ?= prod
AWS_REGION ?= us-west-2
TERRAGRUNT_DIR = infrastructure/terraform/environment/$(ENV)

# Export environment variables to shell
export ENV
export AWS_REGION

# Colors for output
RED := \033[0;31m
GREEN := \033[0;32m
YELLOW := \033[1;33m
BLUE := \033[0;34m
NC := \033[0m # No Color

# Help target - shows available commands
help: ## Show this help message
	@echo "$(BLUE)Landing as a Service - Available Commands$(NC)"
	@echo "========================================"
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | sort | awk 'BEGIN {FS = ":.*?## "}; {printf "$(GREEN)%-20s$(NC) %s\n", $$1, $$2}'
	@echo ""
	@echo "$(YELLOW)Environment Variables:$(NC)"
	@echo "  ENV=$(ENV) (default: prod)"
	@echo "  AWS_REGION=$(AWS_REGION) (default: us-west-2)"

# Check dependencies
check-deps: ## Check if required tools are installed
	@echo "$(BLUE)Checking dependencies...$(NC)"
	@command -v terragrunt >/dev/null 2>&1 || { echo "$(RED)Error: terragrunt is required but not installed$(NC)"; exit 1; }
	@command -v terraform >/dev/null 2>&1 || { echo "$(RED)Error: terraform is required but not installed$(NC)"; exit 1; }
	@command -v aws >/dev/null 2>&1 || { echo "$(RED)Error: aws CLI is required but not installed$(NC)"; exit 1; }
	@command -v docker >/dev/null 2>&1 || { echo "$(RED)Error: docker is required but not installed$(NC)"; exit 1; }
	@command -v python3 >/dev/null 2>&1 || { echo "$(RED)Error: python3 is required but not installed$(NC)"; exit 1; }
	@command -v zip >/dev/null 2>&1 || { echo "$(RED)Error: zip is required but not installed$(NC)"; exit 1; }
	@echo "$(GREEN)✓ All dependencies are installed$(NC)"

# Validate AWS credentials
check-aws: ## Check AWS credentials and permissions
	@echo "$(BLUE)Checking AWS credentials...$(NC)"
	@aws sts get-caller-identity > /dev/null || { echo "$(RED)Error: AWS credentials not configured$(NC)"; exit 1; }
	@echo "$(GREEN)✓ AWS credentials are valid$(NC)"
	@echo "Account: $$(aws sts get-caller-identity --query Account --output text)"
	@echo "Region: $(AWS_REGION)"

# Build all Lambda functions
build: check-deps ## Build all Lambda functions
	@echo "$(BLUE)Building all Lambda functions...$(NC)"
	
	@echo "$(YELLOW)Building Puppeteer Lambda (fetch-site)...$(NC)"
	@cd infrastructure/terraform_modules/puppeteer_lambda && \
		chmod +x build/rebuild_and_deploy.sh && \
		ENV=$(ENV) AWS_REGION=$(AWS_REGION) ./build/rebuild_and_deploy.sh build-only
	
	@echo "$(YELLOW)Building Gen Landing Lambda...$(NC)"
	@cd infrastructure/terraform_modules/lambda/build && \
		chmod +x build.sh && \
		./build.sh
	
	@echo "$(YELLOW)Building Inject HTML Lambda...$(NC)"
	@cd infrastructure/terraform_modules/inject_html_lambda/build && \
		chmod +x build.sh && \
		./build.sh
	
	@echo "$(YELLOW)Building Orchestrator Lambda...$(NC)"
	@cd infrastructure/terraform_modules/orchestrator_lambda/build && \
		chmod +x build.sh && \
		./build.sh
	
	@echo "$(GREEN)✓ All Lambda functions built successfully$(NC)"

# Run tests
test: ## Run the complete test suite
	@echo "$(BLUE)Running test suite...$(NC)"
	@chmod +x scripts/run_tests.sh
	@./scripts/run_tests.sh

# Lint and format code
lint: ## Lint all code (Python, JavaScript, Terraform)
	@echo "$(BLUE)Linting code...$(NC)"
	
	@if command -v black >/dev/null 2>&1; then \
		echo "$(YELLOW)Formatting Python code with black...$(NC)"; \
		find . -name "*.py" -not -path "./tests/venv/*" -not -path "./.git/*" -exec black {} +; \
	else \
		echo "$(YELLOW)black not installed, skipping Python formatting$(NC)"; \
	fi
	
	@if command -v isort >/dev/null 2>&1; then \
		echo "$(YELLOW)Sorting Python imports with isort...$(NC)"; \
		find . -name "*.py" -not -path "./tests/venv/*" -not -path "./.git/*" -exec isort {} +; \
	else \
		echo "$(YELLOW)isort not installed, skipping import sorting$(NC)"; \
	fi
	
	@if command -v tflint >/dev/null 2>&1; then \
		echo "$(YELLOW)Linting Terraform code...$(NC)"; \
		find infrastructure/terraform_modules -name "*.tf" -execdir tflint {} +; \
	else \
		echo "$(YELLOW)tflint not installed, skipping Terraform linting$(NC)"; \
	fi
	
	@echo "$(GREEN)✓ Code linting completed$(NC)"

# Validate Terraform configuration
validate: check-deps ## Validate Terraform and Terragrunt configuration
	@echo "$(BLUE)Validating Terraform configuration...$(NC)"
	@cd $(TERRAGRUNT_DIR) && ENV=$(ENV) terragrunt validate-all
	@echo "$(GREEN)✓ Terraform configuration is valid$(NC)"

# Plan deployment
plan: check-deps check-aws build ## Plan the deployment (terraform plan)
	@echo "$(BLUE)Planning deployment for environment: $(ENV)$(NC)"
	@cd $(TERRAGRUNT_DIR) && ENV=$(ENV) terragrunt plan-all

# Deploy everything
deploy: check-deps check-aws build ## Deploy all infrastructure and Lambda functions
	@echo "$(BLUE)Deploying Landing as a Service to $(ENV) environment...$(NC)"
	@echo "$(YELLOW)This will deploy to AWS region: $(AWS_REGION)$(NC)"
	@echo ""
	
	@echo "$(YELLOW)Building Puppeteer Lambda and pushing to ECR...$(NC)"
	@cd infrastructure/terraform_modules/puppeteer_lambda && \
		ENV=$(ENV) AWS_REGION=$(AWS_REGION) ./build/rebuild_and_deploy.sh
	
	@echo "$(YELLOW)Deploying all infrastructure with Terragrunt...$(NC)"
	@cd $(TERRAGRUNT_DIR) && \
		ENV=$(ENV) terragrunt apply-all --terragrunt-non-interactive --auto-approve
	
	@echo ""
	@echo "$(GREEN)🚀 Deployment completed successfully!$(NC)"
	@echo "$(BLUE)The three-step workflow is now ready:$(NC)"
	@echo "  1. fetch_site → 2. gen_landing → 3. inject_html"
	@echo ""
	@echo "$(YELLOW)API Endpoint:$(NC) $$(cd $(TERRAGRUNT_DIR)/api_gateway && terragrunt output -raw api_endpoint 2>/dev/null || echo 'Run: make get-endpoint')"

# Deploy with confirmation
deploy-confirm: check-deps check-aws build plan ## Deploy with manual confirmation
	@echo "$(YELLOW)Review the plan above. Do you want to proceed with deployment? [y/N]$(NC)"
	@read -p "" confirm && [ "$$confirm" = "y" ] || [ "$$confirm" = "Y" ] || { echo "Deployment cancelled."; exit 1; }
	@make deploy

# Get API endpoint
get-endpoint: ## Get the deployed API Gateway endpoint URL
	@echo "$(BLUE)API Gateway Endpoint:$(NC)"
	@cd $(TERRAGRUNT_DIR)/api_gateway && ENV=$(ENV) terragrunt output -raw api_endpoint 2>/dev/null || echo "API Gateway not deployed yet"

# Get CloudFront URL
get-cloudfront: ## Get the CloudFront distribution URL
	@echo "$(BLUE)CloudFront Distribution:$(NC)"
	@cd $(TERRAGRUNT_DIR)/cloudfront && ENV=$(ENV) terragrunt output -raw distribution_domain_name 2>/dev/null || echo "CloudFront not deployed yet"

# Clean up build artifacts
clean: ## Clean up build artifacts and temporary files
	@echo "$(BLUE)Cleaning up build artifacts...$(NC)"
	@find . -name "*.zip" -path "*/terraform_modules/*/build/*" -delete
	@find . -name "lambda.zip" -delete
	@find . -name "__pycache__" -type d -exec rm -rf {} + 2>/dev/null || true
	@find . -name "*.pyc" -delete 2>/dev/null || true
	@rm -rf tests/venv 2>/dev/null || true
	@echo "$(GREEN)✓ Build artifacts cleaned$(NC)"

# Destroy infrastructure (with confirmation)
destroy: check-deps check-aws ## Destroy all infrastructure (with confirmation)
	@echo "$(RED)⚠️  WARNING: This will destroy ALL infrastructure in $(ENV) environment!$(NC)"
	@echo "$(YELLOW)Are you sure you want to proceed? Type 'yes' to confirm:$(NC)"
	@read -p "" confirm && [ "$$confirm" = "yes" ] || { echo "Destruction cancelled."; exit 1; }
	@echo "$(BLUE)Destroying infrastructure...$(NC)"
	@cd $(TERRAGRUNT_DIR) && ENV=$(ENV) terragrunt destroy-all --terragrunt-non-interactive --auto-approve
	@echo "$(GREEN)Infrastructure destroyed$(NC)"

# Show status of deployed resources
status: ## Show status of deployed resources
	@echo "$(BLUE)LaaS Infrastructure Status$(NC)"
	@echo "=========================="
	@echo "Environment: $(ENV)"
	@echo "Region: $(AWS_REGION)"
	@echo ""
	
	@echo "$(YELLOW)Lambda Functions:$(NC)"
	@aws lambda list-functions --region $(AWS_REGION) --query 'Functions[?starts_with(FunctionName, `lpgen-$(ENV)`)].{Name:FunctionName,Runtime:Runtime,Status:State}' --output table 2>/dev/null || echo "No Lambda functions found"
	@echo ""
	
	@echo "$(YELLOW)S3 Buckets:$(NC)"
	@aws s3 ls | grep "lpgen-$(ENV)" || echo "No S3 buckets found"
	@echo ""
	
	@echo "$(YELLOW)API Gateway:$(NC)"
	@make get-endpoint
	@echo ""
	
	@echo "$(YELLOW)CloudFront:$(NC)"
	@make get-cloudfront

# Initialize development environment
init: check-deps ## Initialize development environment
	@echo "$(BLUE)Initializing development environment...$(NC)"
	
	@echo "$(YELLOW)Installing Python testing dependencies...$(NC)"
	@python3 -m venv tests/venv
	@tests/venv/bin/pip install -r tests/requirements.txt
	
	@echo "$(YELLOW)Installing pre-commit hooks...$(NC)"
	@if command -v pre-commit >/dev/null 2>&1; then \
		pre-commit install; \
	else \
		echo "pre-commit not installed, skipping hooks"; \
	fi
	
	@echo "$(GREEN)✓ Development environment initialized$(NC)"
	@echo "$(BLUE)Next steps:$(NC)"
	@echo "  1. Configure AWS credentials: aws configure"
	@echo "  2. Run tests: make test"
	@echo "  3. Deploy: make deploy"

# Quick deploy for development (skips tests)
deploy-dev: build ## Quick deploy for development (skips tests)
	@echo "$(YELLOW)⚡ Quick development deploy (skips tests)$(NC)"
	@make deploy

# Format all code
format: ## Format all code (Python, JavaScript)
	@echo "$(BLUE)Formatting all code...$(NC)"
	@make lint

# Show logs from Lambda functions
logs: ## Show recent logs from Lambda functions
	@echo "$(BLUE)Recent Lambda function logs:$(NC)"
	@echo "$(YELLOW)Orchestrator Lambda:$(NC)"
	@aws logs tail /aws/lambda/lpgen-$(ENV)-$(AWS_REGION)-orchestrator --since 1h --region $(AWS_REGION) || echo "No logs found"

# Start development server
dev: ## Start local development server on http://localhost:8080
	@echo "$(BLUE)Starting development server...$(NC)"
	@echo "$(YELLOW)Frontend will be available at: http://localhost:8080$(NC)"
	@echo "$(YELLOW)API Endpoint configured: https://sfwwrb68gf.execute-api.us-west-2.amazonaws.com/chat$(NC)"
	@echo "$(GREEN)Press Ctrl+C to stop the server$(NC)"
	@echo ""
	@cd web && python3 -m http.server 8080

# Update deployment
update: build deploy ## Update existing deployment

# Default target
.DEFAULT_GOAL := help

# Ensure we fail on any command failure
.ONESHELL: 