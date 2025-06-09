import os
import boto3

s3 = boto3.client("s3")


def handler(event, context):
    print("Event received:", event)

    bucket = os.environ.get("OUTPUT_BUCKET")
    if bucket:
        s3.put_object(
            Bucket=bucket,
            Key="index.html",
            Body="<html><body>Hello from Lambda</body></html>",
            ContentType="text/html",
        )

    return {"statusCode": 200, "body": "ok"}
