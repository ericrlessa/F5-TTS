import requests

files = {
    "audio": open("../../src/f5_tts/infer/examples/basic/basic_ref_en.wav", "rb"),
}
data = {
    "text": "Hello world",
    "ref_text": "Some call me nature, others call me mother nature.",
}

response = requests.post("http://localhost:8080/invocations", files=files, data=data)
print(response.status_code)
print(response)