#!/bin/bash 
#set -e env

read -p "Are you sure you want to cleanup k8s on AWS y or n? " clean

if [[ $clean == "y" ]]; then
echo "Deleting the k8s cluster on AWS"

kops delete cluster --name $(kops get clusters | awk '{print $1}' | grep -v NAME)

kops delete cluster --name $(kops get clusters | awk '{print $1}' | grep -v NAME) --yes 

echo "Removing the IAM Roles for kops"
aws iam remove-user-from-group --user-name kops --group-name kops
aws iam detach-group-policy --policy-arn arn:aws:iam::aws:policy/AmazonEC2FullAccess --group-name kops
aws iam detach-group-policy --policy-arn arn:aws:iam::aws:policy/AmazonRoute53FullAccess --group-name kops
aws iam detach-group-policy --policy-arn arn:aws:iam::aws:policy/AmazonS3FullAccess --group-name kops
aws iam detach-group-policy --policy-arn arn:aws:iam::aws:policy/IAMFullAccess --group-name kops
aws iam detach-group-policy --policy-arn arn:aws:iam::aws:policy/AmazonVPCFullAccess --group-name kops

aws iam delete-group --group-name kops

for line in `aws iam list-access-keys --user-name kops | jq -r '.AccessKeyMetadata[].AccessKeyId'`; do aws iam delete-access-key --access-key-id $line --user-name kops; done

aws iam delete-user --user-name kops

echo "Removing the S3 storage for kops"

aws s3api list-object-versions --bucket prefix-kops-k8s-local-state-store

aws s3api delete-objects --bucket prefix-kops-k8s-local-state-store --delete "$(aws s3api list-object-versions --bucket prefix-kops-k8s-local-state-store | jq '{Objects: [.Versions[] | {Key:.Key, VersionId : .VersionId}], Quiet: false}')"

aws s3api delete-objects --bucket prefix-kops-k8s-local-state-store --delete "$(aws s3api list-object-versions --bucket prefix-kops-k8s-local-state-store | jq '{Objects: [.DeleteMarkers[] | {Key:.Key, VersionId : .VersionId}], Quiet: false}')"

aws s3api delete-bucket --bucket prefix-kops-k8s-local-state-store

echo "Deleted everything for kops"

else
	echo "You don't want to cleanup k8's on AWS"
fi
