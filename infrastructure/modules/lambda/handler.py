"""Lambda handler that generates landing pages using AWS Bedrock."""

import json
import os
import uuid

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

    prompt = f"Modify the following HTML to create a landing page:\n{template_html}"

    response = bedrock_runtime.invoke_model(
        modelId=bedrock_model,
        contentType="application/json",
        accept="application/json",
        body=json.dumps({"inputText": prompt}).encode("utf-8"),
    )

    result = json.loads(response["body"].read())
    generated_html = result.get("results", [{}])[0].get("outputText", "")

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
