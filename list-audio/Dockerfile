FROM public.ecr.aws/lambda/python:3.12

# Copy and install dependencies
COPY requirements.txt .
RUN pip install -r requirements.txt

# Copy your app code (app.py)
COPY app.py .

# Set the Lambda handler to app.handler (module.function)
CMD ["app.handler"]