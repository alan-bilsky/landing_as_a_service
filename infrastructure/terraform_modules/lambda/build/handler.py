"""Lambda handler for gen_landing - generates landing page content using AWS Bedrock."""

import json
import os
import random
import re
import time
import uuid
from typing import Dict, List, Optional, Tuple, Any

import boto3
import requests
from aws_lambda_powertools import Logger, Tracer, Metrics
from aws_lambda_powertools.utilities.typing import LambdaContext
from bs4 import BeautifulSoup, Tag
# No longer using pydantic validation

from models import (
    BedrockPayload,
    BedrockResponse,
    GenerationRequest,
    GenerationResponse,
    LandingContent,
    SSMPrompts,
    ThemeInfo,
)

# Initialize Powertools
logger = Logger()
tracer = Tracer()
metrics = Metrics()

# Environment variables
BEDROCK_REGION: str = os.environ.get("BEDROCK_REGION", "us-west-2")

# AWS clients
s3_client = boto3.client("s3")
bedrock_runtime = boto3.client("bedrock-runtime", region_name=BEDROCK_REGION)
ssm_client = boto3.client("ssm")

# CORS headers
CORS_HEADERS: Dict[str, str] = {
    "Access-Control-Allow-Origin": "*",
    "Access-Control-Allow-Headers": "Content-Type,Authorization",
    "Access-Control-Allow-Methods": "OPTIONS,POST",
}

# Constants
MAX_RETRIES: int = 3
BASE_DELAY: float = 1.0
MAX_TOTAL_TIME: int = 120
REQUEST_TIMEOUT: int = 5


class BedrockError(Exception):
    """Custom exception for Bedrock-related errors."""
    pass


class SSMError(Exception):
    """Custom exception for SSM-related errors."""
    pass


class LandingValidationError(Exception):
    """Custom exception for validation errors."""
    pass


@tracer.capture_method
def invoke_bedrock_with_retry(
    bedrock_runtime_client: Any,
    llm_model_id: str,
    payload: BedrockPayload,
    max_retries: int = MAX_RETRIES,
    base_delay: float = BASE_DELAY,
    max_total_time: int = MAX_TOTAL_TIME,
) -> Dict[str, Any]:
    """
    Invoke Bedrock with exponential backoff retry and timeout per request.
    
    Args:
        bedrock_runtime_client: Boto3 bedrock-runtime client
        llm_model_id: The Bedrock model ID to use
        payload: Validated payload for Bedrock
        max_retries: Maximum number of retry attempts
        base_delay: Base delay for exponential backoff
        max_total_time: Maximum total time for all attempts
    
    Returns:
        Bedrock response dictionary
    
    Raises:
        BedrockError: If Bedrock invocation fails
        TimeoutError: If operation exceeds time limits
    """
    start_time = time.time()
    
    for attempt in range(max_retries + 1):
        # Check if we're approaching the total time limit
        elapsed_time = time.time() - start_time
        if elapsed_time >= max_total_time:
            raise TimeoutError(f"Bedrock invocation exceeded maximum total time of {max_total_time}s")
        
        try:
            logger.info(f"Bedrock invocation attempt {attempt + 1}/{max_retries + 1}")
            
            # Convert dataclass to dict for JSON serialization
            payload_dict = vars(payload)
            
            response = bedrock_runtime_client.invoke_model(
                modelId=llm_model_id,
                body=json.dumps(payload_dict),
                contentType="application/json",
                accept="application/json",
            )
            
            return response
            
        except Exception as e:
            error_message = str(e)
            logger.warning(f"Bedrock attempt {attempt + 1} failed: {error_message}")
            
            # Don't retry on the last attempt
            if attempt == max_retries:
                raise BedrockError(f"Bedrock invocation failed after {max_retries + 1} attempts: {error_message}")
            
            # Check if we have time for another retry
            elapsed_time = time.time() - start_time
            if elapsed_time >= max_total_time - 10:  # Leave 10s buffer for the next attempt
                raise TimeoutError(f"Not enough time remaining for retry. Elapsed: {elapsed_time}s")
            
            # Exponential backoff with jitter
            delay = base_delay * (2 ** attempt) + random.uniform(0, 1)
            delay = min(delay, 30)  # Cap at 30 seconds
            
            logger.info(f"Retrying Bedrock call in {delay:.2f} seconds...")
            time.sleep(delay)
    
    raise BedrockError("Maximum retry attempts exceeded")


