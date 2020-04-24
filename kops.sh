#! /bin/bash 
set -e env

u=$(uname)

awsregions () {

li=$(aws ec2 describe-regions --output text | cut -f4 | sort)
echo -e "AWS valid Regions\n$li"
}

awsclimac() {
if ! hash aws 2>/dev/null
then
    echo "aws was not installed"
    curl "https://awscli.amazonaws.com/AWSCLIV2.pkg" -o "AWSCLIV2.pkg"
    sudo installer -pkg AWSCLIV2.pkg -target /
else
    echo "AWS ClI already installed"
fi
}

awsclilinux () {
if ! hash aws 2>/dev/null
then
	echo "AWS not installed"
	curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
        unzip awscliv2.zip
        sudo ./aws/install
else
	echo "AWS CLI already installed"
fi

}

awsconfigure() {
if [ -f $HOME/.aws/credentials ]; then
echo "Awc credentails already available at $HOME/.aws/credentials"
else 
# Use your new access and secret key here
aws configure
fi
# you should see a list of all your IAM users here
aws iam list-users

# Because "aws configure" doesn't export these vars for kops to use, we export them now
export AWS_ACCESS_KEY_ID=$(aws configure get aws_access_key_id)
export AWS_SECRET_ACCESS_KEY=$(aws configure get aws_secret_access_key)

iam=$(aws iam get-group --group-name kops | jq -r '.Group.GroupName' | tr -d '\n')
if [[ $iam == "kops" ]]; then
	echo "IAM Roles already exists for Kops"
else

aws iam create-group --group-name kops

aws iam attach-group-policy --policy-arn arn:aws:iam::aws:policy/AmazonEC2FullAccess --group-name kops
aws iam attach-group-policy --policy-arn arn:aws:iam::aws:policy/AmazonRoute53FullAccess --group-name kops
aws iam attach-group-policy --policy-arn arn:aws:iam::aws:policy/AmazonS3FullAccess --group-name kops
aws iam attach-group-policy --policy-arn arn:aws:iam::aws:policy/IAMFullAccess --group-name kops
aws iam attach-group-policy --policy-arn arn:aws:iam::aws:policy/AmazonVPCFullAccess --group-name kops

aws iam create-user --user-name kops

aws iam add-user-to-group --user-name kops --group-name kops

aws iam create-access-key --user-name kops
fi
}


awsstorage() {
echo $1
bu=$(aws s3api list-buckets | jq -r '.Buckets[].Name' | grep "prefix-kops-k8s-local-state-store" | tr -d '\n')
if [[ $bu == "prefix-kops-k8s-local-state-store" ]]; then
	echo "Kops S3 bucket already exists"
else
	if [[ $1 == "us-east-1" ]]; then
		aws s3api create-bucket --bucket prefix-kops-k8s-local-state-store --region us-east-1
		#Cluster State storage
		aws s3api put-bucket-versioning --bucket prefix-kops-k8s-local-state-store  --versioning-configuration Status=Enabled
		#Using S3 default bucket encryption
		aws s3api put-bucket-encryption --bucket prefix-kops-k8s-local-state-store --server-side-encryption-configuration '{"Rules":[{"ApplyServerSideEncryptionByDefault":{"SSEAlgorithm":"AES256"}}]}'
	else

		aws s3api create-bucket --bucket prefix-kops-k8s-local-state-store --create-bucket-configuration LocationConstraint=$1
		#Cluster State storage
		aws s3api put-bucket-versioning --bucket prefix-kops-k8s-local-state-store  --versioning-configuration Status=Enabled
		#Using S3 default bucket encryption
		aws s3api put-bucket-encryption --bucket prefix-kops-k8s-local-state-store --server-side-encryption-configuration '{"Rules":[{"ApplyServerSideEncryptionByDefault":{"SSEAlgorithm":"AES256"}}]}'
	fi
fi
}

