import boto3
import uuid
import mimetypes
from botocore.config import Config


# Prepare parts
boundary = f'----WebKitFormBoundary{uuid.uuid4().hex}'
newline = '\r\n'
delimiter = f'--{boundary}'

# Read audio file
with open("../../src/f5_tts/infer/examples/basic/basic_ref_en.wav", "rb") as f:
    audio_data = f.read()



# Multipart body
body = (
    delimiter + newline +
    'Content-Disposition: form-data; name="audio"; filename="sample.wav"' + newline +
    f'Content-Type: {mimetypes.guess_type("sample.wav")[0]}' + newline + newline +
    audio_data.decode("latin1") + newline +

    delimiter + newline +
    'Content-Disposition: form-data; name="text"' + newline + newline +
    "Hello world" + newline +

    delimiter + newline +
    'Content-Disposition: form-data; name="ref_text"' + newline + newline +
    "Some call me nature, others call me mother nature." + newline +

    delimiter + '--' + newline
)

timeout_config = Config(connect_timeout=10, read_timeout=500)

# Encode body to bytes
body_bytes = body.encode("latin1")  # Required since audio data is binary

# Call SageMaker endpoint
client = boto3.client("sagemaker-runtime", config=timeout_config, region_name="us-east-1")

response = client.invoke_endpoint(
    EndpointName="f5tts",
    ContentType=f"multipart/form-data; boundary={boundary}",
    Body=body_bytes
)

# Save the response (if it's a file, e.g., WAV)
with open("output.wav", "wb") as f:
    f.write(response['Body'].read())

print("✅ File saved as output.wav")