@tracer.capture_method
def get_prompts_from_ssm() -> SSMPrompts:
    """
    Retrieve Bedrock prompts from SSM parameters.
    
    Returns:
        SSMPrompts model with validated system and user prompts
    
    Raises:
        SSMError: If SSM parameter retrieval fails
    """
    try:
        # Get system prompt from SSM
        system_prompt_response = ssm_client.get_parameter(
            Name="/laas/bedrock/system_prompt"
        )
        system_prompt = system_prompt_response['Parameter']['Value']
        
        # Get prompt template from SSM  
        prompt_template_response = ssm_client.get_parameter(
            Name="/laas/bedrock/prompt"
        )
        prompt_template = prompt_template_response['Parameter']['Value']
        
        return SSMPrompts(
            system_prompt=system_prompt,
            prompt_template=prompt_template
        )
        
    except Exception as e:
        logger.warning(f"Failed to get prompts from SSM, using defaults: {e}")
        # Fallback to hardcoded prompts
        system_prompt = (
            "You are an expert landing page copywriter and visual content specialist. Given a business or industry description, "
            "respond ONLY with a valid JSON object with the following fields: "
            "'hero_html' (hero section HTML), 'features_html' (features section HTML), "
            "'cta_html' (call to action HTML), and 'img_prompts' (array of exactly 4 industry-specific Unsplash-style image descriptions). "
            "The HTML should be semantic and use the 'lp-' prefix for CSS classes. "
            "For img_prompts, create vivid, industry-specific descriptions that will yield high-quality, relevant images for the specified industry. "
            "Each image prompt should be detailed and professional, avoiding generic stock photo descriptions. "
            "Do not include any explanation, markdown, or text outside the JSON object."
        )
        prompt_template = (
            "Industry: {industry}{theme_context}\n\n"
            "For images, generate 4 industry-specific Unsplash-style prompts that are highly relevant to the {industry} industry. "
            "The prompts should be:\n"
            "1. A hero background image that captures the essence of {industry}\n"
            "2. A feature image showcasing {industry} technology or processes\n"
            "3. A call-to-action image that motivates {industry} professionals\n"
            "4. A secondary feature image highlighting {industry} benefits or outcomes\n\n"
            "Make each image prompt specific, professional, and visually compelling for the {industry} sector."
        )
        
        return SSMPrompts(
            system_prompt=system_prompt,
            prompt_template=prompt_template
        )


@tracer.capture_method
def build_theme_context(theme_info: ThemeInfo) -> str:
    """
    Build theme context string from theme information.
    
    Args:
        theme_info: Validated theme information
    
    Returns:
        Formatted theme context string
    """
    theme_context = ""
    
    if theme_info.fonts:
        theme_context += f" Use fonts: {', '.join(theme_info.fonts)}. "
    
    if theme_info.color_palette:
        theme_context += f" Use colors: {', '.join(theme_info.color_palette)}. "
    
    if theme_info.logo_url:
        theme_context += f" Include logo from: {theme_info.logo_url}. "
    
    return theme_context


@tracer.capture_method
def generate_landing_content(
    prompt: str,
    theme_info: ThemeInfo,
    bedrock_runtime_client: Any,
    llm_model_id: str,
) -> LandingContent:
    """
    Use Bedrock LLM to generate structured landing page content.
    
    Args:
        prompt: Industry/business description
        theme_info: Theme information from target site
        bedrock_runtime_client: Boto3 bedrock-runtime client
        llm_model_id: The Bedrock model ID to use
    
    Returns:
        Validated LandingContent model
    
    Raises:
        BedrockError: If content generation fails
        ValidationError: If generated content is invalid
    """
    # Get prompts from SSM parameters
    ssm_prompts = get_prompts_from_ssm()
    
    # Build the prompt with theme context
    theme_context = build_theme_context(theme_info)
    
    # Use the template from SSM with replacements
    user_prompt = ssm_prompts.prompt_template.format(
        industry=prompt,
        theme_context=theme_context
    )
    
    # Create validated payload using Messages API format
    payload = BedrockPayload(
        anthropic_version="bedrock-2023-05-31",
        max_tokens=1024,
        temperature=0.7,
        system=ssm_prompts.system_prompt,
        messages=[
            {
                "role": "user",
                "content": [{"type": "text", "text": user_prompt}]
            }
        ]
    )
    
    try:
        # Use retry logic with exponential backoff
        response = invoke_bedrock_with_retry(bedrock_runtime_client, llm_model_id, payload)
        
        response_body = response["body"].read().decode("utf-8")
        logger.info("Bedrock response received", extra={"response_length": len(response_body)})
        
        # Parse Bedrock response
        response_json = json.loads(response_body)
        bedrock_response = BedrockResponse(**response_json)
        
        # Extract JSON from the response (get text from first content block)
        completion_text = ""
        if bedrock_response.content and len(bedrock_response.content) > 0:
            first_content = bedrock_response.content[0]
            if isinstance(first_content, dict) and "text" in first_content:
                completion_text = first_content["text"]
        
        # Try to extract JSON from markdown code blocks first
        match = re.search(r'```(?:json)?\s*({[\s\S]*?})\s*```', completion_text)
        if match:
            json_str = match.group(1)
        else:
            # Fallback: extract first JSON object
            match = re.search(r'\{[\s\S]*?\}', completion_text)
            if match:
                json_str = match.group(0)
            else:
                raise LandingValidationError("No valid JSON found in Bedrock response")
        
        # Parse and validate the JSON
        try:
            parsed_json = json.loads(json_str)
            landing_content = LandingContent(**parsed_json)
        except (json.JSONDecodeError, TypeError, ValueError) as e:
            logger.error(f"Invalid JSON in Bedrock response: {e}")
            raise LandingValidationError(f"Invalid landing content structure: {e}")
        
        return landing_content
        
    except Exception as e:
        logger.error("Bedrock generation failed", extra={"error": str(e)})
        raise BedrockError(f"Content generation failed: {str(e)}")


