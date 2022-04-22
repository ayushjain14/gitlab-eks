# Amazon Web Services

Export global variables

```shell
export AWS_PROFILE=<MY_PROFILE>
export AWS_ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
export AWS_REGION=eu-west-1
export EKS_CLUSTER_NAME="devops"
export R53_HOSTED_ZONE_ID=<R53_HOSTED_ZONE_ID>
export ACM_GITLAB_ARN=<ACM_GITLAB_ARN>
export CERTMANAGER_ISSUER_EMAIL=<CERTMANAGER_ISSUER_EMAIL>
export PUBLIC_DNS_NAME=<PUBLIC_DNS_NAME>
export TERRAFORM_BUCKET_NAME=bucket-${AWS_ACCOUNT_ID}-${AWS_REGION}-terraform-backend
```

Create s3 bucket for terraform states

```shell
# Create bucket
aws s3api create-bucket \
     --bucket $TERRAFORM_BUCKET_NAME \
     --region $AWS_REGION \
     --create-bucket-configuration LocationConstraint=$AWS_REGION

# Make it not public     
aws s3api put-public-access-block \
    --bucket $TERRAFORM_BUCKET_NAME \
    --public-access-block-configuration "BlockPublicAcls=true,IgnorePublicAcls=true,BlockPublicPolicy=true,RestrictPublicBuckets=true"

# Enable versioning
aws s3api put-bucket-versioning \
    --bucket $TERRAFORM_BUCKET_NAME \
    --versioning-configuration Status=Enabled
```

Initialize AWS security infrastructure. The states will be saved in AWS.

```shell
cd infra/plan
terraform init \
    -backend-config="bucket=$TERRAFORM_BUCKET_NAME" \
    -backend-config="key=devops/gitlab/terraform-state" \
    -backend-config="region=$AWS_REGION"
```

Complete `plan/terraform.tfvars` and run 

```shell
sed -i "s/<LOCAL_IP_RANGES>/$(curl -s http://checkip.amazonaws.com/)\/32/g; s/<PUBLIC_DNS_NAME>/${PUBLIC_DNS_NAME}/g; s/<AWS_ACCOUNT_ID>/${AWS_ACCOUNT_ID}/g; s/<AWS_REGION>/${AWS_REGION}/g; s/<EKS_CLUSTER_NAME>/${EKS_CLUSTER_NAME}/g; s,<ACM_GITLAB_ARN>,${ACM_GITLAB_ARN},g; s/<CERTMANAGER_ISSUER_EMAIL>/${CERTMANAGER_ISSUER_EMAIL}/g;" terraform.tfvars
terraform apply
```

Access the EKS Cluster using

```shell
aws eks --region $AWS_REGION update-kubeconfig --name $EKS_CLUSTER_NAME
kubectl config set-context --current --namespace=gitlab
```

Get Gitlab password

```shell
kubectl get secret gitlab-gitlab-initial-root-password \
     -o go-template='{{.data.password}}' | base64 -d && echo
```
terr
To deploy the Amazon EBS CSI driver, run one of the following commands based on your AWS Region:

```shell
kubectl apply -k "github.com/kubernetes-sigs/aws-ebs-csi-driver/deploy/kubernetes/overlays/stable/?ref=master"
```

Annotate the ebs-csi-controller-sa Kubernetes service account with the ARN of the IAM role that you created in terraform:

```shell
kubectl annotate serviceaccount ebs-csi-controller-sa \
  -n kube-system \
  eks.amazonaws.com/role-arn=arn:aws:iam::$AWS_ACCOUNT_ID:role/AmazonEKS_EBS_CSI_DriverRole
```

Delete the driver pods:

```shell
kubectl delete pods \
  -n kube-system \
  -l=app=ebs-csi-controller
```

> Note: The driver pods are automatically redeployed with the IAM permissions from the IAM policy assigned to the role. For more information, see Amazon EBS CSI driver.

# Documentation

* https://cloud.google.com/architecture/deploying-production-ready-gitlab-on-gke
* https://docs.gitlab.com/charts/advanced/external-object-storage/aws-iam-roles.html
* https://aws.amazon.com/premiumsupport/knowledge-center/eks-persistent-storage/