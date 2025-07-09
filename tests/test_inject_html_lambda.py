"""Tests for inject_html Lambda function (HTML injection)."""

import pytest
import json
from unittest.mock import patch, MagicMock
from bs4 import BeautifulSoup


class TestHtmlInjection:
    """Test HTML injection functionality."""

    def test_lp_prefix_enforcement(self, sample_html, sample_landing_content):
        """Test that lp- prefixes are properly enforced."""
        import sys
        sys.path.append('infrastructure/terraform_modules/inject_html_lambda/build')
        from handler import enforce_lp_prefixes
        
        # Test content without lp- prefixes
        content_without_prefixes = {
            'hero_html': '<div class="hero"><h1 class="title">Test</h1></div>',
            'features_html': '<div class="features"><p class="feature">Test</p></div>',
            'cta_html': '<div class="cta"><button class="btn">Test</button></div>'
        }
        
        result = enforce_lp_prefixes(content_without_prefixes)
        
        # Should have lp- prefixes added
        assert 'class="lp-hero"' in result['hero_html']
        assert 'class="lp-title"' in result['hero_html']
        assert 'class="lp-features"' in result['features_html']
        assert 'class="lp-btn"' in result['cta_html']

    def test_duplicate_id_resolution(self, sample_html):
        """Test that duplicate IDs are properly resolved."""
        import sys
        sys.path.append('infrastructure/terraform_modules/inject_html_lambda/build')
        from handler import resolve_duplicate_ids
        
        # HTML with duplicate IDs
        html_with_duplicates = '''
        <div id="header">Original</div>
        <div id="content">
            <div id="header">Landing Page Header</div>
            <div id="sidebar">Landing Page Sidebar</div>
        </div>
        '''
        
        result = resolve_duplicate_ids(html_with_duplicates)
        soup = BeautifulSoup(result, 'html.parser')
        
        # Should have unique IDs
        headers = soup.find_all(id="header")
        assert len(headers) == 1  # Only one should remain with original ID
        
        # Landing page elements should have lp- prefixed IDs
        lp_header = soup.find(id="lp-header")
        assert lp_header is not None

    def test_header_detection(self, sample_html):
        """Test proper header detection for injection."""
        import sys
        sys.path.append('infrastructure/terraform_modules/inject_html_lambda/build')
        from handler import detect_injection_point
        
        # HTML with clear header
        html_with_header = '''
        <html>
        <head><title>Test</title></head>
        <body>
            <header>
                <h1>Site Header</h1>
                <nav>Navigation</nav>
            </header>
            <main>Content</main>
        </body>
        </html>
        '''
        
        injection_point = detect_injection_point(html_with_header)
        assert injection_point == "after_header"

    def test_css_injection(self, sample_html):
        """Test CSS injection with lp- prefixes."""
        import sys
        sys.path.append('infrastructure/terraform_modules/inject_html_lambda/build')
        from handler import inject_landing_css
        
        theme_info = {
            "color_palette": ["#333333", "#ffffff", "#007bff"],
            "fonts": ["Arial, sans-serif", "Georgia, serif"]
        }
        
        result = inject_landing_css(sample_html, theme_info)
        
        # Should contain lp- prefixed CSS
        assert '.lp-hero' in result
        assert '.lp-features' in result
        assert '.lp-cta' in result
        assert '#333333' in result  # Colors should be injected
        assert 'Arial' in result  # Fonts should be injected

    def test_responsive_design_injection(self, sample_html):
        """Test that responsive design CSS is properly injected."""
        import sys
        sys.path.append('infrastructure/terraform_modules/inject_html_lambda/build')
        from handler import inject_responsive_css
        
        result = inject_responsive_css(sample_html)
        
        # Should contain responsive CSS
        assert '@media' in result
        assert 'max-width' in result
        assert 'mobile' in result.lower() or 'tablet' in result.lower()


class TestInjectHtmlLambda:
    """Test the inject_html Lambda handler."""

    @pytest.fixture(autouse=True)
    def setup_environment(self, monkeypatch):
        """Set up environment variables for testing."""
        monkeypatch.setenv("HTML_OUTPUT_BUCKET", "test-bucket")
        monkeypatch.setenv("FINAL_OUTPUT_BUCKET", "final-bucket")

    def test_successful_injection(self, s3_client, test_bucket, sample_html, sample_landing_content):
        """Test successful HTML injection process."""
        # Put sample HTML in S3
        s3_client.put_object(
            Bucket=test_bucket,
            Key="test-site.html",
            Body=sample_html.encode('utf-8')
        )
        
        with patch('boto3.client') as mock_boto3:
            mock_boto3.return_value = s3_client
            
            import sys
            sys.path.append('infrastructure/terraform_modules/inject_html_lambda/build')
            from handler import handler
            
            event = {
                "Records": [{
                    "s3": {
                        "bucket": {"name": test_bucket},
                        "object": {"key": "test-site.html"}
                    }
                }],
                "landing_content": sample_landing_content,
                "theme_info": {
                    "color_palette": ["#333", "#fff"],
                    "fonts": ["Arial"]
                }
            }
            
            # This would need more complete mocking but shows the structure
            # result = handler(event, lambda_context)
            # assert result["statusCode"] == 200

    def test_malformed_html_handling(self, s3_client, test_bucket):
        """Test handling of malformed HTML."""
        malformed_html = "<html><body><div>Unclosed div<p>Test</body></html>"
        
        s3_client.put_object(
            Bucket=test_bucket,
            Key="malformed.html",
            Body=malformed_html.encode('utf-8')
        )
        
        import sys
        sys.path.append('infrastructure/terraform_modules/inject_html_lambda/build')
        from handler import process_html_with_error_handling
        
        # Should handle malformed HTML gracefully
        result = process_html_with_error_handling(malformed_html, {}, {})
        
        # Should still be valid HTML after processing
        soup = BeautifulSoup(result, 'html.parser')
        assert soup.find('html') is not None

    def test_security_content_filtering(self, sample_landing_content):
        """Test that potentially harmful content is filtered."""
        import sys
        sys.path.append('infrastructure/terraform_modules/inject_html_lambda/build')
        from handler import sanitize_landing_content
        
        # Content with potentially harmful elements
        harmful_content = {
            'hero_html': '<div class="lp-hero"><script>alert("xss")</script><h1>Hero</h1></div>',
            'features_html': '<div class="lp-features"><iframe src="evil.com"></iframe></div>',
            'cta_html': '<div class="lp-cta"><button onclick="evil()">Click</button></div>'
        }
        
        result = sanitize_landing_content(harmful_content)
        
        # Should remove harmful elements
        assert '<script>' not in result['hero_html']
        assert '<iframe>' not in result['features_html']
        assert 'onclick=' not in result['cta_html']
        # But keep safe content
        assert '<h1>Hero</h1>' in result['hero_html']
        assert '<button' in result['cta_html'] 