#!/bin/bash

# Variables
REPO_FILE="repo.txt"  
TICKET_NUM="IOT-11983"              
BRANCH_NAME="feature/go-1.23"       
COMMIT_MESSAGE="$TICKET_NUM: go version update to 1.23 and pipeline file update."  
LOCAL_PIPELINE_FILE="bitbucket-pipelines.yml"  

# Check if the local pipeline file exists
if [[ ! -f $LOCAL_PIPELINE_FILE ]]; then
    echo "Local pipeline file $LOCAL_PIPELINE_FILE not found. Please provide the file."
    exit 1
fi

# Function to process a single repository
process_repo() {
    local REPO_URL=$1
    echo "Processing repository: $REPO_URL"

    # Extract repository name from URL
    REPO_NAME=$(basename -s .git $REPO_URL)

    # Clone the repository
    echo "Cloning $REPO_URL..."
    git clone $REPO_URL
    cd $REPO_NAME

    # Create a new feature branch
    echo "Creating feature branch: $BRANCH_NAME"
    git checkout -b $BRANCH_NAME
 
    rm -rf common.mk
    # Update go.mod to use Go version 1.23
    echo "Updating go.mod Go version..."
    sed -i 's/go 1.18/go 1.23/' go.mod || echo "go.mod not found, skipping."

    echo "Updating Dockerfile alpine version..."
    sed -i 's/alpine:3.14/alpine:3.20/' Dockerfile || echo "Dockerfile not found, skipping."

    echo "removing line from docker.."
    sed -i '/RUN apk --no-cache add ca-certificates/d' Dockerfile
    # Run go mod tidy
    echo "Running go mod tidy..."
    go mod tidy || echo "go mod tidy failed, skipping."

    # Replace the bitbucket-pipelines.yml file
    echo "Updating bitbucket-pipelines.yml..."
    cp ../$LOCAL_PIPELINE_FILE bitbucket-pipelines.yml

    # Stage changes
    echo "Staging changes..."
    git add . 2>/dev/null || echo "Nothing to stage."

    # Commit changes
    echo "Committing changes..."
    git commit -m "$COMMIT_MESSAGE" || echo "No changes to commit."

    # Push feature branch to the remote repository
    echo "Pushing branch $BRANCH_NAME to remote repository..."
    git push origin $BRANCH_NAME || echo "Push failed."

    # Return to the parent directory
    cd ..

    # Remove the cloned repository to save space
    rm -rf $REPO_NAME

    echo "Completed processing $REPO_URL"
}

# Check if repository file exists
if [[ ! -f $REPO_FILE ]]; then
    echo "Repository file $REPO_FILE not found."
    exit 1
fi

# Read repositories from the file and process each
while IFS= read -r REPO_URL; do
    if [[ -n $REPO_URL ]]; then
        process_repo "$REPO_URL"
    fi
done < $REPO_FILE

echo "All repositories processed."
