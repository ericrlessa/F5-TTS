# This is the file that implements a flask server to do inferences. It's the file that you will modify to
# implement the scoring for your own algorithm.

from __future__ import print_function

import io
import json
import os
import pickle
import signal
import sys
import traceback

import flask
import subprocess
import uuid


prefix = "/opt/ml/"
model_path = os.path.join(prefix, "model")

# The flask app for serving predictions
app = flask.Flask(__name__)

@app.route("/ping", methods=["GET"])
def ping():
    """Determine if the container is working and healthy. In this sample container, we declare
    it healthy if we can load the model successfully."""
#    health = ScoringService.get_model() is not None  # You can insert a health check here

 #   status = 200 if health else 404
    return flask.Response(response="\n", status=200, mimetype="application/json")


UPLOAD_FOLDER = 'uploads'
OUTPUT_FOLDER = '/opt/ml/output'
os.makedirs(UPLOAD_FOLDER, exist_ok=True)
os.makedirs(OUTPUT_FOLDER, exist_ok=True)

@app.route("/invocations", methods=["POST"])
def transformation():
    """Do an inference on a single batch of data. In this sample server, we take data as CSV, convert
    it to a pandas data frame for internal use and then convert the predictions back to CSV (which really
    just means one prediction per line, since there's a single column.
    """
    if flask.request.content_type and flask.request.content_type.startswith("multipart/form-data"):
        if 'audio' not in flask.request.files:
            return flask.jsonify({'error': 'No audio file provided'}), 400
        audio_file = flask.request.files['audio']

        if 'text' not in flask.request.form:
            return flask.jsonify({'error': 'No text provided'}), 400
        input_text = flask.request.form['text']

        if 'ref_text' not in flask.request.form:
            return flask.jsonify({'error': 'No text provided'}), 400
        input_ref_text = flask.request.form['ref_text']

    else:
        return flask.Response(
            response="This predictor expect multipart/form-data", status=415, mimetype="text/plain"
        )

    input_path = os.path.join(UPLOAD_FOLDER, audio_file.filename)
    audio_file.save(input_path)

    output_filename = f"{uuid.uuid4().hex}.wav"
    output_path = os.path.join(OUTPUT_FOLDER, output_filename)

    # Command and arguments as a list
    cmd = ["f5-tts_infer-cli", "--model", "F5TTS_v1_Base",
     "--ref_audio", input_path,
     "--ref_text", input_ref_text,
     "--gen_text", input_text,
     "--output_dir", OUTPUT_FOLDER,
     "--output_file", output_filename]

    try:
        result = subprocess.run(cmd, check=True, capture_output=True, text=True)
        print("Command output:", result.stdout)
    except subprocess.CalledProcessError as e:
        print("Error:", e.stderr)

    return flask.send_file(output_path, mimetype='audio/wav', as_attachment=True, download_name='output.wav')