@tracer.capture_method
def store_landing_assets(
    landing_content: LandingContent,
    bucket: str,
    theme_info: ThemeInfo,
) -> Tuple[str, Dict[str, str]]:
    """
    Store landing page assets in S3.
    
    Args:
        landing_content: Validated landing content
        bucket: S3 bucket name
        theme_info: Theme information
    
    Returns:
        Tuple of (generation_id, assets_dict)
    
    Raises:
        Exception: If S3 operations fail
    """
    generation_id = str(uuid.uuid4())
    assets: Dict[str, str] = {}
    
    try:
        # Store the landing content JSON
        content_key = f"generated/{generation_id}/landing_content.json"
        s3_client.put_object(
            Bucket=bucket,
            Key=content_key,
            Body=json.dumps(vars(landing_content)),
            ContentType="application/json"
        )
        assets["content_key"] = content_key
        
        # Store theme information
        theme_key = f"generated/{generation_id}/theme_info.json"
        s3_client.put_object(
            Bucket=bucket,
            Key=theme_key,
            Body=json.dumps(vars(theme_info)),
            ContentType="application/json"
        )
        assets["theme_key"] = theme_key
        
        logger.info(f"Assets stored successfully", extra={
            "generation_id": generation_id,
            "assets": list(assets.keys())
        })
        
        return generation_id, assets
        
    except Exception as e:
        logger.error(f"Failed to store assets", extra={"error": str(e)})
        raise


@logger.inject_lambda_context
@tracer.capture_lambda_handler
@metrics.log_metrics
def handler(event: Dict[str, Any], context: LambdaContext) -> Dict[str, Any]:
    """
    Generate landing page content using Bedrock and store in S3.
    
    Args:
        event: Lambda event dictionary
        context: Lambda context
    
    Returns:
        HTTP response dictionary
    """
    logger.info("gen_landing Lambda invoked")
    
    # Environment variables
    output_bucket = os.environ["OUTPUT_BUCKET"]
    llm_model_id = os.environ.get("BEDROCK_LLM_MODEL_ID", "anthropic.claude-3-sonnet-20240229")
    
    try:
        # Parse and validate input
        try:
            if "body" in event:
                body_content = event["body"]
                if event.get("isBase64Encoded"):
                    import base64
                    body_content = base64.b64decode(body_content).decode("utf-8")
                parsed_body = json.loads(body_content)
            else:
                parsed_body = event if isinstance(event, dict) else json.loads(str(event))
            
            # Convert theme_info dict to ThemeInfo instance if present
            if "theme_info" in parsed_body and parsed_body["theme_info"] is not None:
                theme_info_dict = parsed_body["theme_info"]
                if isinstance(theme_info_dict, dict):
                    parsed_body["theme_info"] = ThemeInfo(**theme_info_dict)
            
            # Validate request using dataclass
            request_data = GenerationRequest(**parsed_body)
            
        except (json.JSONDecodeError, TypeError, ValueError) as e:
            logger.error(f"Invalid request format: {e}")
            return {
                "statusCode": 400,
                "headers": CORS_HEADERS,
                "body": json.dumps({"error": f"Invalid request format: {str(e)}"})
            }
        
        # Generate landing content using Bedrock
        theme_info = request_data.theme_info if request_data.theme_info else ThemeInfo()
        landing_content = generate_landing_content(
            request_data.prompt,
            theme_info,
            bedrock_runtime,
            llm_model_id
        )
        
        # Store assets in S3
        generation_id, assets = store_landing_assets(
            landing_content,
            output_bucket,
            theme_info
        )
        
        # Create validated response
        response_data = GenerationResponse(
            generation_id=generation_id,
            assets=assets,
            status="generated"
        )
        
        logger.info("Landing content generated successfully", extra={
            "generation_id": generation_id
        })
        
        return {
            "statusCode": 200,
            "headers": CORS_HEADERS,
            "body": json.dumps(vars(response_data))
        }
        
    except BedrockError as e:
        logger.error(f"Bedrock error: {e}")
        return {
            "statusCode": 500,
            "headers": CORS_HEADERS,
            "body": json.dumps({"error": f"Content generation failed: {str(e)}"})
        }
    
    except SSMError as e:
        logger.error(f"SSM error: {e}")
        return {
            "statusCode": 500,
            "headers": CORS_HEADERS,
            "body": json.dumps({"error": f"Configuration error: {str(e)}"})
        }
    
    except (TypeError, ValueError) as e:
        logger.error(f"Validation error: {e}")
        return {
            "statusCode": 400,
            "headers": CORS_HEADERS,
            "body": json.dumps({"error": f"Validation failed: {str(e)}"})
        }
    
    except Exception as e:
        logger.error(f"Unexpected error: {e}")
        import traceback
        logger.error(f"Full traceback: {traceback.format_exc()}")
        return {
            "statusCode": 500,
            "headers": CORS_HEADERS,
            "body": json.dumps({"error": f"Unexpected error: {str(e)}"})
        }
