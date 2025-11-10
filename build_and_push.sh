#!/usr/bin/env bash

region=$1
image=$2
dir=$3
env=$4

if [ "$image" == "" ]
then
    echo "Usage: $0 <image-name>"
    exit 1
fi

# Get the account number associated with the current IAM credentials
account=$(aws sts get-caller-identity --query Account --output text)

if [ $? -ne 0 ]
then
    exit 255
fi


# If the repository doesn't exist in ECR, create it.

aws ecr describe-repositories --repository-names "${image}"  --region "${region}" > /dev/null 2>&1

if [ $? -ne 0 ]
then
    aws ecr create-repository --repository-name "${image}" --region "${region}" > /dev/null
fi

# Get the login command from ECR and execute it directly
aws ecr get-login-password --region "${region}" | docker login --username AWS --password-stdin "${account}".dkr.ecr."${region}".amazonaws.com

# Build the docker image locally with the image name and then push it to ECR
# with the full name.

fullname="${account}.dkr.ecr.${region}.amazonaws.com/${image}:${env}"

echo "image: " ${image}
echo "fullname: " ${fullname}

docker build  -t ${image}:${env} ${dir}
docker tag ${image}:${env} ${fullname}

docker push ${fullname}