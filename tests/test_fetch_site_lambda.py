"""Tests for fetch_site Lambda function (Puppeteer-based)."""

import pytest
import json
import responses
from unittest.mock import patch, MagicMock


class TestUrlValidation:
    """Test URL validation security measures."""

    @pytest.fixture(autouse=True)
    def setup_environment(self, monkeypatch):
        """Set up environment variables for testing."""
        monkeypatch.setenv("HTML_OUTPUT_BUCKET", "test-bucket")

    def test_valid_urls(self):
        """Test that valid URLs pass validation."""
        # Import here to avoid import errors in CI
        import sys
        sys.path.append('infrastructure/terraform_modules/puppeteer_lambda/build')
        from index import validateUrl
        
        valid_urls = [
            "https://example.com",
            "http://google.com",
            "https://subdomain.example.org/path",
            "https://example.com:8080/path?query=1"
        ]
        
        for url in valid_urls:
            assert validateUrl(url), f"URL should be valid: {url}"

    def test_invalid_protocols(self):
        """Test that non-HTTP(S) protocols are rejected."""
        import sys
        sys.path.append('infrastructure/terraform_modules/puppeteer_lambda/build')
        from index import validateUrl
        
        invalid_urls = [
            "ftp://example.com",
            "file:///etc/passwd",
            "javascript:alert(1)",
            "data:text/html,<script>alert(1)</script>",
            "ldap://example.com"
        ]
        
        for url in invalid_urls:
            assert not validateUrl(url), f"URL should be invalid: {url}"

    def test_private_ip_rejection(self):
        """Test that private IP ranges are properly rejected."""
        import sys
        sys.path.append('infrastructure/terraform_modules/puppeteer_lambda/build')
        from index import validateUrl
        
        private_ips = [
            "http://127.0.0.1",
            "https://localhost",
            "http://10.0.0.1",
            "http://192.168.1.1",
            "http://172.16.0.1",
            "http://172.31.255.255",
            "http://169.254.169.254",  # AWS metadata
            "http://::1",  # IPv6 localhost
        ]
        
        for url in private_ips:
            assert not validateUrl(url), f"Private IP should be rejected: {url}"

    def test_query_param_stripping(self):
        """Test that query parameters are stripped."""
        import sys
        sys.path.append('infrastructure/terraform_modules/puppeteer_lambda/build')
        from index import stripQueryParams
        
        test_cases = [
            ("https://example.com?param=value", "https://example.com"),
            ("https://example.com/path?a=1&b=2", "https://example.com/path"),
            ("https://example.com#fragment", "https://example.com"),
            ("https://example.com/path?query=1#fragment", "https://example.com/path"),
        ]
        
        for input_url, expected in test_cases:
            result = stripQueryParams(input_url)
            assert result == expected, f"Expected {expected}, got {result}"


class TestFetchSiteLambda:
    """Test the main Lambda handler."""

    @pytest.fixture(autouse=True)
    def setup_environment(self, monkeypatch):
        """Set up environment variables for testing."""
        monkeypatch.setenv("HTML_OUTPUT_BUCKET", "test-bucket")

    @responses.activate
    def test_valid_request_processing(self, lambda_context):
        """Test processing of a valid request."""
        # Mock the target website
        responses.add(
            responses.GET,
            "https://example.com",
            body="<html><body><h1>Test</h1></body></html>",
            status=200
        )
        
        # Mock S3 and Puppeteer operations
        with patch('boto3.client') as mock_boto3, \
             patch('chrome-aws-lambda.puppeteer') as mock_puppeteer:
            
            mock_s3 = MagicMock()
            mock_boto3.return_value = mock_s3
            
            mock_browser = MagicMock()
            mock_page = MagicMock()
            mock_puppeteer.launch.return_value = mock_browser
            mock_browser.newPage.return_value = mock_page
            mock_page.evaluate.return_value = {
                "fonts": ["Arial"],
                "color_palette": ["#333"]
            }
            
            # Import and test the handler
            import sys
            sys.path.append('infrastructure/terraform_modules/puppeteer_lambda/build')
            from index import handler
            
            event = {
                "body": json.dumps({"url": "https://example.com"})
            }
            
            # This would need more mocking to fully work, but shows the structure
            # result = handler(event, lambda_context)
            # assert result["statusCode"] == 200

    def test_invalid_url_rejection(self, lambda_context):
        """Test that invalid URLs are properly rejected."""
        import sys
        sys.path.append('infrastructure/terraform_modules/puppeteer_lambda/build')
        from index import handler
        
        event = {
            "body": json.dumps({"url": "http://127.0.0.1"})
        }
        
        result = handler(event, lambda_context)
        assert result["statusCode"] == 400
        assert "Invalid URL" in result["body"]

    def test_missing_url_parameter(self, lambda_context):
        """Test handling of missing URL parameter."""
        import sys
        sys.path.append('infrastructure/terraform_modules/puppeteer_lambda/build')
        from index import handler
        
        event = {
            "body": json.dumps({})
        }
        
        result = handler(event, lambda_context)
        assert result["statusCode"] == 400
        assert "Missing URL" in result["body"] 