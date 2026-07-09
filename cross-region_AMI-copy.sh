#!/bin/bash

PROJECT_NAME="tryshoov.com"
SOURCE_REGION="eu-west-1"
DEST_REGION="us-east-1"
AMI_NAME_PREFIX="DLM_policy-074d0029bc6276f4f_i-08f33dac7a950f13d"
RETENTION_COUNT=14

echo "===== Backup started at $(date) ====="

echo "=== Step 1: Get latest AMI from $SOURCE_REGION ==="

LATEST_AMI_ID=$(aws ec2 describe-images \
    --region $SOURCE_REGION \
    --owners self \
    --filters "Name=name,Values=${AMI_NAME_PREFIX}*" \
    --query 'Images | sort_by(@, &CreationDate)[-1].ImageId' \
    --output text)

if [ "$LATEST_AMI_ID" == "None" ]; then
    echo "No AMI found!"
    exit 1
fi

AMI_NAME=$(aws ec2 describe-images \
    --region $SOURCE_REGION \
    --image-ids $LATEST_AMI_ID \
    --query 'Images[0].Name' \
    --output text)

echo "Latest AMI: $AMI_NAME ($LATEST_AMI_ID)"

echo "=== Step 2: Copy AMI to $DEST_REGION ==="

NEW_AMI_ID=$(aws ec2 copy-image \
    --source-region $SOURCE_REGION \
    --source-image-id $LATEST_AMI_ID \
    --region $DEST_REGION \
    --name "${AMI_NAME}-copy-virginia-$(date +%Y-%m-%d-%H-%M)" \
    --query 'ImageId' \
    --output text)

echo "AMI copy started: $NEW_AMI_ID"

echo "Waiting for AMI to become available..."

while true; do
    STATUS=$(aws ec2 describe-images \
        --region $DEST_REGION \
        --image-ids $NEW_AMI_ID \
        --query 'Images[0].State' \
        --output text)

    echo "Current status: $STATUS"

    if [ "$STATUS" == "available" ]; then
        echo "AMI is now available: $NEW_AMI_ID"
        break
    fi

    if [ "$STATUS" == "failed" ]; then
        echo "AMI copy failed!"
        exit 1
    fi

    sleep 60
done

echo "Tagging AMI..."

aws ec2 create-tags \
    --region $DEST_REGION \
    --resources $NEW_AMI_ID \
    --tags Key=Name,Value=$PROJECT_NAME Key=mgt:managed,Value=true

echo "=== Step 3: Cleanup old AMIs in $DEST_REGION ==="

AMI_LIST=$(aws ec2 describe-images \
    --region $DEST_REGION \
    --owners self \
    --filters "Name=name,Values=${AMI_NAME_PREFIX}*" \
    --query 'Images | sort_by(@, &CreationDate)[].ImageId' \
    --output text)

TOTAL_AMIS=$(echo $AMI_LIST | wc -w)

echo "Total AMIs in $DEST_REGION: $TOTAL_AMIS"

if [ "$TOTAL_AMIS" -le "$RETENTION_COUNT" ]; then
    echo "No cleanup required."
    exit 0
fi

DELETE_COUNT=$(($TOTAL_AMIS - $RETENTION_COUNT))

echo "Deleting $DELETE_COUNT old AMIs..."


AMI_ARRAY=($AMI_LIST)

for ((i=0; i<$DELETE_COUNT; i++))
do
    AMI_ID=${AMI_ARRAY[$i]}
    
    echo "Deregistering AMI: $AMI_ID"

    SNAPSHOT_IDS=$(aws ec2 describe-images \
        --region $DEST_REGION \
        --image-ids $AMI_ID \
        --query 'Images[0].BlockDeviceMappings[].Ebs.SnapshotId' \
        --output text)

    aws ec2 deregister-image \
        --region $DEST_REGION \
        --image-id $AMI_ID

    for SNAP_ID in $SNAPSHOT_IDS
    do
        echo "Deleting snapshot: $SNAP_ID"
        aws ec2 delete-snapshot \
            --region $DEST_REGION \
            --snapshot-id $SNAP_ID
    done
done

echo "Cleanup completed. Retained latest $RETENTION_COUNT AMIs."

echo "=== Process completed successfully ==="

echo "===== Backup completed at $(date) ====="