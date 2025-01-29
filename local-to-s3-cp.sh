#!/bin/bash

# AWS S3 Bucket Name
BUCKET_NAME="bluvision-wrapped"
S3_PATH="Jan-2025"  # Change this as needed

# Check if necessary files exist
if [[ ! -f "folder.txt" ]] || [[ ! -f "out.txt" ]]; then
    echo "Error: folder.txt or out.txt not found!"
    exit 1
fi

# Read folder.txt and out.txt line by line
paste folder.txt out.txt | while IFS=$'\t' read -r SRC_FOLDER DEST_FOLDER; do
    # Ensure source folder exists before uploading
    if [[ ! -d "$SRC_FOLDER" ]]; then
        echo "Warning: Source folder '$SRC_FOLDER' does not exist, skipping..."
        continue
    fi

    # Upload the folder to S3
    echo "Uploading $SRC_FOLDER to s3://$BUCKET_NAME/$S3_PATH/$DEST_FOLDER ..."
    aws s3 cp "$SRC_FOLDER" "s3://$BUCKET_NAME/$S3_PATH/$DEST_FOLDER" --recursive

    # Check if the upload was successful
    if [[ $? -eq 0 ]]; then
        echo "Backup successful: $SRC_FOLDER -> $DEST_FOLDER"
    else
        echo "Backup failed: $SRC_FOLDER"
    fi
done
