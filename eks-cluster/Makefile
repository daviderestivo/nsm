CLUSTER_NAME ?= nsm-test
REGION ?= eu-central-2
NODE_COUNT ?= 4
NSM_VERSION ?= v1.14.0

# IAM role names
CLUSTER_ROLE_NAME = EKS-Cluster-Role
NODEGROUP_ROLE_NAME = EKS-NodeGroup-Role
EBS_CSI_ROLE_NAME = EKS-EBS-CSI-Role

# AWS managed policy ARNs
EKS_CLUSTER_POLICY = arn:aws:iam::aws:policy/AmazonEKSClusterPolicy
EKS_WORKER_NODE_POLICY = arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy
EKS_CNI_POLICY = arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy
ECR_READ_ONLY_POLICY = arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly
EBS_CSI_POLICY = arn:aws:iam::aws:policy/service-role/AmazonEBSCSIDriverPolicy

# Common AWS CLI options
AWS_OUTPUT = --output text > /dev/null

.PHONY: create-roles create-cluster create-oidc-provider create-nodegroup install-addons install-nsm setup-storage all clean clean-nsm

all: create-roles create-cluster create-oidc-provider create-nodegroup install-addons install-nsm setup-storage

create-roles:
	@echo "Creating IAM roles..."
	-aws iam create-role --role-name $(CLUSTER_ROLE_NAME) --assume-role-policy-document file://eks-cluster-role-trust.yaml $(AWS_OUTPUT)
	-aws iam attach-role-policy --role-name $(CLUSTER_ROLE_NAME) --policy-arn $(EKS_CLUSTER_POLICY)
	-aws iam create-role --role-name $(NODEGROUP_ROLE_NAME) --assume-role-policy-document file://eks-nodegroup-role-trust.yaml $(AWS_OUTPUT)
	-aws iam attach-role-policy --role-name $(NODEGROUP_ROLE_NAME) --policy-arn $(EKS_WORKER_NODE_POLICY)
	-aws iam attach-role-policy --role-name $(NODEGROUP_ROLE_NAME) --policy-arn $(EKS_CNI_POLICY)
	-aws iam attach-role-policy --role-name $(NODEGROUP_ROLE_NAME) --policy-arn $(ECR_READ_ONLY_POLICY)
	-aws iam create-role --role-name $(EBS_CSI_ROLE_NAME) --assume-role-policy-document file://eks-ebs-csi-role-trust.yaml $(AWS_OUTPUT)
	-aws iam attach-role-policy --role-name $(EBS_CSI_ROLE_NAME) --policy-arn $(EBS_CSI_POLICY)

create-cluster:
	@echo "Creating EKS cluster..."
	@SUBNET_IDS=$$(aws ec2 describe-subnets --filters "Name=default-for-az,Values=true" --query 'Subnets[].SubnetId' --output text --region $(REGION) | tr '\t' ','); \
	echo "Using subnets: $$SUBNET_IDS"; \
	aws eks create-cluster \
		--name $(CLUSTER_NAME) \
		--role-arn $$(aws iam get-role --role-name $(CLUSTER_ROLE_NAME) --query 'Role.Arn' --output text) \
		--resources-vpc-config subnetIds=$$SUBNET_IDS \
		--region $(REGION) \
		$(AWS_OUTPUT) || { echo "Cluster creation failed"; exit 1; }
	@echo "Waiting for cluster to become active..."
	aws eks wait cluster-active --name $(CLUSTER_NAME) --region $(REGION)

create-oidc-provider:
	@echo "Creating OIDC provider for EKS cluster..."
	@OIDC_URL=$$(aws eks describe-cluster --name $(CLUSTER_NAME) --region $(REGION) --query 'cluster.identity.oidc.issuer' --output text); \
	echo "OIDC URL: $$OIDC_URL"; \
	aws iam create-open-id-connect-provider \
		--url $$OIDC_URL \
		--client-id-list sts.amazonaws.com \
		--thumbprint-list 9e99a48a9960b14926bb7f3b02e22da2b0ab7280 \
		--output text > /dev/null 2>&1 || echo "OIDC provider already exists"
	@echo "Recreating EBS CSI role with OIDC provider..."
	-aws iam detach-role-policy --role-name $(EBS_CSI_ROLE_NAME) --policy-arn $(EBS_CSI_POLICY)
	-aws iam delete-role --role-name $(EBS_CSI_ROLE_NAME)
	aws iam create-role --role-name $(EBS_CSI_ROLE_NAME) --assume-role-policy-document file://eks-ebs-csi-role-trust.yaml.personal $(AWS_OUTPUT)
	aws iam attach-role-policy --role-name $(EBS_CSI_ROLE_NAME) --policy-arn $(EBS_CSI_POLICY)

create-nodegroup:
	@echo "Creating node group..."
	aws eks create-nodegroup \
		--cluster-name $(CLUSTER_NAME) \
		--nodegroup-name $(CLUSTER_NAME)-nodes \
		--node-role $$(aws iam get-role --role-name $(NODEGROUP_ROLE_NAME) --query 'Role.Arn' --output text) \
		--subnets $$(aws ec2 describe-subnets --filters "Name=default-for-az,Values=true" --query 'Subnets[].SubnetId' --output text --region $(REGION) | tr '\n' ' ') \
		--instance-types t3.medium \
		--scaling-config minSize=1,maxSize=6,desiredSize=$(NODE_COUNT) \
		--region $(REGION) \
		$(AWS_OUTPUT)
	@echo "Waiting for node group to become active..."
	aws eks wait nodegroup-active --cluster-name $(CLUSTER_NAME) --nodegroup-name $(CLUSTER_NAME)-nodes --region $(REGION)

