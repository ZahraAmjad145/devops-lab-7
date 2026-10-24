import os
import json
import time
import base64
import urllib.parse
import boto3

s3 = boto3.client("s3")

BUCKET = os.environ.get("BUCKET", "cv-23l-3072")
PREFIX = os.environ.get("PREFIX", "site/")


def lambda_handler(event, context):
    start_time = time.time()
    path = urllib.parse.unquote(
        event.get("rawPath", event.get("path", "/"))
    )

    if path == "/":
        path = "/index.html"

    status = 200
    content_type = "text/html"
    body = ""
    is_base64_encoded = False

    try:
        if path == "/index.html":
            key = PREFIX + "index.html"
            response = s3.get_object(Bucket=BUCKET, Key=key)
            body = response["Body"].read().decode("utf-8")
            body = body.replace(
                "{{HOSTED_ON}}",
                f"Lambda - {context.function_name}"
            )

        elif path == "/style.css":
            key = PREFIX + "style.css"
            response = s3.get_object(Bucket=BUCKET, Key=key)
            body = response["Body"].read().decode("utf-8")
            content_type = "text/css"

        elif path == "/cv.pdf":
            key = PREFIX + "cv.pdf"
            response = s3.get_object(Bucket=BUCKET, Key=key)
            body = base64.b64encode(
                response["Body"].read()
            ).decode("utf-8")
            content_type = "application/pdf"
            is_base64_encoded = True

        else:
            status = 404
            content_type = "text/plain"
            body = "404 Not Found"

    except Exception as error:
        status = 500
        content_type = "text/plain"
        body = "Internal Server Error"
        print(json.dumps({
            "error": str(error),
            "path": path
        }))

    elapsed_ms = round((time.time() - start_time) * 1000, 2)

    print(json.dumps({
        "fn": context.function_name,
        "path": path,
        "status": status,
        "ms": elapsed_ms
    }))

    headers = {
        "Content-Type": content_type,
        "Cache-Control": "max-age=60"
    }

    return {
        "statusCode": status,
        "headers": headers,
        "body": body,
        "isBase64Encoded": is_base64_encoded
    }
