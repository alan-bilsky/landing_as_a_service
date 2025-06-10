"""Lambda handler that generates landing pages using AWS Bedrock."""

import json
import os
import uuid
import base64

import boto3


s3_client = boto3.client("s3")
bedrock_runtime = boto3.client("bedrock-runtime")



def handler(event, context):
    """Generate a landing page from a template stored in S3."""
    print("Event received:", event)

    input_bucket = os.environ["INPUT_BUCKET"]
    input_key = os.environ["INPUT_KEY"]
    output_bucket = os.environ["OUTPUT_BUCKET"]
    bedrock_model = os.environ["BEDROCK_MODEL_ID"]
    cloudfront_domain = os.environ.get("CLOUDFRONT_DOMAIN")

    template_obj = s3_client.get_object(Bucket=input_bucket, Key=input_key)
    template_html = template_obj["Body"].read().decode("utf-8")

    body_content = event.get("body", "")
    if event.get("isBase64Encoded"):
        body_content = base64.b64decode(body_content).decode("utf-8")

    payload = json.loads(body_content) if body_content else {}
    mods = payload.get("modifications", "")

    prompt = (
        f"Modify the following HTML using these instructions: {mods}\n{template_html}"
    )

    response = bedrock_runtime.invoke_model(
        modelId=bedrock_model,
        contentType="application/json",
        accept="application/json",
        body=json.dumps(
            {
                "prompt": prompt,
                "max_tokens_to_sample": 300,
                "anthropic_version": "bedrock-2023-05-31",
            }
        ).encode("utf-8"),
    )

    generated_html = json.loads(response["body"].read())["completion"]

    output_key = f"{uuid.uuid4()}.html"
    s3_client.put_object(
        Bucket=output_bucket,
        Key=output_key,
        Body=generated_html,
        ContentType="text/html",
    )

    if cloudfront_domain:
        url = f"https://{cloudfront_domain}/{output_key}"
    else:
        url = f"https://{output_bucket}.s3.amazonaws.com/{output_key}"

    return {"statusCode": 200, "body": json.dumps({"url": url})}