install-addons:
	@echo "Installing VPC CNI addon..."
	aws eks create-addon --cluster-name $(CLUSTER_NAME) --addon-name vpc-cni --region $(REGION) $(AWS_OUTPUT)
	@echo "Installing EBS CSI driver addon..."
	aws eks create-addon --cluster-name $(CLUSTER_NAME) --addon-name aws-ebs-csi-driver \
		--service-account-role-arn $$(aws iam get-role --role-name $(EBS_CSI_ROLE_NAME) --query 'Role.Arn' --output text) \
		--region $(REGION) $(AWS_OUTPUT)

install-nsm:
	@echo "Installing Spire..."
	kubectl apply -k https://github.com/networkservicemesh/deployments-k8s/examples/spire/single_cluster?ref=$(NSM_VERSION)
	@echo "Waiting for Spire pods to be ready..."
	kubectl wait -n spire --timeout=4m --for=condition=ready pod -l app=spire-server
	kubectl wait -n spire --timeout=1m --for=condition=ready pod -l app=spire-agent
	@echo "Applying ClusterSPIFFEID configurations..."
	kubectl apply -f https://raw.githubusercontent.com/networkservicemesh/deployments-k8s/$(NSM_VERSION)/examples/spire/single_cluster/clusterspiffeid-template.yaml
	kubectl apply -f https://raw.githubusercontent.com/networkservicemesh/deployments-k8s/$(NSM_VERSION)/examples/spire/base/clusterspiffeid-webhook-template.yaml
	@echo "Installing Network Service Mesh..."
	kubectl apply -k https://github.com/networkservicemesh/deployments-k8s/examples/basic?ref=$(NSM_VERSION)
	kubectl wait -n nsm-system --for=condition=ready --timeout=3m pod -l app=admission-webhook-k8s

setup-storage:
	@echo "Configuring kubeconfig and storage..."
	aws eks update-kubeconfig --region $(REGION) --name $(CLUSTER_NAME)
	kubectl patch storageclass gp2 -p '{"metadata":{"annotations":{"storageclass.kubernetes.io/is-default-class":"true"}}}'

clean-nsm:
	@echo "Cleaning up NSM resources..."
	-kubectl delete crd clusterspiffeids.spire.spiffe.io
	-kubectl delete crd clusterfederatedtrustdomains.spire.spiffe.io
	-kubectl delete validatingwebhookconfiguration.admissionregistration.k8s.io/spire-controller-manager-webhook
	-kubectl delete ns spire
	-kubectl delete mutatingwebhookconfiguration nsm-mutating-webhook
	-kubectl delete ns nsm-system

clean:
	@echo "Deleting EKS addons..."
	-aws eks delete-addon --cluster-name $(CLUSTER_NAME) --addon-name aws-ebs-csi-driver --region $(REGION) $(AWS_OUTPUT)
	-aws eks delete-addon --cluster-name $(CLUSTER_NAME) --addon-name vpc-cni --region $(REGION) $(AWS_OUTPUT)
	@echo "Deleting node group..."
	-aws eks delete-nodegroup --cluster-name $(CLUSTER_NAME) --nodegroup-name $(CLUSTER_NAME)-nodes --region $(REGION) $(AWS_OUTPUT)
	-aws eks wait nodegroup-deleted --cluster-name $(CLUSTER_NAME) --nodegroup-name $(CLUSTER_NAME)-nodes --region $(REGION)
	@echo "Deleting EKS cluster..."
	-aws eks delete-cluster --name $(CLUSTER_NAME) --region $(REGION) $(AWS_OUTPUT)
	-aws eks wait cluster-deleted --name $(CLUSTER_NAME) --region $(REGION)
	@echo "Deleting IAM roles..."
	-aws iam detach-role-policy --role-name $(EBS_CSI_ROLE_NAME) --policy-arn $(EBS_CSI_POLICY)
	-aws iam delete-role --role-name $(EBS_CSI_ROLE_NAME)
	-aws iam detach-role-policy --role-name $(NODEGROUP_ROLE_NAME) --policy-arn $(EKS_WORKER_NODE_POLICY)
	-aws iam detach-role-policy --role-name $(NODEGROUP_ROLE_NAME) --policy-arn $(EKS_CNI_POLICY)
	-aws iam detach-role-policy --role-name $(NODEGROUP_ROLE_NAME) --policy-arn $(ECR_READ_ONLY_POLICY)
	-aws iam delete-role --role-name $(NODEGROUP_ROLE_NAME)
	-aws iam detach-role-policy --role-name $(CLUSTER_ROLE_NAME) --policy-arn $(EKS_CLUSTER_POLICY)
	-aws iam delete-role --role-name $(CLUSTER_ROLE_NAME)
	$(MAKE) clean-nsm
