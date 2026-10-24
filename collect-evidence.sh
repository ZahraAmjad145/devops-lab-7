#!/bin/bash

# Check that exactly three arguments were provided.
if [ "$#" -ne 3 ]; then
    echo "Usage: ./collect-evidence.sh <bucket> <ec2-address> <lambda-address>"
    exit 1
fi

BUCKET="$1"
EC2_ADDRESS="$2"
LAMBDA_ADDRESS="$3"
REGION="ap-southeast-2"
INSTANCE_ID="i-069dc3d4ef86ff3d1"
LAMBDA_FUNCTION="cv-lambda-23l-3072"
EC2_ROLE="cv-ec2-role-23l-3072"
LAMBDA_ROLE="cv-lambda-role-23l-3072"
OUTPUT="evidence.txt"

# Run an AWS command and record errors without stopping the script.
run_command() {
    echo "\$ $*" >> "$OUTPUT"
    "$@" >> "$OUTPUT" 2>&1
    STATUS=$?

    if [ "$STATUS" -ne 0 ]; then
        echo "NOTE: Command failed with exit code $STATUS." >> "$OUTPUT"
    fi

    echo "" >> "$OUTPUT"
}

# Start a new evidence file.
echo "AWS LAB 7 - EVIDENCE REPORT" > "$OUTPUT"
echo "Date: $(date)" >> "$OUTPUT"
echo "Region: $REGION" >> "$OUTPUT"
echo "" >> "$OUTPUT"

# 1. Caller identity
echo "===== 1. CALLER IDENTITY =====" >> "$OUTPUT"
run_command aws sts get-caller-identity --region "$REGION"

# 2. S3 public-access settings
echo "===== 2. S3 PUBLIC-ACCESS SETTINGS =====" >> "$OUTPUT"
run_command aws s3api get-public-access-block \
    --bucket "$BUCKET" --region "$REGION"

# 3. S3 versioning
echo "===== 3. S3 VERSIONING =====" >> "$OUTPUT"
run_command aws s3api get-bucket-versioning \
    --bucket "$BUCKET" --region "$REGION"

# 4. S3 objects
echo "===== 4. S3 OBJECTS =====" >> "$OUTPUT"
run_command aws s3api list-objects-v2 \
    --bucket "$BUCKET" --prefix "site/" --region "$REGION"

# 5. EC2 role permissions
echo "===== 5. EC2 IAM POLICY =====" >> "$OUTPUT"
run_command aws iam get-role-policy \
    --role-name "$EC2_ROLE" \
    --policy-name "cv-ec2-s3-read-policy" \
    --region "$REGION"

# 6. Lambda role permissions
echo "===== 6. LAMBDA IAM POLICY =====" >> "$OUTPUT"
run_command aws iam get-role-policy \
    --role-name "$LAMBDA_ROLE" \
    --policy-name "cv-lambda-s3-read-policy" \
    --region "$REGION"

# 7. EC2 security group
echo "===== 7. EC2 SECURITY GROUP =====" >> "$OUTPUT"
run_command aws ec2 describe-instances \
    --instance-ids "$INSTANCE_ID" \
    --query 'Reservations[].Instances[].{InstanceId:InstanceId,State:State.Name,SecurityGroups:SecurityGroups,MetadataOptions:MetadataOptions}' \
    --output json --region "$REGION"

# 8. EC2 instance details
echo "===== 8. EC2 INSTANCE =====" >> "$OUTPUT"
run_command aws ec2 describe-instances \
    --instance-ids "$INSTANCE_ID" \
    --query 'Reservations[].Instances[].{InstanceId:InstanceId,InstanceType:InstanceType,PublicIpAddress:PublicIpAddress,IamInstanceProfile:IamInstanceProfile,Tags:Tags}' \
    --output json --region "$REGION"

# 9. Website endpoints
echo "===== 9. WEBSITE ENDPOINTS =====" >> "$OUTPUT"
echo "EC2 address: $EC2_ADDRESS" >> "$OUTPUT"
echo "Lambda address: $LAMBDA_ADDRESS" >> "$OUTPUT"
echo "" >> "$OUTPUT"

echo "Testing EC2 website..." >> "$OUTPUT"
curl -sS -o /dev/null -w "HTTP status: %{http_code}\n" \
    --max-time 15 "$EC2_ADDRESS" >> "$OUTPUT" 2>&1
if [ "$?" -ne 0 ]; then
    echo "NOTE: EC2 website request failed." >> "$OUTPUT"
fi

echo "" >> "$OUTPUT"
echo "Testing Lambda website..." >> "$OUTPUT"
curl -sS -o /dev/null -w "HTTP status: %{http_code}\n" \
    --max-time 15 "$LAMBDA_ADDRESS" >> "$OUTPUT" 2>&1
if [ "$?" -ne 0 ]; then
    echo "NOTE: Lambda website request failed." >> "$OUTPUT"
fi
echo "" >> "$OUTPUT"

# 10. Lambda logs
echo "===== 10. LAMBDA LOGS =====" >> "$OUTPUT"
run_command aws logs describe-log-streams \
    --log-group-name "/aws/lambda/$LAMBDA_FUNCTION" \
    --order-by LastEventTime --descending --limit 1 \
    --region "$REGION"

# 11. CloudWatch log retention
echo "===== 11. LOG RETENTION =====" >> "$OUTPUT"
run_command aws logs describe-log-groups \
    --log-group-name-prefix "/aws/lambda/$LAMBDA_FUNCTION" \
    --query 'logGroups[].{LogGroupName:logGroupName,RetentionInDays:retentionInDays}' \
    --output json --region "$REGION"

echo "Evidence collection finished. See $OUTPUT"
echo "DONE"