#!/bin/bash

set -e

# Ensure correct number of arguments
if [ "$#" -ne 5 ]; then
    echo "Usage: $0 [dev|test|prod] [init|validate|plan|apply|destroy] [app1|app2] [new_image_tag] [branch]"
    exit 1
fi

# Arguments
ENVIRONMENT=$1
CMD=$2
SERVICE=$3
NEW_IMAGE_TAG=$4
BRANCH=$5

# Print arguments for debugging
echo "ENVIRONMENT: $ENVIRONMENT"
echo "CMD: $CMD"
echo "SERVICE: $SERVICE"
echo "NEW_IMAGE_TAG: $NEW_IMAGE_TAG"
echo "BRANCH: $BRANCH"

# Directory paths
TF_ROOT_DIR=$(pwd)
TF_WORKING_DIR="${TF_ROOT_DIR}/terraform/${ENVIRONMENT}"
TF_VAR_FILE="${TF_ROOT_DIR}/${ENVIRONMENT}-terraform.tfvars"
TF_BACKEND_CONFIG="${TF_ROOT_DIR}/backend/backend-${ENVIRONMENT}.tf"
S3_BUCKET_NAME="${ENVIRONMENT}-atlus"
VARIABLES_FILE="${TF_ROOT_DIR}/variables.tf"

# Ensure the environment is valid
if [[ "$ENVIRONMENT" != "dev" && "$ENVIRONMENT" != "test" && "$ENVIRONMENT" != "prod" ]]; then
    echo "Invalid environment: $ENVIRONMENT"
    exit 1
fi

# Create the working directory if it doesn't exist
mkdir -p $TF_WORKING_DIR

# Initialize Terraform with the backend configuration if state file doesn't exist
if [ ! -f "$TF_WORKING_DIR/terraform.tfstate" ]; then
    echo "No existing state file found. Initializing Terraform..."
    
    # Copy Terraform configuration files to the working directory
    cp -r ${TF_ROOT_DIR}/*.tf $TF_WORKING_DIR/
    cp -r ${TF_ROOT_DIR}/modules $TF_WORKING_DIR/
    cp -r ${TF_ROOT_DIR}/conf $TF_WORKING_DIR/
    cp -r ${TF_ROOT_DIR}/*.tfvars $TF_WORKING_DIR/

    # Initialize Terraform with the backend configuration
    cd $TF_WORKING_DIR
    terraform init -backend-config=$TF_BACKEND_CONFIG
fi

# Pull the latest state file from S3 if not present locally (for plan, apply, destroy)
if [[ "$CMD" == "plan" || "$CMD" == "apply" || "$CMD" == "destroy" ]]; then
    if [ ! -f "$TF_WORKING_DIR/terraform.tfstate" ]; then
        echo "Pulling state file from S3..."
        aws s3 cp s3://$S3_BUCKET_NAME/terraform.tfstate $TF_WORKING_DIR/terraform.tfstate || true
        echo "AWS S3 pull exit status: $?"
    fi
fi

# Update ECS image in variables.tf
echo "Updating ECS image for service: $SERVICE on branch: $BRANCH"

# Define the key to look for based on the service
case "$SERVICE" in
    app1)
        SERVICE_KEY="admin-ui"
        ;;
    app2)
        SERVICE_KEY="admin-native"
        ;;
    *)
        echo "Invalid service: $SERVICE"
        exit 1
        ;;
esac

# Update the variables.tf file with the new image tag
sed -i "s|container_image = \"[^\"]*\(${SERVICE_KEY}\):[^\"]*\"|container_image = \"xxxxxxxxxxxxxx/atlus/${SERVICE_KEY}:${NEW_IMAGE_TAG}\"|" $VARIABLES_FILE

# Handle different commands
case "$CMD" in
    init)
        echo "Initializing Terraform..."
        terraform init -backend-config=$TF_BACKEND_CONFIG
        ;;
    validate)
        echo "Validating Terraform configuration..."
        terraform validate
        ;;
    plan)
        echo "Planning Terraform changes..."
        terraform plan -var-file=$TF_VAR_FILE -parallelism=1
        ;;
    apply)
        echo "Applying Terraform changes..."
        terraform apply -var-file=$TF_VAR_FILE -auto-approve -parallelism=1

        # Push the updated state file back to S3
        aws s3 cp $TF_WORKING_DIR/terraform.tfstate s3://$S3_BUCKET_NAME/
        echo "AWS S3 push exit status: $?"
        ;;
    destroy)
        echo "Destroying Terraform resources..."
        terraform destroy -var-file=$TF_VAR_FILE -auto-approve -parallelism=1
        ;;
    *)
        echo "Invalid command: $CMD"
        exit 1
        ;;
esac

# Push the updated state file back to the S3 bucket (only for plan, apply, destroy commands)
if [[ "$CMD" == "plan" || "$CMD" == "apply" || "$CMD" == "destroy" ]]; then
    # Check if terraform.tfstate exists before attempting to copy it
    if [ -f "$TF_WORKING_DIR/terraform.tfstate" ]; then
        aws s3 cp $TF_WORKING_DIR/terraform.tfstate s3://$S3_BUCKET_NAME/
        echo "AWS S3 push exit status: $?"
    else
        echo "No terraform.tfstate file found. Skipping state file upload."
    fi
fi

echo "Terraform operation '$CMD' for $ENVIRONMENT environment on branch $BRANCH is complete."
