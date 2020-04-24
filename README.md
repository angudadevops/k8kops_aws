# This repository help you to install k8's on AWS with kops

## Prerequisites
- AWS access key
- AWS secret access key

## Platforms supported
- Linux 
- MacOs 

## Usage

Download or clone to your system

```
git clone https://github.com/angudadevops/k8kops_aws.git
```

Now run the below command help you to install k8's on AWS, as script will require some inputs
- AWS access key
- AWS secret key
- AWS Region for k8's
  - Note: Currently automation supports for us-west-2, will fix soon for other Regions
- K8's clsuter name
  - Note: Here you use gosip cluster which doesn't require any route53, but you want to use route53 you use as cluster name

```
bash kops.sh
```

When you run the script below AWS resources will created for Kops
- autoscaling-group
- autoscaling-config
- dhcp-options
- iam-instance-profile
- iam-role
- internet-gateway
- instance
- keypair
- load-balancer
- route-table
- security-group
- subnet
- volumes
- vpc

### CleanUP

If you want to cleanup everything that got created with above steps, please run the below command

```
bash cleanup
```
