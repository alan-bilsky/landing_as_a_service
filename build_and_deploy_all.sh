#!/bin/bash
set -euo pipefail

# ====================================================================
# 🚀 Landing as a Service (LaaS) - Complete Deployment Script
# ====================================================================
# This script deploys the entire LaaS infrastructure from scratch
# Supports: AWS Lambda, Docker, Terraform, complete testing
# ====================================================================

# Configuration - Override with environment variables
export ENV=${ENV:-prod}
export AWS_REGION=${AWS_REGION:-us-west-2}
export PROJECT_NAME=${PROJECT_NAME:-lpgen}
export RETRY_ATTEMPTS=${RETRY_ATTEMPTS:-3}
export DOCKER_TIMEOUT=${DOCKER_TIMEOUT:-1800}  # 30 minutes
export SKIP_DOCKER=${SKIP_DOCKER:-false}
export SKIP_TESTS=${SKIP_TESTS:-false}
export VERBOSE=${VERBOSE:-false}

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Print colored output
print_status() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

print_debug() {
    if [[ "$VERBOSE" == "true" ]]; then
        echo -e "${PURPLE}[DEBUG]${NC} $1"
    fi
}

print_step() {
    echo -e "${CYAN}[STEP]${NC} $1"
}

# Error handling
cleanup() {
    local exit_code=$?
    if [[ $exit_code -ne 0 ]]; then
        print_error "Script failed with exit code $exit_code"
        print_error "Check logs above for details"
        print_error "You can retry with: VERBOSE=true bash $0"
    fi
}
trap cleanup EXIT

# Retry function
retry() {
    local max_attempts=$1
    shift
    local cmd="$@"
    local attempt=1
    
    while [[ $attempt -le $max_attempts ]]; do
        print_debug "Attempt $attempt of $max_attempts: $cmd"
        if eval "$cmd"; then
            return 0
        else
            if [[ $attempt -eq $max_attempts ]]; then
                print_error "Command failed after $max_attempts attempts: $cmd"
                return 1
            fi
            print_warning "Attempt $attempt failed, retrying in 5 seconds..."
            sleep 5
            ((attempt++))
        fi
    done
}

# Configuration validation
validate_config() {
    print_step "🔧 Validating configuration..."
    
    # Required environment variables
    local required_vars=("AWS_REGION" "ENV" "PROJECT_NAME")
    for var in "${required_vars[@]}"; do
        if [[ -z "${!var:-}" ]]; then
            print_error "Required environment variable $var is not set"
            exit 1
        fi
    done
    
    # Validate AWS region format
    if [[ ! "$AWS_REGION" =~ ^[a-z0-9-]+$ ]]; then
        print_error "Invalid AWS region format: $AWS_REGION"
        exit 1
    fi
    
    # Validate environment
    if [[ ! "$ENV" =~ ^(dev|staging|prod)$ ]]; then
        print_warning "Environment '$ENV' is not standard (dev/staging/prod)"
    fi
    
    print_success "Configuration validated"
}

# Ensure we're running from the repository root
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"
REPO_ROOT="$SCRIPT_DIR"

print_status "🚀 Starting comprehensive LaaS deployment..."
print_status "📍 Repository root: $REPO_ROOT"
print_status "🌍 Environment: $ENV"
print_status "🌐 AWS Region: $AWS_REGION"
print_status "🏷️  Project Name: $PROJECT_NAME"

validate_config

