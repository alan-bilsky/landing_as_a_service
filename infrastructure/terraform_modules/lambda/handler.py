"""Lambda handler that generates landing pages and images using AWS Bedrock."""

import json
import os
import uuid
import base64
import random

import boto3


BEDROCK_REGION = os.environ.get("BEDROCK_REGION", "us-east-1")

s3_client = boto3.client("s3")
bedrock_runtime = boto3.client("bedrock-runtime", region_name=BEDROCK_REGION)

ESTILO_TREINTA = (
    "obligatory: both hands holding device naturally, five fingers each hand, realistic grip. no distortion. PROPORTIONAL. centered symmetrical face, natural proportions, professional headshot quality. "
    "Ultra realistic professional photograph, DSLR quality. "
    "Person from America with Yellow clothing element (#FFE600) or detail. "
    "smile, device screen-away, correct anatomy, business background, "
    "studio softbox, shallow DOF, ISO 200."
    "camera_face = Canon EOS R5, 85mm f/1.4, ISO 100. "
    "camera_hands = Nikon D850, 50mm f/2.8, macro detail. "
    "camera_business = Sony A7R IV, 24-70mm f/2.8, commercial lighting. "
    "Sharp focus, no floating objects, no artificial elements. "
)



def handler(event, context):
    """Generate a landing page from a template stored in S3."""
    print("Event received:", event)

    input_bucket = os.environ["INPUT_BUCKET"]
    input_key = os.environ["INPUT_KEY"]
    output_bucket = os.environ["OUTPUT_BUCKET"]
    bedrock_model = os.environ["BEDROCK_MODEL_ID"]
    cloudfront_domain = os.environ.get("CLOUDFRONT_DOMAIN")

    # Determine the request payload. Support either API Gateway ("body") or n8n style
    # events where the JSON is nested under node.inputs[0].value.
    if "node" in event:
        raw_json_str = event["node"]["inputs"][0]["value"]
    else:
        body_content = event.get("body", "")
        if event.get("isBase64Encoded"):
            body_content = base64.b64decode(body_content).decode("utf-8")
        raw_json_str = body_content

    parsed = json.loads(raw_json_str or "{}")

    prompt_base = parsed.get("imagen", "")
    if not prompt_base:
        return {
            "statusCode": 400,
            "body": json.dumps({"error": "El campo 'imagen' est\u00e1 vac\u00edo o no existe."}),
        }

    prompt_completo = f"{prompt_base}. {ESTILO_TREINTA}"

    payload = {
        "taskType": "TEXT_IMAGE",
        "textToImageParams": {"text": prompt_completo},
        "imageGenerationConfig": {
            "numberOfImages": 1,
            "quality": "standard",
            "height": 1408,
            "width": 1440,
            "cfgScale": 5.5,
            "seed": random.randint(12, 858993459),
        },
    }

    response = bedrock_runtime.invoke_model(
        modelId=bedrock_model,
        body=json.dumps(payload),
        contentType="application/json",
        accept="application/json",
    )

    response_body = response["body"].read().decode("utf-8")
    parsed_response = json.loads(response_body)
    image_base64 = parsed_response["images"][0]

    # Upload generated image
    image_key = f"images/{uuid.uuid4()}.png"
    s3_client.put_object(
        Bucket=output_bucket,
        Key=image_key,
        Body=base64.b64decode(image_base64),
        ContentType="image/png",
    )

    # Load HTML template from S3
    template_obj = s3_client.get_object(Bucket=input_bucket, Key=input_key)
    html_content = template_obj["Body"].read().decode("utf-8")

    def replace_tag_by_id(html, id_value, new_text):
        start_tag = f'id="{id_value}"'
        start_index = html.find(start_tag)
        if start_index == -1:
            return html
        content_start = html.find(">", start_index) + 1
        content_end = html.find("<", content_start)
        return html[:content_start] + new_text + html[content_end:]

    html_content = replace_tag_by_id(html_content, "titulo", parsed.get("titulo", ""))
    html_content = replace_tag_by_id(html_content, "subtitulo", parsed.get("subtitulo", ""))
    beneficios = parsed.get("beneficios", ["", "", ""])
    if len(beneficios) >= 3:
        html_content = replace_tag_by_id(html_content, "beneficio1", beneficios[0])
        html_content = replace_tag_by_id(html_content, "beneficio2", beneficios[1])
        html_content = replace_tag_by_id(html_content, "beneficio3", beneficios[2])
    html_content = replace_tag_by_id(html_content, "cta", parsed.get("cta", ""))

    output_key = f"{uuid.uuid4()}.html"
    s3_client.put_object(
        Bucket=output_bucket,
        Key=output_key,
        Body=html_content.encode("utf-8"),
        ContentType="text/html",
    )

    html_url = s3_client.generate_presigned_url(
        "get_object",
        Params={"Bucket": output_bucket, "Key": output_key},
        ExpiresIn=3600,
    )

    image_url = s3_client.generate_presigned_url(
        "get_object",
        Params={"Bucket": output_bucket, "Key": image_key},
        ExpiresIn=3600,
    )

    result = {
        "imageS3Url": f"s3://{output_bucket}/{image_key}",
        "imagePresignedUrl": image_url,
        "htmlUrl": html_url,
        "promptUsado": prompt_completo,
    }

    return {"statusCode": 200, "body": json.dumps(result)}
