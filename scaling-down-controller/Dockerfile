FROM public.ecr.aws/lambda/python:3.12

# Copy and install dependencies
COPY requirements.txt .
RUN pip install -r requirements.txt

# Copy your app code and folders
COPY app.py .

CMD ["app.lambda_handler"]