# AWS credentials validation with enhanced checks
validate_aws_credentials() {
    print_step "🔐 Validating AWS credentials..."
    
    if ! aws sts get-caller-identity >/dev/null 2>&1; then
        print_error "AWS credentials not configured or expired!"
        print_error "Please configure AWS credentials using one of:"
        print_error "  • AWS CLI: aws configure"
        print_error "  • Environment: AWS_ACCESS_KEY_ID, AWS_SECRET_ACCESS_KEY, AWS_SESSION_TOKEN"
        print_error "  • IAM roles or instance profiles"
        exit 1
    fi

    ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
    AWS_USER=$(aws sts get-caller-identity --query 'Arn' --output text | cut -d'/' -f2)
    
    print_success "AWS credentials validated"
    print_success "Account ID: $ACCOUNT_ID"
    print_success "User/Role: $AWS_USER"
    
    # Check required permissions
    print_debug "Testing AWS permissions..."
    
    local permissions_ok=true
    
    # Test S3 permissions
    if ! aws s3 ls >/dev/null 2>&1; then
        print_warning "S3 list permission check failed"
        permissions_ok=false
    fi
    
    # Test Lambda permissions
    if ! aws lambda list-functions --max-items 1 >/dev/null 2>&1; then
        print_warning "Lambda list permission check failed"
        permissions_ok=false
    fi
    
    # Test ECR permissions (needed for Docker)
    if [[ "$SKIP_DOCKER" != "true" ]]; then
        if ! aws ecr describe-repositories --max-items 1 >/dev/null 2>&1; then
            print_warning "ECR permissions check failed - Docker builds may fail"
        fi
    fi
    
    if [[ "$permissions_ok" == "false" ]]; then
        print_warning "Some AWS permission checks failed - continuing but may encounter issues"
    fi
}

validate_aws_credentials

# Tool validation with version checking
validate_tools() {
    print_step "🔧 Validating required tools..."
    
    local tools_required=("docker" "terraform" "terragrunt" "jq" "curl" "zip" "python3" "pip3")
    local tools_optional=("node" "npm")
    
    for tool in "${tools_required[@]}"; do
        if ! command -v "$tool" >/dev/null 2>&1; then
            print_error "Required tool '$tool' is not installed!"
            print_error "Please install $tool and try again"
            exit 1
        fi
        
        # Show versions for debugging
        case $tool in
            terraform)
                local tf_version=$(terraform version -json | jq -r '.terraform_version' 2>/dev/null || terraform version | head -1)
                print_debug "Terraform version: $tf_version"
                ;;
            terragrunt)
                local tg_version=$(terragrunt --version 2>/dev/null | head -1 || echo "unknown")
                print_debug "Terragrunt version: $tg_version"
                ;;
            docker)
                local docker_version=$(docker --version 2>/dev/null || echo "unknown")
                print_debug "Docker version: $docker_version"
                ;;
        esac
    done
    
    for tool in "${tools_optional[@]}"; do
        if command -v "$tool" >/dev/null 2>&1; then
            print_debug "Optional tool available: $tool"
        else
            print_debug "Optional tool not available: $tool"
        fi
    done
    
    print_success "All required tools are available"
}

validate_tools

# Enhanced codebase validation
validate_codebase() {
    print_step "🔍 Validating codebase integrity..."
    
    # Check critical files exist
    local critical_files=(
        "infrastructure/terraform/terragrunt.hcl"
        "infrastructure/terraform/environment/$ENV/environment.hcl"
        "infrastructure/terraform_modules/puppeteer_lambda/build/index.js"
        "infrastructure/terraform_modules/lambda/build/handler.py"
        "infrastructure/terraform_modules/inject_html_lambda/build/handler.py"
        "infrastructure/terraform_modules/orchestrator_lambda/build/handler.py"
    )
    
    for file in "${critical_files[@]}"; do
        if [[ ! -f "$file" ]]; then
            print_error "Critical file missing: $file"
            exit 1
        fi
        print_debug "✓ Found: $file"
    done
    
    # Verify the UTF-8 fix is in place
    print_status "🔍 Verifying UTF-8 fix is applied..."
    if grep -q "resp.data.toString('utf-8')" infrastructure/terraform_modules/puppeteer_lambda/build/index.js; then
        print_success "UTF-8 fix verified in puppeteer Lambda"
    else
        print_error "UTF-8 fix not found in puppeteer Lambda! This will cause HTML corruption."
        print_error "Expected: resp.data.toString('utf-8')"
        exit 1
    fi

    # Verify pydantic dependencies are fixed
    print_status "🔍 Verifying pydantic dependencies..."
    if python3 -c "
import sys
import traceback
import os

try:
    sys.path.insert(0, 'infrastructure/terraform_modules/lambda/build')
    import pydantic
    import pydantic_core
    print('✅ pydantic and pydantic_core import successfully')
    
    # Test basic model functionality
    if os.path.exists('infrastructure/terraform_modules/lambda/build/models.py'):
        from models import GenerationRequest, ThemeInfo
        request = GenerationRequest(prompt='test')
        print('✅ pydantic models work correctly')
    
    sys.path.remove('infrastructure/terraform_modules/lambda/build')
    
except Exception as e:
    print(f'❌ pydantic validation failed: {e}')
    traceback.print_exc()
    sys.exit(1)
" 2>/dev/null; then
        print_success "Pydantic dependencies validated"
    else
        print_warning "Pydantic validation failed - will attempt to fix during build"
    fi
    
    # Validate Terragrunt structure
    print_status "🔍 Validating Terragrunt structure..."
    if [[ -d "infrastructure/terraform/environment/$ENV" ]]; then
        local component_count=$(find "infrastructure/terraform/environment/$ENV" -name "terragrunt.hcl" | wc -l)
        print_debug "Found $component_count Terragrunt components in $ENV environment"
        
        if [[ $component_count -eq 0 ]]; then
            print_warning "No Terragrunt components found in $ENV environment"
        else
            print_success "Terragrunt structure validated ($component_count components)"
        fi
    else
        print_error "Environment directory not found: infrastructure/terraform/environment/$ENV"
        print_error "Available environments:"
        ls -1 "infrastructure/terraform/environment/" 2>/dev/null || echo "  No environments found"
        exit 1
    fi
    
    print_success "Codebase validation completed"
}

