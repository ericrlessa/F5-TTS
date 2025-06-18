import requests
import zipfile
import io

# Paths to your input files
ref_wav_path = "../../src/f5_tts/infer/examples/basic/basic_ref_en.wav"
ref_txt_content = "Some call me nature, others call me mother nature."
gen_txt_content = "Hello world"

# Create ZIP in memory
zip_buffer = io.BytesIO()
with zipfile.ZipFile(zip_buffer, "w", zipfile.ZIP_DEFLATED) as zip_file:
    zip_file.write(ref_wav_path, arcname="ref.wav")
    zip_file.writestr("ref.txt", ref_txt_content)
    zip_file.writestr("gen.txt", gen_txt_content)

# Move to beginning of buffer
zip_buffer.seek(0)

# Send POST request with ZIP in body
headers = {"Content-Type": "application/zip"}
response = requests.post("http://localhost:8080/invocations", data=zip_buffer.read(), headers=headers)

# Handle response
print(response.status_code)
if response.status_code == 200:
    with open("output.wav", "wb") as f:
        f.write(response.content)
    print("✅ Saved response to output.wav")
else:
    print("❌ Error:", response.text)