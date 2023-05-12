#!/bin/bash

# -e: Exit on first failure
# -E (-o errtrace): Ensures that ERR traps get inherited by functions and subshells.
# -u (-o nounset): Treats unset variables as errors.
# -o pipefail: This option will propagate intermediate errors when using pipes.
set -Eeo pipefail

script_name="$(basename -- "$0")"
script_dir="$(dirname "$0")"

trap err_exit ERR

err_exit () {
	echo "echo ⚠️ Something went wrong! Tidying up..."
	exit 1
}

help_text()
{
    echo ""
    echo "Helper script to create Cloudformation Infrastructure."
    echo ""
    echo "⚠️  This must be run from the root of the repository."
    echo ""
    echo "Usage:        $script_dir/$script_name <COMMAND>"
    echo ""
    echo "Example:      'CFN_STACK_NAME=sample_name $script_dir/$script_name cfn_create'"
    echo ""
    echo "Available Commands:"
    echo "  cfn_create          🚀️ Run Cloudformation to create AWS infrastructure"
    echo "  cfn_update          🔃 Run Cloudformation to update AWS infrastructure"
    echo "  cfn_build           👷 Run Cloudformation to delete AWS infrastructure"
    echo "  cfn_destroy         💥 Run Cloudformation to destroy AWS infrastructure"
}

set_env_variables() {
  export CFN_TEMPLATES_S3_BUCKET_NAME=cloudre01-cfn-templates
	export CFN_DIR="./deployment"
	export CFN_PARENT_TEMPLATE_FILE="${CFN_DIR}/parent-stack.yml"
	export CFN_PACKAGED_TEMPLATE_FILE="${CFN_DIR}/nested-stacks.yml"
	export CFN_PARAMETERS_FILE="${CFN_DIR}/parameters.json"
	export CFN_TAG_NAME="Alex-Dev-Stack"
	export CFN_TAG_EMAIL="alextan01@hotmail.com"
	export CURRENT_DATETIME="$(date +%F_%T)"

	if [[ -z $CFN_STACK_NAME ]]; then
    export CFN_STACK_NAME="DJ-stack"
  fi

  if [[ -z $ECR_REPO_NAME ]]; then
    export ECR_REPO_NAME="alex-repo"
  fi
}

cfn_package() {
	# Packaging nested CloudFormation templates
	aws cloudformation package \
		--template-file ${CFN_PARENT_TEMPLATE_FILE} \
		--output-template ${CFN_PACKAGED_TEMPLATE_FILE} \
		--s3-bucket ${CFN_TEMPLATES_S3_BUCKET_NAME}
}

create_ecr() {
  if aws ecr describe-repositories --repository-names ${ECR_REPO_NAME} || aws ecr create-repository --repository-name ${ECR_REPO_NAME} --region ${AWS_DEFAULT_REGION}
  then
    echo "ECR repository ${ECR_REPO_NAME} already exists."
    echo "Skipping creation of ECR repository."
  else
    echo "Creating ECR repository ${ECR_REPO_NAME}..."
    aws ecr create-repository --repository-name ${ECR_REPO_NAME} --region ${AWS_DEFAULT_REGION}
  fi
}

check_docker() {
  if ! [ -x "$(command -v docker)" ]; then
    echo "Docker is not installed/initialized. Please install/initialize docker first."
    exit 1
  fi
}

cfn_build(){
  aws ecr-public get-login-password --region us-east-1 | docker login -u AWS \
    --password-stdin public.ecr.aws

  AWS_ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
  AWS_DEFAULT_REGION=$(aws configure get region)

  ECR_MAIN_URI="${AWS_ACCOUNT_ID}.dkr.ecr.${AWS_DEFAULT_REGION}.amazonaws.com"

  create_ecr

  aws ecr get-login-password --region ${AWS_DEFAULT_REGION} | docker login -u AWS --password-stdin ${ECR_MAIN_URI}
  CODEBUILD_RESOLVED_SOURCE_VERSION=$(git rev-parse HEAD)
  ECR_IMAGE_URI="${ECR_MAIN_URI}/${ECR_REPO_NAME}:${CODEBUILD_RESOLVED_SOURCE_VERSION:0:8}"

  docker build -t score-app:latest .

  docker tag score-app:latest ${ECR_IMAGE_URI}
  docker push ${ECR_IMAGE_URI}

  echo ""
  echo "🚀️  Image pushed to ECR."
  echo "➕  Add this image URI to deployment parameters file ${ECR_IMAGE_URI}"
  echo ""
}

