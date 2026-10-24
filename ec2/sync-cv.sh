#!/bin/bash

BUCKET="cv-23l-3072"
WEB_ROOT="/var/www/html"
LOG_FILE="/var/log/cv-sync.log"

# Get an IMDSv2 token and the instance ID.
TOKEN=$(curl -fsS --connect-timeout 2 --max-time 3 \
  -X PUT \
  -H "X-aws-ec2-metadata-token-ttl-seconds: 21600" \
  http://169.254.169.254/latest/api/token)

INSTANCE_ID=$(curl -fsS --connect-timeout 2 --max-time 3 \
  -H "X-aws-ec2-metadata-token: $TOKEN" \
  http://169.254.169.254/latest/meta-data/instance-id)

# Download the website from S3 and update the hosting footer.
if aws s3 sync "s3://${BUCKET}/site/" "$WEB_ROOT/" --only-show-errors; then
    if [ -f "$WEB_ROOT/index.html" ]; then
        sed -i "s|{{HOSTED_ON}}|EC2 - ${INSTANCE_ID}|g" \
          "$WEB_ROOT/index.html"
    fi

    echo "[$(date '+%Y-%m-%d %H:%M:%S')] Sync successful; instance=${INSTANCE_ID}" \
      >> "$LOG_FILE"
else
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] ERROR: Sync failed" \
      >> "$LOG_FILE"
    exit 1
fi