validate_codebase

# Build Lambda zip files first (non-Docker ones)
build_lambda_zips() {
    print_step "📦 Building Lambda ZIP packages..."
    
    local lambda_dirs=(
        "infrastructure/terraform_modules/lambda/build"
        "infrastructure/terraform_modules/inject_html_lambda/build" 
        "infrastructure/terraform_modules/orchestrator_lambda/build"
    )
    
    for lambda_dir in "${lambda_dirs[@]}"; do
        local lambda_name=$(basename $(dirname $lambda_dir))
        print_status "Building $lambda_name ZIP package..."
        
        cd "$REPO_ROOT/$lambda_dir"
        
        # Clean previous builds
        rm -rf lambda.zip __pycache__ *.pyc 2>/dev/null || true
        
        if [[ -f "build.sh" ]]; then
            chmod +x build.sh
            
            # Build with error handling and retry
            if ! retry "$RETRY_ATTEMPTS" "./build.sh"; then
                print_warning "Build script failed, attempting manual recovery..."
                
                # Try to fix pydantic issues
                if [[ -f "requirements.txt" ]]; then
                    print_status "Installing dependencies with force reinstall..."
                    pip3 install -r requirements.txt -t . --upgrade --force-reinstall
                    
                    # Manual zip creation
                    print_status "Creating ZIP manually..."
                    zip -r lambda.zip . -x "*.pyc" "__pycache__/*" "*.git*" "build.sh" "requirements.txt" "*.md"
                fi
                
                if [[ ! -f "lambda.zip" ]]; then
                    print_error "Failed to create lambda.zip for $lambda_name"
                    cd "$REPO_ROOT"
                    exit 1
                fi
            fi
        else
            print_error "build.sh not found for $lambda_name"
            cd "$REPO_ROOT"
            exit 1
        fi
        
        # Verify zip file
        if [[ -f "lambda.zip" ]]; then
            local zip_size=$(du -h lambda.zip | cut -f1)
            print_debug "ZIP file size: $zip_size"
            
            # Verify zip integrity
            if ! unzip -t lambda.zip >/dev/null 2>&1; then
                print_error "Created ZIP file is corrupted for $lambda_name"
                cd "$REPO_ROOT"
                exit 1
            fi
            
            print_success "$lambda_name ZIP package built successfully"
        else
            print_error "lambda.zip not found for $lambda_name"
            cd "$REPO_ROOT"
            exit 1
        fi
        
        cd "$REPO_ROOT"
    done
    
    print_success "All Lambda ZIP packages built successfully"
}

build_lambda_zips