cfn_create() {
	aws cloudformation create-stack \
		--stack-name=${CFN_STACK_NAME} \
		--template-body=file://"${CFN_PACKAGED_TEMPLATE_FILE}" \
		--parameters file://"${CFN_PARAMETERS_FILE}" \
		--tags "Key"="Name","Value"=\"${CFN_TAG_NAME}\" \
			   "Key"="Modified_Date","Value"="${CURRENT_DATETIME}" \
			   "Key"="Email","Value"="${CFN_TAG_EMAIL}" \
		--capabilities=CAPABILITY_NAMED_IAM
}

cfn_update() {
	aws cloudformation update-stack \
		--stack-name=${CFN_STACK_NAME} \
		--template-body=file://"${CFN_PACKAGED_TEMPLATE_FILE}" \
		--parameters file://"${CFN_PARAMETERS_FILE}" \
		--tags "Key"="Name","Value"=\"${CFN_TAG_NAME}\" \
			   "Key"="Modified_Date","Value"="${CURRENT_DATETIME}" \
			   "Key"="Email","Value"="${CFN_TAG_EMAIL}" \
		--capabilities=CAPABILITY_NAMED_IAM
}

cfn_init() {
  # Create S3 bucket for CloudFormation templates
  if aws s3 ls "s3://$S3_BUCKET" 2>&1 | grep -q ${CFN_TEMPLATES_S3_BUCKET_NAME}
  then
    echo "S3 bucket ${CFN_TEMPLATES_S3_BUCKET_NAME} already exists."
    echo "Skipping creation of S3 bucket."
  else
    echo "Creating S3 bucket ${CFN_TEMPLATES_S3_BUCKET_NAME}..."
    aws s3 mb s3://${CFN_TEMPLATES_S3_BUCKET_NAME}
  fi
}

cfn_query() {
  # Query CloudFormation stack to get postgres endpoint
  aws cloudformation describe-stacks \
    --stack-name=${CFN_STACK_NAME} | jq -r '.Stacks[0].Outputs[0].OutputValue'
}

cfn_destroy() {
	aws cloudformation delete-stack --stack-name=${CFN_STACK_NAME}
}

wait_for_stack_status() {

	status_in_progress=$1
	status_complete=$2

	get_stack_status() {
		status=$(aws cloudformation describe-stacks \
				--stack-name=${CFN_STACK_NAME} | jq -r '.Stacks[0].StackStatus' 2>/dev/null || true)
		if [[ -z $status ]]; then
			# empty status, i.e stack does not exist (likely deleted)
			echo ""
		else
			echo $status
		fi;
	}

	until [[ $(get_stack_status) != $status_in_progress ]];
	do
		echo "🕵️‍♂️  Current stack status: $status_in_progress..."
		sleep 30
	done

	until [[ $(get_stack_status) != "UPDATE_COMPLETE_CLEANUP_IN_PROGRESS" ]];
	do
		echo "🕵️‍♂️  Clean up operation in progress (UPDATE_COMPLETE_CLEANUP_IN_PROGRESS)..."
		sleep 30
	done

	if [[ $status_complete == $(get_stack_status) || $status_complete == "DELETE_COMPLETE" ]]; then
		# Expected complete status was reached, or
		# Stack Deletion case: could not retrieve status because the stack does not exist (deleted). All good.
		echo "✅  Stack operation complete!"
		exit 0
	fi

	echo "❌  Oops, something went wrong during stack operation!"
	exit 1
}

# Script starting point
if [[ -n $1 ]]; then
	set_env_variables
	case "$1" in
		cfn_create)
			printf "👷‍♂️  Run Cloudformation to create AWS infrastructure...\n"
			cfn_init
			cfn_package
			cfn_create
			wait_for_stack_status "CREATE_IN_PROGRESS" "CREATE_COMPLETE"
			exit 0
			;;
    cfn_update)
			printf "🔃 	Run Cloudformation to update AWS infrastructure...\n"
			cfn_package
			cfn_update
			wait_for_stack_status "UPDATE_IN_PROGRESS" "UPDATE_COMPLETE"
			exit 0
			;;
	  cfn_build)
	    printf "👷‍♂️  Build docker image and push to ECR...\n"
      check_docker
	    cfn_build
	    exit 0
	    ;;
    cfn_destroy)
			printf "💥  Run Cloudformation to destroy AWS infrastructure...\n"
			cfn_destroy
			wait_for_stack_status "DELETE_IN_PROGRESS" "DELETE_COMPLETE"
			exit 0
			;;
    help)
      help_text
      exit 0
      ;;
		*)
			echo "¯\\_(ツ)_/¯ What do you mean \"$1\"?"
			help_text
			exit 1
			;;
	esac
else
	help_text
	exit 1
fi
