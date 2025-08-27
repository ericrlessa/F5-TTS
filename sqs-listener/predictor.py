from __future__ import print_function

import uuid
import re

import os
import time
import sys

import boto3

import subprocess
import uuid
import traceback

import wave

import tempfile


s3 = boto3.client("s3", region_name="ca-central-1")

def download_s3_file(bucket, key, local_path):
    with open(local_path, "wb") as f:
        s3.download_fileobj(bucket, key, f)
    return local_path

def get_wav_duration(file_path: str) -> float:
    """Return duration of a WAV file in seconds."""
    with wave.open(file_path, 'rb') as wav_file:
        frames = wav_file.getnframes()
        rate = wav_file.getframerate()
        duration = frames / float(rate)
    return duration

def inference(data):
    with tempfile.TemporaryDirectory() as temp_dir:
        
        output_filename = f"{uuid.uuid4().hex}.wav"
        output_path = os.path.join(temp_dir, output_filename)

        required_keys = ["bucket", "s3_key_gen", "voices", "s3_key_output"]
        if not all(k in data for k in required_keys):
            return {"error": "Missing required fields"}, 400


        try:
            bucket  =  data.get("bucket")
            gen_key =  data.get("s3_key_gen")
            voices  =  data.get("voices")
            s3_key_output = data.get("s3_key_output")
            
            cmd = json_inference(temp_dir, output_filename, bucket, gen_key, voices)
            
            processing_time = call_process(cmd)

            with open(output_path, "rb") as f:
                s3.put_object(
                    Bucket=bucket,
                    Key=s3_key_output,
                    Body=f,
                    ContentType="audio/wav"
                )
            
            print(f"✅ Podcast stored in {s3_key_output}")

            return {"processing_time": processing_time,
                                    "duration": get_wav_duration(output_path)}, 200

        except Exception as e:
            traceback.print_exc()
            print("Error:", str(e), file=sys.stderr)
            return {"error": "Inference failed"}, 500

def call_process(cmd):
    try:
        start_time = time.time()
        result = subprocess.run(cmd, check=True, capture_output=True, text=True)
        elapsed = time.time() - start_time
        print(f"⏱ Inference took {elapsed:.2f} seconds", file=sys.stdout, flush=True)
        print("Subprocess output:", result.stdout, flush=True)
        return elapsed
    except subprocess.CalledProcessError as e:
        print("❌ Subprocess failed!", file=sys.stderr, flush=True)
        print("Command:", e.cmd, file=sys.stderr, flush=True)
        print("Return code:", e.returncode, file=sys.stderr, flush=True)
        print("Error output:", e.stderr, file=sys.stderr, flush=True)
        traceback.print_exc(file=sys.stderr)
        raise

def json_inference(temp_dir, output_filename, bucket, gen_key, voices):
    config_file = create_toml_file(temp_dir, output_filename, bucket, gen_key, voices)
    print(f"Config toml file: \n{config_file}", file=sys.stdout, flush=True)
    config_file_path = os.path.join(temp_dir, "config_file.toml")
    with open(config_file_path, "w") as f:
        f.write(config_file)

    return ["f5-tts_infer-cli", "--config", config_file_path]

def map_voice_names_to_uuid(voices):
    name_to_id = {voice["name"]: f"voice{i+1}" for i, voice in enumerate(voices)}
    return name_to_id

def replace_voice_names_with_uuid(name_to_uuid, content):
    result = content
    for name, uid in name_to_uuid.items():
        pattern = re.compile(re.escape(f"[{name}]"))
        result = re.sub(pattern, f"[{uid}]", result)

    return result

def replace_voice_names_with_uuid_in_file(name_to_uuid, gen_key_local_path):
    with open(gen_key_local_path, "r") as f:
        content = f.read()
    
    result = replace_voice_names_with_uuid(name_to_uuid, content)

    print(f" replace_voice_names_with_uuid: \n{result}", file=sys.stdout, flush=True)

    with open(gen_key_local_path, "w") as f:
        f.write(result)

def create_toml_file(temp_dir, output_filename, bucket, gen_key, voices):
    name_to_uuid = map_voice_names_to_uuid(voices)
    input_path = os.path.join(temp_dir, "gen_file.txt")
    gen_key_local_path = download_s3_file(bucket, gen_key, input_path)

    config_file = 'model = "F5TTS_v1_Base"\n'
    config_file += f'gen_file = "{gen_key_local_path}"\n'
    config_file += 'remove_silence = false\n'
    config_file += f'output_dir = "{temp_dir}"\n'
    config_file += f'output_file = "{output_filename}"\n'

    for voice in voices:
        config_file += f'[voices.{name_to_uuid[voice["name"]]}]\n'
        ref_audio_path = download_s3_file(bucket, voice["s3_key_ref_audio"], os.path.join(temp_dir, f"{uuid.uuid4().hex}.wav"))
        config_file += f'ref_audio = "{ref_audio_path}"\n'
        ref_text_path = download_s3_file(bucket, voice["s3_key_ref_text"], os.path.join(temp_dir, f"{uuid.uuid4().hex}.txt"))
#        config_file += f'ref_text = "{ref_text_path}"\n'
        config_file += f'ref_text = ""\n'

    
    print(f"name_to_uuid: {name_to_uuid}", file=sys.stdout, flush=True)
    replace_voice_names_with_uuid_in_file(name_to_uuid, gen_key_local_path)

    return config_file