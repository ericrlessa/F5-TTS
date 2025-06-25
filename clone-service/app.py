import json
import boto3
import base64
import os

s3_client = boto3.client('s3')
BUCKET_NAME = os.environ.get('BUCKET_NAME')

def lambda_handler(event, context):
    try:
        # Parse input
        body = event.get("body")
        if event.get("isBase64Encoded"):
            body = base64.b64decode(body).decode("utf-8")

        data = json.loads(body)

        model = data.get("model")
        audio_b64 = data.get("audio")
        ref_text = data.get("ref_text")

        if not model:
            return {"statusCode": 400, "body": "Missing 'model'"}
        if not audio_b64:
            return {"statusCode": 400, "body": "Missing 'audio'"}
        if not ref_text:
            return {"statusCode": 400, "body": "Missing 'ref_text'"}

        audio_bytes = base64.b64decode(audio_b64)
        s3_key_audio = f"{model}/ref.wav"
        s3_client.put_object(Bucket=BUCKET_NAME, Key=s3_key_audio, Body=audio_bytes, ContentType='audio/wav')

        s3_key_ref_text = f"{model}/ref_text.txt"
        s3_client.put_object(Bucket=BUCKET_NAME, Key=s3_key_ref_text, Body=ref_text, ContentType='text/plain')

        return {
            "statusCode": 200,
            "body": json.dumps({
                "message": "Upload successful",
                "audio_file": s3_key_audio,
                "text_file": s3_key_ref_text
            })
        }
    except Exception as e:
        return {"statusCode": 500, "body": str(e)}