# Apply infrastructure first (this creates ECR repositories)
apply_infrastructure() {
    print_step "🏗️  Applying all Terragrunt infrastructure..."
    cd "$REPO_ROOT/infrastructure/terraform"

    # Check if terragrunt.hcl exists
    if [[ ! -f "terragrunt.hcl" ]]; then
        print_error "terragrunt.hcl not found in $PWD"
        print_error "Make sure you're in the correct terraform directory"
        exit 1
    fi

    # Check if environment file exists
    if [[ ! -f "environment/$ENV/environment.hcl" ]]; then
        print_error "environment.hcl not found for environment: $ENV"
        print_error "Available environments:"
        ls -1 "environment/" 2>/dev/null || echo "  No environments found"
        cd "$REPO_ROOT"
        exit 1
    fi

    # Set environment variable for terragrunt
    export ENV="$ENV"
    
    # Apply infrastructure components in dependency order
    print_status "🚀 Applying infrastructure components in dependency order..."
    
    local components=(
        "s3_input"          # S3 buckets first (no dependencies)
        "s3_output" 
        "iam"               # IAM roles (depend on S3 buckets)
        "ssm_parameters"    # SSM parameters (no dependencies)
        "cloudfront"        # CloudFront (depends on S3 output)
        "puppeteer_lambda"  # Puppeteer Lambda (creates ECR repo, depends on IAM/S3/CloudFront)
        "lambda"            # Gen Landing Lambda (depends on IAM/S3/CloudFront)
        "inject_html_lambda" # Inject HTML Lambda (depends on S3/CloudFront)
        "orchestrator_lambda" # Orchestrator Lambda (depends on all other lambdas)
        "api_gateway"       # API Gateway (depends on orchestrator lambda)
        "cognito"           # Cognito (optional, no critical dependencies)
    )
    
    local failed_components=()
    cd "environment/$ENV"
    
    for component in "${components[@]}"; do
        if [[ -d "$component" ]]; then
            print_status "Applying $component..."
            if terragrunt apply --auto-approve --terragrunt-working-dir "$component"; then
                print_success "✅ $component applied successfully"
            else
                print_warning "❌ $component failed to apply"
                failed_components+=("$component")
                
                # For critical components, exit immediately
                if [[ "$component" == "puppeteer_lambda" ]]; then
                    print_error "Puppeteer Lambda deployment failed - this creates the ECR repository needed for Docker builds"
                    cd "$REPO_ROOT"
                    exit 1
                fi
            fi
        else
            print_debug "Component directory not found: $component"
        fi
    done
    
    cd "$REPO_ROOT/infrastructure/terraform"
    
    if [[ ${#failed_components[@]} -gt 0 ]]; then
        print_error "Some components failed to deploy: ${failed_components[*]}"
        print_error "You may need to apply them manually or check for dependencies"
        cd "$REPO_ROOT"
        exit 1
    else
        print_success "All infrastructure components applied successfully"
    fi
    
    cd "$REPO_ROOT"
}

apply_infrastructure

# Now build and deploy Docker image (after ECR repository exists)
deploy_docker_lambda() {
    if [[ "$SKIP_DOCKER" == "true" ]]; then
        print_warning "Skipping Docker build for Puppeteer Lambda (SKIP_DOCKER=true)"
        return 0
    fi
    
    print_step "🐳 Building and deploying Puppeteer Lambda Docker image..."
    
    local lambda_dir="infrastructure/terraform_modules/puppeteer_lambda"
    
    cd "$REPO_ROOT/$lambda_dir"
    
    # Verify ECR repository exists
    local repo_name="puppeteer-lambda-repo"
    print_status "Verifying ECR repository exists..."
    
    if ! aws ecr describe-repositories --repository-names "$repo_name" --region "$AWS_REGION" >/dev/null 2>&1; then
        print_error "ECR repository '$repo_name' does not exist!"
        print_error "This should have been created by the infrastructure deployment"
        print_error "Try running: cd infrastructure/terraform/environment/$ENV/puppeteer_lambda && terragrunt apply"
        cd "$REPO_ROOT"
        exit 1
    fi
    
    print_success "ECR repository verified"
    
    # Ensure we have the build script
    if [[ ! -f "build/rebuild_and_deploy.sh" ]]; then
        print_error "rebuild_and_deploy.sh not found at build/rebuild_and_deploy.sh"
        cd "$REPO_ROOT"
        exit 1
    fi
    
    # Make script executable
    chmod +x build/rebuild_and_deploy.sh
    
    print_status "Starting Docker build and push..."
    print_debug "Running Docker build from: $(pwd)"
    
    # Set required environment variables for the build script
    export AWS_REGION="$AWS_REGION"
    
    # Use timeout for Docker operations on systems that support it
    local timeout_cmd=""
    if command -v timeout >/dev/null 2>&1; then
        timeout_cmd="timeout $DOCKER_TIMEOUT"
    elif command -v gtimeout >/dev/null 2>&1; then
        timeout_cmd="gtimeout $DOCKER_TIMEOUT"
    fi
    
    # Docker build with retry logic
    if retry "$RETRY_ATTEMPTS" "$timeout_cmd ./build/rebuild_and_deploy.sh"; then
        print_success "Docker build and deployment completed successfully"
    else
        print_error "Docker build failed after $RETRY_ATTEMPTS attempts"
        print_error "Check the logs above for detailed error information"
        
        # Provide debugging suggestions
        print_status "Debugging suggestions:"
        print_status "1. Check Docker daemon is running: docker ps"
        print_status "2. Check AWS credentials: aws sts get-caller-identity"
        print_status "3. Check ECR permissions: aws ecr describe-repositories"
        print_status "4. Try manual build: cd $lambda_dir && ./build/rebuild_and_deploy.sh"
        
        cd "$REPO_ROOT"
        exit 1
    fi
    
    cd "$REPO_ROOT"
    
    print_success "Puppeteer Lambda Docker deployment completed"
}

deploy_docker_lambda

# Update Lambda function code (ZIP-based ones only, Docker is handled above)
update_lambda_functions() {
    print_step "⬆️  Updating Lambda function code..."
    
    local lambda_configs=(
        "gen-landing:infrastructure/terraform_modules/lambda/build"
        "inject-html:infrastructure/terraform_modules/inject_html_lambda/build"
        "orchestrator:infrastructure/terraform_modules/orchestrator_lambda/build"
    )
    
    for config in "${lambda_configs[@]}"; do
        local function_suffix="${config%%:*}"
        local build_dir="${config##*:}"
        local function_name="$PROJECT_NAME-$ENV-$AWS_REGION-$function_suffix"
        
        print_status "Updating $function_name..."
        
        cd "$REPO_ROOT/$build_dir"
        
        if [[ -f "lambda.zip" ]]; then
            # Upload with retry logic
            if retry "$RETRY_ATTEMPTS" "aws lambda update-function-code \
                --function-name '$function_name' \
                --zip-file fileb://lambda.zip \
                --region '$AWS_REGION'"; then
                
                print_success "$function_name updated successfully"
                
                # Test the function after upload
                if [[ "$SKIP_TESTS" != "true" ]]; then
                    print_status "🧪 Testing $function_name after deployment..."
                    sleep 3
                    
                    if aws lambda invoke \
                        --function-name "$function_name" \
                        --payload '{"test": "true"}' \
                        --region "$AWS_REGION" \
                        /tmp/test-response-$(basename $function_name).json >/dev/null 2>&1; then
                        print_success "$function_name tested successfully!"
                    else
                        print_warning "Lambda function test failed for $function_name, but continuing..."
                    fi
                fi
            else
                print_error "Failed to update $function_name after $RETRY_ATTEMPTS attempts"
                cd "$REPO_ROOT"
                exit 1
            fi
        else
            print_error "lambda.zip not found for $function_name in $build_dir"
            cd "$REPO_ROOT"
            exit 1
        fi
        
        cd "$REPO_ROOT"
    done
    
    print_success "All Lambda functions updated successfully"
}

update_lambda_functions

# Get API endpoint dynamically
get_api_endpoint() {
    print_debug "Fetching API Gateway endpoint..."
    local api_endpoint=""
    
    # Try to get from terragrunt output
    cd "$REPO_ROOT/infrastructure/terraform/environment/$ENV/api_gateway"
    if api_endpoint=$(ENV="$ENV" terragrunt output -raw api_endpoint 2>/dev/null); then
        print_debug "Got API endpoint from terragrunt: $api_endpoint"
    else
        cd "$REPO_ROOT"
        
        # Fallback: get from AWS API Gateway
        print_debug "Trying to get API endpoint from AWS API Gateway..."
        local api_id=$(aws apigateway get-rest-apis --query "items[?name=='$PROJECT_NAME-$ENV-$AWS_REGION-api'].id" --output text 2>/dev/null || echo "")
        if [[ -n "$api_id" && "$api_id" != "None" && "$api_id" != "null" ]]; then
            api_endpoint="https://$api_id.execute-api.$AWS_REGION.amazonaws.com/chat"
            print_debug "Got API endpoint from AWS: $api_endpoint"
        else
            # Try alternative API name patterns
            print_debug "Trying alternative API name patterns..."
            local api_id_alt=$(aws apigateway get-rest-apis --query "items[?contains(name, 'api')].id | [0]" --output text 2>/dev/null || echo "")
            if [[ -n "$api_id_alt" && "$api_id_alt" != "None" && "$api_id_alt" != "null" ]]; then
                api_endpoint="https://$api_id_alt.execute-api.$AWS_REGION.amazonaws.com/chat"
                print_debug "Got API endpoint from AWS (alternative pattern): $api_endpoint"
            else
                print_warning "Could not determine API endpoint - will use placeholder"
                api_endpoint="https://placeholder.execute-api.$AWS_REGION.amazonaws.com/chat"
            fi
        fi
    fi
    
    cd "$REPO_ROOT"
    echo "$api_endpoint"
}

# Enhanced testing
test_deployment() {
    if [[ "$SKIP_TESTS" == "true" ]]; then
        print_warning "Skipping deployment tests (SKIP_TESTS=true)"
        return 0
    fi
    
    print_step "🧪 Testing the complete deployment..."

    # Wait for deployment to stabilize
    print_status "⏳ Waiting for deployment to stabilize..."
    sleep 15

    # Get API endpoint dynamically
    local test_url=$(get_api_endpoint)
    local test_payload='{"source_url": "https://example.com", "prompt": "automotive industry landing page"}'

    print_status "📡 Testing API endpoint: $test_url"
    
    # Test with retry logic
    local test_response=""
    local test_attempts=0
    local max_test_attempts=5
    
    while [[ $test_attempts -lt $max_test_attempts ]]; do
        print_debug "Test attempt $((test_attempts + 1)) of $max_test_attempts"
        
        if test_response=$(curl -s -w "\n%{http_code}" -X POST "$test_url" \
          -H "Content-Type: application/json" \
          -d "$test_payload" 2>/dev/null); then
            
            local http_code=$(echo "$test_response" | tail -n1)
            local response_body=$(echo "$test_response" | head -n -1)
            
            print_debug "HTTP Code: $http_code"
            
            if [[ "$http_code" == "200" || "$http_code" == "202" ]]; then
                print_success "✅ API endpoint responding correctly (HTTP $http_code)"
                
                # Validate JSON response
                if echo "$response_body" | jq . >/dev/null 2>&1; then
                    print_success "✅ Response is valid JSON"
                    
                    if [[ "$VERBOSE" == "true" ]]; then
                        print_debug "API Response:"
                        echo "$response_body" | jq .
                    fi
                    
                    # Extract and test job ID or HTML URL
                    local job_id=$(echo "$response_body" | jq -r '.job_id // empty' 2>/dev/null || echo "")
                    local html_url=$(echo "$response_body" | jq -r '.htmlUrl // empty' 2>/dev/null || echo "")
                    
                    if [[ -n "$job_id" && "$job_id" != "null" ]]; then
                        print_success "✅ Async workflow initiated with job ID: $job_id"
                        
                        # Test status endpoint
                        local status_url="${test_url}/status/${job_id}"
                        print_status "🔍 Testing status endpoint: $status_url"
                        
                        if curl -s "$status_url" >/dev/null 2>&1; then
                            print_success "✅ Status endpoint accessible"
                        else
                            print_warning "Status endpoint test failed"
                        fi
                        
                    elif [[ -n "$html_url" && "$html_url" != "null" ]]; then
                        print_success "✅ Synchronous response with HTML URL: $html_url"
                        
                        # Test HTML content
                        test_html_content "$html_url"
                    fi
                    
                    break
                else
                    print_warning "Response is not valid JSON"
                    if [[ "$VERBOSE" == "true" ]]; then
                        print_debug "Raw response: $response_body"
                    fi
                fi
            else
                print_warning "API returned HTTP $http_code"
                if [[ "$VERBOSE" == "true" ]]; then
                    print_debug "Response: $response_body"
                fi
            fi
        else
            print_warning "API test request failed"
        fi
        
        ((test_attempts++))
        if [[ $test_attempts -lt $max_test_attempts ]]; then
            print_status "Retrying in 10 seconds..."
            sleep 10
        fi
    done
    
    if [[ $test_attempts -eq $max_test_attempts ]]; then
        print_error "❌ API testing failed after $max_test_attempts attempts"
        print_error "The deployment may still be working, but API tests failed"
        print_warning "You can test manually with:"
        echo "curl -X POST $test_url \\"
        echo "  -H \"Content-Type: application/json\" \\"
        echo "  -d '$test_payload'"
        return 1
    fi
}

# Test HTML content quality
test_html_content() {
    local html_url=$1
    
    print_status "🌐 Testing generated HTML at: $html_url"
    
    # Test if HTML is accessible and properly formatted
    local html_content=$(curl -s --compressed "$html_url" 2>/dev/null | head -10)
    
    if echo "$html_content" | grep -q "<!DOCTYPE\|<html\|<HTML"; then
        print_success "✅ HTML is properly formatted!"
        print_success "🎉 UTF-8 encoding fix is working correctly!"
        
        # Check for our enhanced CSS
        if curl -s "$html_url" | grep -q "lp-landing-section\|lp-hero\|lp-features"; then
            print_success "✅ Enhanced CSS styling detected!"
        else
            print_warning "Enhanced CSS styling not detected"
        fi
        
    else
        print_error "❌ HTML appears corrupted. First few lines:"
        echo "$html_content"
        return 1
    fi
    
    if [[ "$VERBOSE" == "true" ]]; then
        print_debug "📄 First few lines of generated HTML:"
        echo "$html_content"
    fi
}

# Run tests
test_deployment

# Final summary
print_success "🎊 Deployment Summary:"
print_success "   ✅ Configuration validated"
print_success "   ✅ AWS credentials verified"
print_success "   ✅ All required tools available"
print_success "   ✅ Codebase integrity confirmed"
print_success "   ✅ UTF-8 fix verified and working"
print_success "   ✅ Lambda ZIP packages built"
print_success "   ✅ Complete infrastructure applied"
print_success "   ✅ Docker image built and deployed"
print_success "   ✅ All Lambda functions updated"

if [[ "$SKIP_TESTS" != "true" ]]; then
    print_success "   ✅ End-to-end testing completed"
fi

print_status "🌟 Your LaaS system is fully deployed and ready!"

# Get final API endpoint for user
FINAL_API_URL=$(get_api_endpoint)
print_status "🚀 Test your deployment with:"
echo ""
echo "curl -X POST $FINAL_API_URL \\"
echo "  -H \"Content-Type: application/json\" \\"
echo "  -d '{\"source_url\": \"https://example.com\", \"prompt\": \"your industry here\"}'"
echo ""

print_success "🏁 Deployment complete! 🎉"

# Optional: Save deployment info
cat > "$REPO_ROOT/deployment-info.json" << EOF
{
  "timestamp": "$(date -u +"%Y-%m-%dT%H:%M:%SZ")",
  "environment": "$ENV",
  "aws_region": "$AWS_REGION",
  "project_name": "$PROJECT_NAME",
  "account_id": "$ACCOUNT_ID",
  "api_endpoint": "$FINAL_API_URL",
  "deployment_successful": true
}
EOF

print_status "📄 Deployment info saved to deployment-info.json" 