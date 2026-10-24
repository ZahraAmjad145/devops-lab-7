# Lab 7 — Basic App Deployment on AWS

**Name:** Zahra Amjad  
**Roll Number:** 23L-3072  
**Course:** DevOps  
**AWS Region:** Asia Pacific (Sydney) — `ap-southeast-2`

## 1. Project Overview

This project deploys a CV website using Amazon S3, Amazon EC2, and AWS Lambda.

Amazon S3 privately stores the website files. EC2 retrieves these files and serves them through Apache. AWS Lambda retrieves the requested files from S3 and returns them through a public Function URL.

## 2. Architecture

```text
                 Website Visitor
                  /            \
                 v              v
           EC2 Public IP    Lambda Function URL
                 |              |
                 v              v
           Apache Server    Lambda Function
                 |              |
                 v              v
                 +------+-------+
                        |
                        v
                Private S3 Bucket
                  cv-23l-3072
                        |
                    site/
                 /      |      \
           index.html style.css cv.pdf
```

Both EC2 and Lambda access S3 independently using their respective IAM roles.

## 3. EC2 Deployment

1. A visitor opens the EC2 public IP address.
2. Apache serves the website from `/var/www/html`.
3. The EC2 instance uses its attached IAM role to retrieve website files from the private S3 bucket.
4. The synchronization script replaces `{{HOSTED_ON}}` with the EC2 instance identifier.
5. A cron job is configured to run the synchronization script every five minutes.

**Website:** http://13.236.10.132

**Instance ID:** `i-069dc3d4ef86ff3d1`

**Instance type:** `t3.micro`

## 4. Lambda Deployment

1. A visitor opens the Lambda Function URL.
2. The function identifies the requested path.
3. It retrieves the corresponding file from S3 using its execution role.
4. It returns HTML, CSS, or PDF with the appropriate content type.
5. Unknown paths return HTTP 404.
6. The function records request information in CloudWatch Logs.

**Function name:** `cv-lambda-23l-3072`

**Function URL:** https://7vap3zbuz42wq5tx5rejfns75a0hkirq.lambda-url.ap-southeast-2.on.aws/

## 5. S3 Storage and Security

The S3 bucket is named `cv-23l-3072`.

The bucket is configured to remain private, with all four Block Public Access settings enabled and versioning enabled.

The website files are stored under `site/`:

- `site/index.html`
- `site/style.css`
- `site/cv.pdf`

The website is served through EC2 and Lambda rather than by making the S3 bucket public.

### Direct S3 Access

Unauthenticated requests to private S3 objects should be denied unless another applicable permission grants access. S3 Block Public Access helps prevent public access, while IAM policies determine which AWS identities can access permitted resources.

## 6. IAM Roles

### EC2 Role

**Role:** `cv-ec2-role-23l-3072`

The role permits `s3:GetObject` on objects under `site/` and `s3:ListBucket` on the bucket, restricted to the `site/` prefix.

### Lambda Role

**Role:** `cv-lambda-role-23l-3072`

The role includes `AWSLambdaBasicExecutionRole` for CloudWatch logging and a custom policy allowing `s3:GetObject` on objects under `site/`.

The application code and user-data script do not require embedded AWS access keys. IAM roles provide service credentials without storing long-term access keys in these files.

## 7. EC2 Synchronization

The synchronization script is located at:

`ec2/sync-cv.sh`

It synchronizes website files from S3 to `/var/www/html` and replaces the hosting placeholder in the HTML file.

A cron job is configured to run the script every five minutes. The script is intended to record synchronization results in:

`/var/log/cv-sync.log`

## 8. Lambda Logging and Monitoring

**CloudWatch log group:**

`/aws/lambda/cv-lambda-23l-3072`

**Log retention:** 7 days

The function is designed to record JSON request logs containing the function name, requested path, HTTP status code, and execution time in milliseconds.

## 9. Questions and Answers

### Q1. Why are IAM roles preferred over access keys, and what can go wrong if keys are placed in user data?

IAM roles provide temporary credentials to authorized AWS services without requiring long-term access keys in application files. Access keys stored in user data may be exposed to people or processes that can access instance configuration or related logs. An attacker could misuse exposed credentials to access AWS resources. IAM roles reduce the need to store and manage long-term credentials.

### Q2. What happens when the S3 object URL is opened directly, and which setting helps prevent public access?

An unauthenticated visitor should receive an Access Denied response for a private object. S3 Block Public Access helps prevent public access through public bucket policies and ACLs. The EC2 and Lambda roles can retrieve permitted objects through their IAM permissions. Keeping the bucket private prevents visitors from bypassing the intended application endpoints.

### Q3. Why is a public Lambda Function URL acceptable here, but a public S3 bucket is not?

The public Function URL exposes a controlled application endpoint that returns responses implemented by the function. The function accesses S3 through its restricted execution role. A public bucket could allow direct access to stored objects, bypassing the application logic. Therefore, the bucket remains private while the intended application endpoints are publicly accessible.

### Q4. What costs may occur while the application is idle, and what could happen if traffic increases 100 times?

A running EC2 instance can incur compute charges even when idle. S3 storage and requests, CloudWatch logging, and data transfer may also incur charges. Lambda costs can increase with the number and duration of function executions. A hundredfold increase in traffic may increase requests, execution time, data transfer, and logging costs, depending on usage and applicable credits or free-tier allowances.

### Q5. What is lost if the EC2 instance is deleted, and what remains?

Deleting the EC2 instance removes the instance and its associated local state and installed software. The S3 bucket and its objects remain unless separately deleted. The Lambda function, IAM roles, and CloudWatch log group also remain until separately removed. Resources must be deleted individually when cleaning up the deployment.

## 10. Evidence Collection

The repository includes `collect-evidence.sh`, a script designed to collect AWS configuration details, IAM policies, S3 settings, endpoint checks, and Lambda logging information into `evidence.txt`.

The script accepts three arguments: the bucket name, EC2 address, and Lambda Function URL.

Example:

./collect-evidence.sh cv-23l-3072 http://13.236.10.132 https://7vap3zbuz42wq5tx5rejfns75a0hkirq.lambda-url.ap-southeast-2.on.aws/
