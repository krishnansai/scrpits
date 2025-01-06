#!/bin/bash

# Variables
REGION="us-east-1"
CLUSTER_NAME="bztest"

# Function to delete master** tags for a given service
delete_master_tags() {
  local SERVICE_NAME=$1

  echo "Processing service: $SERVICE_NAME"  >> service.txt

  # Get the task definition for the running ECS service
  TASK_DEFINITION=$(aws ecs describe-services --cluster $CLUSTER_NAME --services $SERVICE_NAME --region $REGION --query 'services[0].taskDefinition' --output text)
  if [ -z "$TASK_DEFINITION" ]; then
    echo "No task definition found for service $SERVICE_NAME. Skipping."
    return
  fi

  # Get the image used by the task definition
  TASK_IMAGE=$(aws ecs describe-task-definition --task-definition $TASK_DEFINITION --region $REGION --query 'taskDefinition.containerDefinitions[0].image' --output text)

  # Extract the image name without the tag or digest
  TASK_IMAGE_NAME=$(echo $TASK_IMAGE | awk -F'/' '{print $NF}' | awk -F':' '{print $1}')

  echo "Task Image: $TASK_IMAGE"
  echo "Task Image Name: $TASK_IMAGE_NAME"  >> image_name.txt

  # Fetch the list of images with tags from the specific repository
  IMAGE_TAGS=$(aws ecr list-images --repository-name $TASK_IMAGE_NAME --region $REGION --query 'imageIds[*]' --output json)

  # Filter tags starting with 'master'
  MASTER_TAGS=$(echo $IMAGE_TAGS | jq -r '.[] | select(.imageTag != null) | select(.imageTag | startswith("master")) | @base64')

  # Loop through each master tag and delete the tag
  for tag in $MASTER_TAGS; do
    _jq() {
      echo ${tag} | base64 --decode | jq -r ${1}
    }

    IMAGE_DIGEST=$(_jq '.imageDigest')
    IMAGE_TAG=$(_jq '.imageTag')

    echo "Deleting tag: $IMAGE_TAG with digest: $IMAGE_DIGEST from repository: $TASK_IMAGE_NAME"  >> image.txt
    # aws ecr batch-delete-image --repository-name $TASK_IMAGE_NAME --region $REGION --image-ids imageDigest=$IMAGE_DIGEST,imageTag=$IMAGE_TAG
  done

  echo "Completed processing repository: $TASK_IMAGE_NAME"
}

# Get the list of services in the cluster
SERVICES=$(aws ecs list-services --cluster $CLUSTER_NAME --region $REGION --query 'serviceArns' --output json | jq -r '.[]')

if [ -z "$SERVICES" ]; then
  echo "No services found in cluster $CLUSTER_NAME. Exiting."
  exit 1
fi

# Loop through each service
for SERVICE_ARN in $SERVICES; do
  SERVICE_NAME=$(echo $SERVICE_ARN | awk -F'/' '{print $NF}')
  delete_master_tags $SERVICE_NAME
done

echo "Deletion of master** tags completed."
