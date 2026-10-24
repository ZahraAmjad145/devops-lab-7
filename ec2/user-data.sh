#!/bin/bash

set -euxo pipefail

dnf install -y httpd awscli cronie

systemctl enable --now httpd
systemctl enable --now crond

mkdir -p /var/www/html

# Install the synchronization script directly on the instance.
cat > /usr/local/bin/sync-cv.sh <<'SYNC_SCRIPT'
#!/bin/bash

BUCKET="cv-23l-3072"
WEB_ROOT="/var/www/html"
LOG_FILE="/var/log/cv-sync.log"

TOKEN=$(curl -fsS --connect-timeout 2 --max-time 3 \
  -X PUT \
  -H "X-aws-ec2-metadata-token-ttl-seconds: 21600" \
  http://169.254.169.254/latest/api/token)

INSTANCE_ID=$(curl -fsS --connect-timeout 2 --max-time 3 \
  -H "X-aws-ec2-metadata-token: $TOKEN" \
  http://169.254.169.254/latest/meta-data/instance-id)

if aws s3 sync "s3://${BUCKET}/site/" "$WEB_ROOT/" --only-show-errors; then
    sed -i "s|{{HOSTED_ON}}|EC2 - ${INSTANCE_ID}|g" \
      "$WEB_ROOT/index.html"

    echo "[$(date '+%Y-%m-%d %H:%M:%S')] Sync successful; instance=${INSTANCE_ID}" \
      >> "$LOG_FILE"
else
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] ERROR: Sync failed" \
      >> "$LOG_FILE"
    exit 1
fi
SYNC_SCRIPT

chmod 755 /usr/local/bin/sync-cv.sh

# Perform the initial synchronization.
 /usr/local/bin/sync-cv.sh

# Repeat synchronization every five minutes.
cat > /etc/cron.d/cv-sync <<'CRON'
*/5 * * * * root /usr/local/bin/sync-cv.sh
CRON

chmod 644 /etc/cron.d/cv-sync
systemctl restart crond

echo "EC2 CV website setup completed."