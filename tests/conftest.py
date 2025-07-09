"""Pytest configuration and shared fixtures for LaaS testing."""

import pytest
import boto3
import json
import os
from moto import mock_s3, mock_lambda, mock_ssm, mock_cloudfront
# Note: mock_bedrock is not available in moto yet
from moto.core import DEFAULT_ACCOUNT_ID as ACCOUNT_ID


@pytest.fixture
def aws_credentials():
    """Mocked AWS Credentials for moto."""
    os.environ['AWS_ACCESS_KEY_ID'] = 'testing'
    os.environ['AWS_SECRET_ACCESS_KEY'] = 'testing'
    os.environ['AWS_SECURITY_TOKEN'] = 'testing'
    os.environ['AWS_SESSION_TOKEN'] = 'testing'
    os.environ['AWS_DEFAULT_REGION'] = 'us-west-2'


@pytest.fixture
def s3_client(aws_credentials):
    """Mocked S3 client."""
    with mock_s3():
        yield boto3.client('s3', region_name='us-west-2')


@pytest.fixture
def ssm_client(aws_credentials):
    """Mocked SSM client."""
    with mock_ssm():
        yield boto3.client('ssm', region_name='us-west-2')


@pytest.fixture
def lambda_client(aws_credentials):
    """Mocked Lambda client."""
    with mock_lambda():
        yield boto3.client('lambda', region_name='us-west-2')


@pytest.fixture
def cloudfront_client(aws_credentials):
    """Mocked CloudFront client."""
    with mock_cloudfront():
        yield boto3.client('cloudfront', region_name='us-west-2')


@pytest.fixture
def test_bucket(s3_client):
    """Create a test S3 bucket."""
    bucket_name = "test-laas-bucket"
    s3_client.create_bucket(
        Bucket=bucket_name,
        CreateBucketConfiguration={'LocationConstraint': 'us-west-2'}
    )
    return bucket_name


@pytest.fixture
def ssm_parameters(ssm_client):
    """Create test SSM parameters."""
    ssm_client.put_parameter(
        Name="/laas/bedrock/prompt",
        Value="Industry: {industry}{theme_context}",
        Type="String"
    )
    ssm_client.put_parameter(
        Name="/laas/bedrock/system_prompt", 
        Value="You are a landing page copywriter. Respond with JSON containing hero_html, features_html, cta_html, img_prompts fields. Use lp- CSS prefixes.",
        Type="String"
    )
    return {
        "prompt": "/laas/bedrock/prompt",
        "system_prompt": "/laas/bedrock/system_prompt"
    }


@pytest.fixture
def sample_html():
    """Sample HTML for testing."""
    return """
    <!DOCTYPE html>
    <html>
    <head>
        <title>Test Site</title>
        <style>.test { color: blue; }</style>
    </head>
    <body>
        <header>
            <h1>Test Header</h1>
        </header>
        <main>
            <p>Test content</p>
        </main>
    </body>
    </html>
    """


@pytest.fixture
def sample_theme_info():
    """Sample theme information."""
    return {
        "fonts": ["Arial, sans-serif"],
        "color_palette": ["#333333", "#ffffff"],
        "logo_url": "https://example.com/logo.png",
        "layout_hints": {
            "has_header": True,
            "has_nav": False,
            "has_main": True,
            "has_footer": False
        }
    }


@pytest.fixture
def sample_landing_content():
    """Sample landing page content."""
    return {
        "hero_html": '<div class="lp-hero"><h1>Test Hero</h1></div>',
        "features_html": '<div class="lp-features"><p>Test Features</p></div>',
        "cta_html": '<div class="lp-cta"><button class="lp-btn">Test CTA</button></div>',
        "img_prompts": ["modern office space", "professional team meeting"]
    }


@pytest.fixture
def api_gateway_event():
    """Sample API Gateway event."""
    return {
        "body": json.dumps({
            "source_url": "https://example.com",
            "prompt": "technology startup"
        }),
        "headers": {
            "Content-Type": "application/json"
        },
        "httpMethod": "POST",
        "path": "/chat",
        "isBase64Encoded": False
    }


@pytest.fixture
def lambda_context():
    """Mock Lambda context."""
    class MockContext:
        def __init__(self):
            self.function_name = "test-function"
            self.function_version = "$LATEST"
            self.invoked_function_arn = f"arn:aws:lambda:us-west-2:{ACCOUNT_ID}:function:test-function"
            self.memory_limit_in_mb = 128
            self.remaining_time_in_millis = lambda: 300000
            self.aws_request_id = "test-request-id"
            self.log_group_name = "/aws/lambda/test-function"
            self.log_stream_name = "test-stream"
    
    return MockContext() 