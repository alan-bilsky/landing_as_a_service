"""Tests for gen_landing Lambda function (Bedrock integration)."""

import pytest
import json
from unittest.mock import patch, MagicMock


class TestGenLandingLambda:
    """Test the gen_landing Lambda handler."""

    @pytest.fixture(autouse=True)
    def setup_environment(self, monkeypatch):
        """Set up environment variables for testing."""
        monkeypatch.setenv("BEDROCK_REGION", "us-west-2")
        monkeypatch.setenv("BEDROCK_MODEL_ID", "anthropic.claude-3-sonnet-20240229-v1:0")

    def test_ssm_parameter_retrieval(self, ssm_client, ssm_parameters):
        """Test that SSM parameters are properly retrieved."""
        with patch('boto3.client') as mock_boto3:
            mock_boto3.return_value = ssm_client
            
            import sys
            sys.path.append('infrastructure/terraform_modules/lambda/build')
            from handler import get_ssm_parameter
            
            result = get_ssm_parameter("/laas/bedrock/prompt")
            assert result == "Industry: {industry}{theme_context}"

    def test_bedrock_retry_logic(self, lambda_context):
        """Test Bedrock retry logic with exponential backoff."""
        with patch('boto3.client') as mock_boto3, \
             patch('time.sleep') as mock_sleep:
            
            mock_bedrock = MagicMock()
            mock_boto3.return_value = mock_bedrock
            
            # Simulate throttling then success
            mock_bedrock.invoke_model.side_effect = [
                Exception("ThrottlingException"),
                Exception("ThrottlingException"),
                {
                    'body': MagicMock(read=lambda: json.dumps({
                        'content': [{'text': json.dumps({
                            'hero_html': '<div class="lp-hero">Test</div>',
                            'features_html': '<div class="lp-features">Test</div>',
                            'cta_html': '<div class="lp-cta">Test</div>',
                            'img_prompts': ['test image']
                        })}]
                    }).encode())
                }
            ]
            
            import sys
            sys.path.append('infrastructure/terraform_modules/lambda/build')
            from handler import call_bedrock_with_retry
            
            result = call_bedrock_with_retry(
                mock_bedrock, 
                "test prompt", 
                "test system prompt"
            )
            
            # Should have retried twice then succeeded
            assert mock_bedrock.invoke_model.call_count == 3
            assert mock_sleep.call_count == 2  # Sleep between retries

    def test_prompt_formatting(self):
        """Test that prompts are properly formatted."""
        import sys
        sys.path.append('infrastructure/terraform_modules/lambda/build')
        from handler import format_prompt
        
        template = "Industry: {industry}\nTheme: {theme_context}"
        theme_info = {
            "fonts": ["Arial"],
            "color_palette": ["#333"]
        }
        
        result = format_prompt(template, "technology", theme_info)
        expected = "Industry: technology\nTheme: Fonts: Arial, sans-serif\nColors: #333"
        
        assert "Industry: technology" in result
        assert "Arial" in result

    def test_json_response_parsing(self):
        """Test parsing of Bedrock JSON responses."""
        import sys
        sys.path.append('infrastructure/terraform_modules/lambda/build')
        from handler import parse_bedrock_response
        
        mock_response = {
            'body': MagicMock(read=lambda: json.dumps({
                'content': [{'text': json.dumps({
                    'hero_html': '<div class="lp-hero">Test Hero</div>',
                    'features_html': '<div class="lp-features">Test Features</div>',
                    'cta_html': '<div class="lp-cta">Test CTA</div>',
                    'img_prompts': ['modern office', 'team meeting']
                })}]
            }).encode())
        }
        
        result = parse_bedrock_response(mock_response)
        
        assert result['hero_html'] == '<div class="lp-hero">Test Hero</div>'
        assert result['features_html'] == '<div class="lp-features">Test Features</div>'
        assert result['cta_html'] == '<div class="lp-cta">Test CTA</div>'
        assert len(result['img_prompts']) == 2

    def test_timeout_handling(self, lambda_context):
        """Test that 5-second timeout is properly enforced."""
        with patch('boto3.client') as mock_boto3, \
             patch('signal.alarm') as mock_alarm:
            
            mock_bedrock = MagicMock()
            mock_boto3.return_value = mock_bedrock
            
            import sys
            sys.path.append('infrastructure/terraform_modules/lambda/build')
            from handler import call_bedrock_with_retry
            
            # Call the function (timeout setup would be tested)
            try:
                call_bedrock_with_retry(
                    mock_bedrock, 
                    "test prompt", 
                    "test system prompt"
                )
            except:
                pass  # Expected for incomplete mock
            
            # Verify timeout was set
            mock_alarm.assert_called_with(5)

    def test_lp_prefix_enforcement(self):
        """Test that lp- prefixes are properly enforced in generated content."""
        import sys
        sys.path.append('infrastructure/terraform_modules/lambda/build')
        from handler import enforce_lp_prefixes
        
        test_content = {
            'hero_html': '<div class="hero"><h1 class="title">Test</h1></div>',
            'features_html': '<div class="features"><p class="feature">Test</p></div>',
            'cta_html': '<div class="cta"><button class="btn">Test</button></div>'
        }
        
        result = enforce_lp_prefixes(test_content)
        
        assert 'class="lp-hero"' in result['hero_html']
        assert 'class="lp-title"' in result['hero_html']
        assert 'class="lp-features"' in result['features_html']
        assert 'class="lp-btn"' in result['cta_html'] 