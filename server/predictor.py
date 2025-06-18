# This is the file that implements a flask server to do inferences. It's the file that you will modify to
# implement the scoring for your own algorithm.

from __future__ import print_function

import os
import time
import sys

import flask
import subprocess
import uuid

import zipfile
import tempfile
import tempfile

# The flask app for serving predictions
app = flask.Flask(__name__)

@app.route("/ping", methods=["GET"])
def ping():
    """Determine if the container is working and healthy. In this sample container, we declare
    it healthy if we can load the model successfully."""
#    health = ScoringService.get_model() is not None  # You can insert a health check here

 #   status = 200 if health else 404
    return flask.Response(response="\n", status=200, mimetype="application/json")

@app.route("/invocations", methods=["POST"])
def inference():
    with tempfile.TemporaryDirectory() as temp_dir:
        
        output_filename = f"{uuid.uuid4().hex}.wav"
        output_path = os.path.join(temp_dir, output_filename)

        if flask.request.content_type and flask.request.content_type.startswith("multipart/form-data"):
            if 'audio' not in flask.request.files:
                return flask.jsonify({'error': 'No audio file provided'}), 400
            if 'text' not in flask.request.form:
                return flask.jsonify({'error': 'No text provided'}), 400
            if 'ref_text' not in flask.request.form:
                return flask.jsonify({'error': 'No ref_text provided'}), 400

            cmd = multipart_inference(temp_dir, output_filename)        
        else:
            if not flask.request.data:
               return flask.jsonify({"error": "Request body is empty"}), 400
           
            cmd = zip_inference(temp_dir, output_filename)

        try:
            start_time = time.time()
            result = subprocess.run(cmd, check=True, capture_output=True, text=True)
            elapsed = time.time() - start_time
            print(f"⏱ Inference took {elapsed:.2f} seconds", file=sys.stdout, flush=True)
            print("Subprocess output:", result.stdout, flush=True)
        except subprocess.CalledProcessError as e:
            print("Error:", e.stderr)
            return flask.jsonify({"error": "Inference failed"}), 500

        return flask.send_file(output_path, mimetype='audio/wav', as_attachment=True, download_name='output.wav')


def multipart_inference(dir, output_filename):
    audio_file = flask.request.files['audio']
    input_text = flask.request.form['text']
    input_ref_text = flask.request.form['ref_text']

    input_path = os.path.join(dir, audio_file.filename)
    audio_file.save(input_path)

    return [
        "f5-tts_infer-cli", "--model", "F5TTS_v1_Base",
        "--ref_audio", input_path,
        "--ref_text", input_ref_text,
        "--gen_text", input_text,
        "--output_dir", dir,
        "--output_file", output_filename,
    ]

def zip_inference(dir, output_filename):

    zip_path = os.path.join(dir, "input.zip")
    with open(zip_path, "wb") as f:
        f.write(flask.request.data)

    ref_wav, ref_txt, gen_txt = unzip_and_get_files(zip_path, extract_to=dir)

    with open(ref_txt, "r", encoding="utf-8") as f:
        ref_text_data = f.read()

    return [
        "f5-tts_infer-cli", "--model", "F5TTS_v1_Base",
        "--ref_audio", ref_wav,
        "--ref_text", ref_text_data,
        "--gen_file", gen_txt,
        "--output_dir", dir,
        "--output_file", output_filename
    ]

def unzip_and_get_files(zip_path, extract_to="."):
    if not zipfile.is_zipfile(zip_path):
        raise ValueError(f"{zip_path} is not a valid zip file.")

    with zipfile.ZipFile(zip_path, 'r') as zip_ref:
        zip_ref.extractall(extract_to)

    ref_wav = os.path.join(extract_to, "ref.wav")
    ref_txt = os.path.join(extract_to, "ref.txt")
    gen_txt = os.path.join(extract_to, "gen.txt")

    for f in [ref_wav, ref_txt, gen_txt]:
        if not os.path.exists(f):
            raise FileNotFoundError(f"Missing expected file: {f}")

    return ref_wav, ref_txt, gen_txt