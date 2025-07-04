"""Lambda handler that generates landing pages and images using AWS Bedrock."""

import json
import os
import uuid
import base64
import random
import time
import re
import requests
from bs4 import BeautifulSoup
import cssutils

import boto3

# Suppress almost all cssutils warnings
cssutils.log.setLevel('FATAL')

BEDROCK_REGION = os.environ.get("BEDROCK_REGION", "us-west-2")

s3_client = boto3.client("s3")
bedrock_runtime = boto3.client("bedrock-runtime", region_name=BEDROCK_REGION)

ESTILO_LAAS = (
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

# Add this at the top-level for reuse
CORS_HEADERS = {
    "Access-Control-Allow-Origin": "*",
    "Access-Control-Allow-Headers": "Content-Type,Authorization",
    "Access-Control-Allow-Methods": "OPTIONS,POST"
}


def generate_landing_fields_from_prompt(prompt, bedrock_runtime, llm_model_id):
    """Use Bedrock LLM to generate structured landing page fields from a prompt."""
    system_prompt = (
        "You are an expert landing page copywriter. Given a business or industry description, respond ONLY with a valid JSON object with the following fields: "
        "'titulo' (title), 'subtitulo' (subtitle), 'beneficios' (list of 3 benefits), 'cta' (call to action), and 'imagen' (image prompt for a hero image). "
        "Do not include any explanation, markdown, or text outside the JSON object."
    )
    user_prompt = f"Business/Industry: {prompt}"
    # Anthropic Claude v2 expects 'prompt', 'max_tokens_to_sample', 'temperature'
    prompt = (
        f"{system_prompt}\n\nHuman: {user_prompt}\n\nAssistant:"
    )
    payload = {
        "prompt": prompt,
        "max_tokens_to_sample": 512,
        "temperature": 0.7
    }
    response = bedrock_runtime.invoke_model(
        modelId=llm_model_id,
        body=json.dumps(payload),
        contentType="application/json",
        accept="application/json",
    )
    response_body = response["body"].read().decode("utf-8")
    print("LLM raw response:", response_body)
    try:
        response_json = json.loads(response_body)
        completion_text = response_json.get("completion", "")

        # Print for debugging
        print("LLM completion text:", completion_text)

        # Try to extract JSON inside a markdown code block (```json ... ``` or ``` ... ```)
        match = re.search(r'```(?:json)?\s*({[\s\S]*?})\s*```', completion_text)
        if match:
            json_str = match.group(1)
            parsed = json.loads(json_str)
            if isinstance(parsed, dict) and all(k in parsed for k in ["titulo", "subtitulo", "beneficios", "cta", "imagen"]):
                return parsed
        # Fallback: extract first JSON object in the text
        match = re.search(r'\{[\s\S]*?\}', completion_text)
        if match:
            parsed = json.loads(match.group(0))
            if isinstance(parsed, dict) and all(k in parsed for k in ["titulo", "subtitulo", "beneficios", "cta", "imagen"]):
                return parsed
    except Exception as e:
        print("Error parsing LLM response:", e, response_body)
    return None


def replace_img_src_by_id(html, id_value, new_src):
    start_tag = f'id="{id_value}"'
    start_index = html.find(start_tag)
    if start_index == -1:
        return html
    src_index = html.find('src="', start_index)
    if src_index == -1:
        return html
    src_start = src_index + 5
    src_end = html.find('"', src_start)
    return html[:src_start] + new_src + html[src_end:]


def replace_tag_by_id(html, id_value, new_text):
    # Replace the inner text of any tag with the given id (including <title>, <h1>, etc.)
    pattern = rf'(<([a-zA-Z0-9]+)[^>]*id=["\\\\\'\"]{id_value}["\\\\\'\"][^>]*>)(.*?)(</\2>)'
    return re.sub(pattern, rf'\1{new_text}\4', html, flags=re.DOTALL)


def extract_style_info(html, base_url):
    soup = BeautifulSoup(html, 'html.parser')
    styles = {'fonts': set(), 'colors': set(), 'layout': []}
    # Inline styles and <style> tags
    for style in soup.find_all('style'):
        try:
            css_text = style.string or ''
            # Filter out rules with unsupported features
            if any(x in css_text for x in ['var(', 'flex', 'grid']):
                continue
            sheet = cssutils.parseString(css_text)
            for rule in sheet:
                if rule.type == rule.STYLE_RULE:
                    if 'color' in rule.style:
                        styles['colors'].add(rule.style['color'])
                    if 'background-color' in rule.style:
                        styles['colors'].add(rule.style['background-color'])
                    if 'font-family' in rule.style:
                        styles['fonts'].add(rule.style['font-family'])
        except Exception as e:
            print(f"[cssutils] Error parsing inline <style>: {e}")
    # External CSS
    for link in soup.find_all('link', rel='stylesheet'):
        href = link.get('href')
        if href:
            if not href.startswith('http'):
                href = base_url + href if href.startswith('/') else base_url + '/' + href
            try:
                css = requests.get(href, timeout=5).text
                # Filter out rules with unsupported features
                if any(x in css for x in ['var(', 'flex', 'grid']):
                    continue
                sheet = cssutils.parseString(css)
                for rule in sheet:
                    if rule.type == rule.STYLE_RULE:
                        if 'color' in rule.style:
                            styles['colors'].add(rule.style['color'])
                        if 'background-color' in rule.style:
                            styles['colors'].add(rule.style['background-color'])
                        if 'font-family' in rule.style:
                            styles['fonts'].add(rule.style['font-family'])
            except Exception as e:
                print(f"[cssutils] Error parsing external CSS ({href}): {e}")
    # Layout hints: look for nav, hero, main, footer, etc.
    for tag in ['nav', 'header', 'main', 'section', 'footer']:
        if soup.find(tag):
            styles['layout'].append(tag)
    # Fallback: if nothing found, use defaults
    if not styles['fonts']:
        styles['fonts'].add('Arial, sans-serif')
    if not styles['colors']:
        styles['colors'].add('#333')
    return styles


def handler(event, context):
    """Generate a landing page from a template stored in S3, or from a chat prompt."""
    print("Event received:", event)

    input_bucket = os.environ["INPUT_BUCKET"]
    input_key = os.environ["INPUT_KEY"]
    output_bucket = os.environ["OUTPUT_BUCKET"]
    bedrock_model = os.environ["BEDROCK_MODEL_ID"]
    llm_model_id = os.environ.get("BEDROCK_LLM_MODEL_ID", "anthropic.claude-v2")
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
    source_url = parsed.get('source_url')
    base_template_html = None
    style_info = None
    source_logo_url = None
    source_favicon_url = None
    source_colors = None
    source_fonts = None
    if source_url:
        try:
            resp = requests.get(source_url, timeout=10)
            if resp.status_code == 200:
                base_template_html = resp.text
                style_info = extract_style_info(base_template_html, source_url)
                # Extract logo and favicon
                soup = BeautifulSoup(base_template_html, 'html.parser')
                logo_tag = soup.find('img', src=True)
                if logo_tag:
                    source_logo_url = logo_tag['src']
                    if source_logo_url and not source_logo_url.startswith('http'):
                        source_logo_url = source_url + source_logo_url if source_logo_url.startswith('/') else source_url + '/' + source_logo_url
                favicon_tag = soup.find('link', rel=lambda x: x and 'icon' in x)
                if favicon_tag and favicon_tag.get('href'):
                    source_favicon_url = favicon_tag['href']
                    if source_favicon_url and not source_favicon_url.startswith('http'):
                        source_favicon_url = source_url + source_favicon_url if source_favicon_url.startswith('/') else source_url + '/' + source_favicon_url
                source_colors = list(style_info['colors']) if style_info and style_info['colors'] else None
                source_fonts = list(style_info['fonts']) if style_info and style_info['fonts'] else None
                # If the HTML is mostly empty or has no meaningful content, ignore it
                if len(soup.get_text(strip=True)) < 100:
                    base_template_html = None
        except Exception as e:
            print(f"Error fetching/parsing source_url: {e}")

    # --- THEME EXTRACTION LOGIC ---
    theme_css = ''
    theme_logo_url = None
    theme_favicon_url = None
    theme_fonts = None
    theme_colors = None
    if source_url:
        try:
            resp = requests.get(source_url, timeout=10)
            if resp.status_code == 200:
                soup = BeautifulSoup(resp.text, 'html.parser')
                # Inline all external CSS
                for link in soup.find_all('link', rel='stylesheet'):
                    href = link.get('href')
                    if href:
                        if not href.startswith('http'):
                            href = source_url + href if href.startswith('/') else source_url + '/' + href
                        try:
                            css = requests.get(href, timeout=5).text
                            theme_css += f"\n/* {href} */\n" + css
                        except Exception as e:
                            print(f"[theme] Error fetching CSS {href}: {e}")
                # Inline <style> tags
                for style in soup.find_all('style'):
                    if style.string:
                        theme_css += f"\n/* inline style */\n" + style.string
                # Extract logo
                logo_tag = soup.find('img', src=True)
                if logo_tag:
                    theme_logo_url = logo_tag['src']
                    if theme_logo_url and not theme_logo_url.startswith('http'):
                        theme_logo_url = source_url + theme_logo_url if theme_logo_url.startswith('/') else source_url + '/' + theme_logo_url
                # Extract favicon
                favicon_tag = soup.find('link', rel=lambda x: x and 'icon' in x)
                if favicon_tag and favicon_tag.get('href'):
                    theme_favicon_url = favicon_tag['href']
                    if theme_favicon_url and not theme_favicon_url.startswith('http'):
                        theme_favicon_url = source_url + theme_favicon_url if theme_favicon_url.startswith('/') else source_url + '/' + theme_favicon_url
                # Extract fonts/colors from CSS
                style_info = extract_style_info(resp.text, source_url)
                theme_fonts = list(style_info['fonts']) if style_info and style_info['fonts'] else None
                theme_colors = list(style_info['colors']) if style_info and style_info['colors'] else None
        except Exception as e:
            print(f"[theme] Error extracting theme: {e}")

    # --- NEW: Chat endpoint logic ---
    if "prompt" in parsed and len(parsed) >= 1:
        chat_prompt = parsed["prompt"]
        # Enhance prompt with style info if available
        if style_info:
            style_str = f"Use the following style: fonts: {', '.join(style_info['fonts'])}; colors: {', '.join(style_info['colors'])}; layout: {', '.join(style_info['layout'])}."
            chat_prompt = f"{chat_prompt}\n{style_str}"
        llm_fields = generate_landing_fields_from_prompt(chat_prompt, bedrock_runtime, llm_model_id)
        if not llm_fields:
            return {
                "statusCode": 500,
                "headers": CORS_HEADERS,
                "body": json.dumps({"error": "Could not generate landing page fields from prompt."}),
            }
        parsed = llm_fields

    # --- Existing logic below ---
    prompt_base = parsed.get("imagen", "")
    if not prompt_base:
        return {
            "statusCode": 400,
            "headers": CORS_HEADERS,
            "body": json.dumps({"error": "El campo 'imagen' est\u00e1 vac\u00edo o no existe."}),
        }

    prompt_completo = f"{prompt_base}. {ESTILO_LAAS}"

    # Truncate to 512 characters for Bedrock image model
    MAX_PROMPT_LENGTH = 512
    if len(prompt_completo) > MAX_PROMPT_LENGTH:
        prompt_completo = prompt_completo[:MAX_PROMPT_LENGTH]

    payload = {
        "taskType": "TEXT_IMAGE",
        "textToImageParams": {
            "text": prompt_completo
        },
        "imageGenerationConfig": {
            "numberOfImages": 1,
            "quality": "standard",
            "height": 1024,
            "width": 1024,
            "cfgScale": 8.0,
            "seed": random.randint(0, 2147483646),
        }
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

    # Generate presigned URL for the image (move this up)
    image_url = s3_client.generate_presigned_url(
        "get_object",
        Params={"Bucket": output_bucket, "Key": image_key},
        ExpiresIn=3600,
    )

    # --- THEMEABLE TEMPLATE ---
    template_obj = s3_client.get_object(Bucket=input_bucket, Key=input_key)
    html_content = template_obj["Body"].read().decode("utf-8")
    # Inject theme CSS in <head>
    if theme_css:
        html_content = html_content.replace('</head>', f'<style>{theme_css}</style></head>')
    # Replace logo
    if theme_logo_url:
        html_content = replace_img_src_by_id(html_content, "logo", theme_logo_url)
    # Replace favicon
    if theme_favicon_url:
        html_content = html_content.replace('<link rel="icon" href="favicon.ico">', f'<link rel="icon" href="{theme_favicon_url}">')
    # Replace fonts/colors
    if theme_fonts:
        html_content = html_content.replace('font-family: Arial, sans-serif;', f'font-family: {theme_fonts[0]}, Arial, sans-serif;')
    if theme_colors:
        html_content = html_content.replace(':root {', f':root {{ --primary-color: {theme_colors[0]};')
    # Inject our content
    html_content = replace_tag_by_id(html_content, "titulo", parsed.get("titulo", ""))
    html_content = replace_tag_by_id(html_content, "subtitulo", parsed.get("subtitulo", ""))
    beneficios = parsed.get("beneficios", ["", "", ""])
    if len(beneficios) >= 3:
        html_content = replace_tag_by_id(html_content, "beneficio1", beneficios[0])
        html_content = replace_tag_by_id(html_content, "beneficio2", beneficios[1])
        html_content = replace_tag_by_id(html_content, "beneficio3", beneficios[2])
    html_content = replace_tag_by_id(html_content, "cta", parsed.get("cta", ""))
    html_content = replace_img_src_by_id(html_content, "hero-image", image_url)
    print('--- OUTPUT THEMED HTML ---')
    print(html_content)

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

    result = {
        "imageS3Url": f"s3://{output_bucket}/{image_key}",
        "imagePresignedUrl": image_url,
        "htmlUrl": html_url,
        "promptUsado": prompt_completo,
    }

    return {"statusCode": 200, "headers": CORS_HEADERS, "body": json.dumps(result)}
