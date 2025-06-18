import os
import sagemaker
import boto3
from time import gmtime, strftime
from datetime import datetime

boto_session = boto3.session.Session()
sm_runtime = boto_session.client("sagemaker-runtime")

response = sm_runtime.invoke_endpoint_async(
    EndpointName="f5tts", InputLocation="s3://voice-clone-f5/input/long_audio.zip"
)
output_location = response["OutputLocation"]
print(f"OutputLocation: {output_location}")