kop() {
read -p "Do you need HA K8's Cluster y or n? " ha
if [[ $ha == "y" ]]; then
	zones=$(aws ec2 describe-availability-zones --region $1 | jq -r '.AvailabilityZones[].ZoneName' | wc -l)
        if [[ $zones == 3 ]] || [[ $zones -gt 3 ]]; then
		zonelist=$(aws ec2 describe-availability-zones --region $1 | jq -r '.AvailabilityZones[].ZoneName' | head -n 3 | tr '\n' ',' | sed 's/.$//')
		echo $zonelist
		kops create cluster --node-count 3 --zones $zonelist --master-zones $zonelist --node-size t3a.xlarge --master-size t2.medium $2
		kops update cluster $2 --yes
	else
		echo "$1 doesn't have 3 AZ's"
        fi
else
                echo "one cluster"
		zonelist=$(aws ec2 describe-availability-zones --region $1 | jq -r '.AvailabilityZones[].ZoneName' | head -n 1 | tr -d '\n')
		echo $zonelist
		kops create cluster --zones $zonelist $2
		kops update cluster $2 --yes
fi
}

addons() {

kubectl create -f https://raw.githubusercontent.com/kubernetes/dashboard/v2.0.0/aio/deploy/recommended.yaml
kubectl apply -f dashboard.yaml -n kubernetes-dashboard
secs=$((3 * 60))
while [ $secs -gt 0 ]; do
   echo -ne "$secs\033[0K\r"
   sleep 1
   : $((secs--))
done
nohup kubectl proxy --address='0.0.0.0' --accept-hosts='^*$' </dev/null >/dev/null 2>&1 &
echo "Access Kubernetes Dashboard using http://localhost:8001/api/v1/namespaces/kubernetes-dashboard/services/https:kubernetes-dashboard:/proxy/"
tok=$(kubectl -n kubernetes-dashboard describe secret $(kubectl -n kubernetes-dashboard get secret | grep admin-user | awk '{print $1}') | grep token: | awk '{print $2}')
echo -e "Use this token to access dashbard\n$tok"

}

if [[ $u == "Darwin" ]]; then
        if ! hash brew 2>/dev/null
	then
    		echo "brew package was not found, installing"
		/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/master/install.sh)"
	else 
                echo "Brew already installed on MAC"
		if [[ `brew list|grep kops` == "kops" ]] ; then
			echo "Kops already installed on Mac"
		else
			brew update && brew install kops
		fi
	fi
	awsclimac
	#awsregions
	read -p "AWS k8's region, currently supports us-west-2: " reg
	awsconfigure $reg
	awsstorage $reg
	
	echo "Enter Cluster name like domain or subdomain or for gossip based cluster use like 'kops.k8s.local'"
	read -p "Cluster Name: " name

	export NAME=$name
	export KOPS_STATE_STORE=s3://prefix-kops-k8s-local-state-store
       
        if [ ! -f $HOME/.ssh/id_rsa.pub ]; then	
        	ssh-keygen
	fi	
	kop $reg $NAME
        secs=$((6 * 60))
   	while [ $secs -gt 0 ]; do
      		echo -ne "$secs\033[0K\r"
      		sleep 1
      		: $((secs--))
   	done
        addons
	echo "export KOPS_STATE_STORE=s3://prefix-kops-k8s-local-state-store"
else
        if ! hash kops 2>/dev/null
        then
	    wget https://github.com/kubernetes/kops/releases/download/v1.16.1/kops-linux-amd64
	    chmod +x kops-linux-amd64
	    sudo mv kops-linux-amd64 /usr/local/bin/kops
        fi
        awsclilinux
	#awsregions
	read -p "AWS k8's region, currently supports us-west-2: " reg
	awsconfigure $reg
	awsstorage $reg
	
        echo "Enter Cluster name like domain or subdomain or for gossip based cluster use like 'kops.k8s.local'"
        read -p "Cluster Name: " name

        export NAME=$name
        export KOPS_STATE_STORE=s3://prefix-kops-k8s-local-state-store

	kop $reg $NAME
        secs=$((6 * 60))
        while [ $secs -gt 0 ]; do
                echo -ne "$secs\033[0K\r"
                sleep 1
                : $((secs--))
        done
        addons
	echo "export KOPS_STATE_STORE=s3://prefix-kops-k8s-local-state-store"
fi
