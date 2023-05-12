# Sample Django Application on AWS

## Pre-requisites
- Docker
- Python
- AWS CLI
- AWS Account

## Steps to deploy
1. Login via AWS CLI
2. Create CodeCommit Repository
3. Update parameters in deployment/parameters.json
4. Build image and upload image to ECR by running the following command
```bash
ECR_REPO_NAME=<repo-name> ./build.sh ecr_build
```
5. Create CloudFormation Stack by running the following command
```bash
CFN_STACK_NAME=<stack-name> ./build.sh cfn_create
```

## Steps to destroy
Go to CloudFormation Console and delete the stack

_Do note that this might fail as s3 bucket will need to be emptied first_
