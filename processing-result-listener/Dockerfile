FROM public.ecr.aws/lambda/nodejs:20

# Install dependencies
COPY package*.json ./
RUN npm install

# Copy function code
COPY index.js ./

# Command for Lambda
CMD ["index.handler"]