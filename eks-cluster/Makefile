# Network Service Mesh on AWS EKS
#
# This Makefile automates the complete setup of Network Service Mesh (NSM) on Amazon EKS
# with enhanced error handling, validation, logging, and usability features.
#
# Quick Start:
#   make validate               # Check prerequisites
#   make plan                   # Preview deployment
#   make all                    # Deploy everything
#
# Management:
#   make status                 # Show cluster status
#   make clean-nsm              # Remove NSM only
#   make clean                  # Delete everything
#
# Individual Steps:
#   make create-roles           # Create IAM roles
#   make create-cluster         # Create EKS cluster
#   make create-oidc-provider   # Setup OIDC for IRSA
#   make create-nodegroup       # Create worker nodes
#   make install-addons         # Install AWS addons
#   make install-nsm            # Install NSM components
#   make setup-kubeconfig       # Configure kubectl access
#   make setup-storage          # Setup default storage
#
# For detailed help: make help

# Configuration
CLUSTER_NAME ?= nsm-test
REGION ?= eu-central-2
NODE_COUNT ?= 4
NSM_VERSION ?= v1.14.0
INSTANCE_TYPE ?= t3.medium
VERBOSE ?= false
DRY_RUN ?= false

# Colors for output
RED := \033[31m
GREEN := \033[32m
YELLOW := \033[33m
BLUE := \033[34m
RESET := \033[0m

# Logging functions
define log_info
	@echo "$(BLUE)[INFO]$(RESET) $(1)"
endef

define log_success
	@echo "$(GREEN)[SUCCESS]$(RESET) $(1)"
endef

define log_warn
	@echo "$(YELLOW)[WARN]$(RESET) $(1)"
endef

define log_error
	@echo "$(RED)[ERROR]$(RESET) $(1)"
endef

# Validation functions
define check_command
	@command -v $(1) >/dev/null 2>&1 || { echo "$(RED)[ERROR]$(RESET) $(1) is required but not installed"; exit 1; }
endef

define validate_number
	@echo "$(2)" | grep -E '^[0-9]+$$' >/dev/null || { echo "$(RED)[ERROR]$(RESET) $(1) must be a number, got: $(2)"; exit 1; }
endef

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

.PHONY: help validate plan status all create-roles create-cluster create-oidc-provider create-nodegroup install-addons install-nsm setup-kubeconfig setup-storage clean clean-nsm

# Default target
.DEFAULT_GOAL := help

help: ## Show this help message
	@echo "$(BLUE)Network Service Mesh on AWS EKS$(RESET)"
	@echo ""
	@echo "$(GREEN)Usage:$(RESET)"
	@echo "  make <target> [VARIABLE=value]"
	@echo ""
	@echo "$(GREEN)Targets:$(RESET)"
	@awk 'BEGIN {FS = ":.*?## "} /^[a-zA-Z_-]+:.*?## / {printf "  $(BLUE)%-20s$(RESET) %s\n", $$1, $$2}' $(MAKEFILE_LIST)
	@echo ""
	@echo "$(GREEN)Variables:$(RESET)"
	@echo "  $(BLUE)CLUSTER_NAME$(RESET)    Cluster name (default: $(CLUSTER_NAME))"
	@echo "  $(BLUE)REGION$(RESET)          AWS region (default: $(REGION))"
	@echo "  $(BLUE)NODE_COUNT$(RESET)      Number of nodes (default: $(NODE_COUNT))"
	@echo "  $(BLUE)INSTANCE_TYPE$(RESET)   Instance type (default: $(INSTANCE_TYPE))"
	@echo "  $(BLUE)NSM_VERSION$(RESET)     NSM version (default: $(NSM_VERSION))"
	@echo "  $(BLUE)VERBOSE$(RESET)         Verbose output (default: $(VERBOSE))"
	@echo ""
	@echo "$(GREEN)Examples:$(RESET)"
	@echo "  make all CLUSTER_NAME=my-cluster REGION=us-west-2"
	@echo "  make plan NODE_COUNT=6 INSTANCE_TYPE=t3.large"
	@echo "  make status"

validate: ## Validate prerequisites and configuration
	$(call log_info,"Validating prerequisites...")
	$(call check_command,aws)
	$(call check_command,kubectl)
	$(call check_command,make)
	$(call validate_number,"NODE_COUNT",$(NODE_COUNT))
	@if [ $(NODE_COUNT) -lt 1 ] || [ $(NODE_COUNT) -gt 10 ]; then \
		echo "$(RED)[ERROR]$(RESET) NODE_COUNT must be between 1 and 10"; exit 1; \
	fi
	$(call log_info,"Checking AWS credentials...")
	@aws sts get-caller-identity >/dev/null 2>&1 || { echo "$(RED)[ERROR]$(RESET) AWS credentials not configured"; exit 1; }
	$(call log_info,"Validating AWS region...")
	@aws ec2 describe-regions --region $(REGION) >/dev/null 2>&1 || { echo "$(RED)[ERROR]$(RESET) Invalid region: $(REGION)"; exit 1; }
	$(call log_success,"All prerequisites validated")

plan: validate ## Show what resources would be created (dry-run)
	$(call log_info,"Deployment plan for cluster: $(CLUSTER_NAME)")
	@echo ""
	@echo "$(GREEN)Configuration:$(RESET)"
	@echo "  Cluster Name: $(CLUSTER_NAME)"
	@echo "  Region: $(REGION)"
	@echo "  Node Count: $(NODE_COUNT)"
	@echo "  Instance Type: $(INSTANCE_TYPE)"
	@echo "  NSM Version: $(NSM_VERSION)"
	@echo ""
	@echo "$(GREEN)Resources to be created:$(RESET)"
	@echo "  • IAM Roles: $(CLUSTER_ROLE_NAME), $(NODEGROUP_ROLE_NAME), $(EBS_CSI_ROLE_NAME)"
	@echo "  • EKS Cluster: $(CLUSTER_NAME)"
	@echo "  • OIDC Provider for IRSA"
	@echo "  • Node Group: $(CLUSTER_NAME)-nodes ($(NODE_COUNT) x $(INSTANCE_TYPE))"
	@echo "  • AWS Addons: VPC CNI, EBS CSI Driver"
	@echo "  • NSM Components: Spire, Network Service Mesh"
	@echo ""
	@SUBNETS=$$(aws ec2 describe-subnets --filters "Name=default-for-az,Values=true" --query 'Subnets[].{Id:SubnetId,AZ:AvailabilityZone}' --output table --region $(REGION) 2>/dev/null || echo "Unable to fetch subnets"); \
	echo "$(GREEN)Target Subnets:$(RESET)"; echo "$$SUBNETS"

status: ## Show current cluster status
	$(call log_info,"Checking cluster status...")
	@if aws eks describe-cluster --name $(CLUSTER_NAME) --region $(REGION) >/dev/null 2>&1; then \
		echo "$(GREEN)Cluster Status:$(RESET)"; \
		aws eks describe-cluster --name $(CLUSTER_NAME) --region $(REGION) --query 'cluster.{Name:name,Status:status,Version:version,Endpoint:endpoint}' --output table; \
		echo ""; \
		echo "$(GREEN)Node Groups:$(RESET)"; \
		aws eks describe-nodegroup --cluster-name $(CLUSTER_NAME) --nodegroup-name $(CLUSTER_NAME)-nodes --region $(REGION) --query 'nodegroup.{Name:nodegroupName,Status:status,InstanceTypes:instanceTypes,ScalingConfig:scalingConfig}' --output table 2>/dev/null || echo "No node groups found"; \
		echo ""; \
		echo "$(GREEN)Addons:$(RESET)"; \
		aws eks list-addons --cluster-name $(CLUSTER_NAME) --region $(REGION) --output table 2>/dev/null || echo "No addons found"; \
	else \
		echo "$(YELLOW)[WARN]$(RESET) Cluster $(CLUSTER_NAME) not found in region $(REGION)"; \
	fi

all: validate ## Complete NSM-enabled EKS cluster setup
	$(call log_info,"Starting complete NSM-enabled EKS cluster setup...")
	@$(MAKE) create-roles
	@$(MAKE) create-cluster
	@$(MAKE) create-oidc-provider
	@$(MAKE) create-nodegroup
	@$(MAKE) install-addons
	@$(MAKE) install-nsm
	@$(MAKE) setup-kubeconfig
	@$(MAKE) setup-storage
	$(call log_success,"Complete setup finished! Cluster $(CLUSTER_NAME) is ready.")

create-roles: ## Create IAM roles for EKS cluster, node group, and EBS CSI driver
	$(call log_info,"Creating IAM roles...")
	@$(call log_info,"Creating EKS cluster role...")
	@aws iam create-role --role-name $(CLUSTER_ROLE_NAME) --assume-role-policy-document file://eks-cluster-role-trust.yaml $(AWS_OUTPUT) 2>/dev/null || echo "$(YELLOW)[WARN]$(RESET) Role $(CLUSTER_ROLE_NAME) already exists"
	@aws iam attach-role-policy --role-name $(CLUSTER_ROLE_NAME) --policy-arn $(EKS_CLUSTER_POLICY) 2>/dev/null || true
	@$(call log_info,"Creating EKS node group role...")
	@aws iam create-role --role-name $(NODEGROUP_ROLE_NAME) --assume-role-policy-document file://eks-nodegroup-role-trust.yaml $(AWS_OUTPUT) 2>/dev/null || echo "$(YELLOW)[WARN]$(RESET) Role $(NODEGROUP_ROLE_NAME) already exists"
	@aws iam attach-role-policy --role-name $(NODEGROUP_ROLE_NAME) --policy-arn $(EKS_WORKER_NODE_POLICY) 2>/dev/null || true
	@aws iam attach-role-policy --role-name $(NODEGROUP_ROLE_NAME) --policy-arn $(EKS_CNI_POLICY) 2>/dev/null || true
	@aws iam attach-role-policy --role-name $(NODEGROUP_ROLE_NAME) --policy-arn $(ECR_READ_ONLY_POLICY) 2>/dev/null || true
	@$(call log_info,"Creating EBS CSI driver role...")
	@aws iam create-role --role-name $(EBS_CSI_ROLE_NAME) --assume-role-policy-document file://eks-ebs-csi-role-trust.yaml $(AWS_OUTPUT) 2>/dev/null || echo "$(YELLOW)[WARN]$(RESET) Role $(EBS_CSI_ROLE_NAME) already exists"
	@aws iam attach-role-policy --role-name $(EBS_CSI_ROLE_NAME) --policy-arn $(EBS_CSI_POLICY) 2>/dev/null || true
	$(call log_success,"IAM roles created successfully")

create-cluster: ## Create EKS cluster
	$(call log_info,"Creating EKS cluster: $(CLUSTER_NAME)")
	@if aws eks describe-cluster --name $(CLUSTER_NAME) --region $(REGION) >/dev/null 2>&1; then \
		echo "$(YELLOW)[WARN]$(RESET) Cluster $(CLUSTER_NAME) already exists"; \
	else \
		SUBNET_IDS=$$(aws ec2 describe-subnets --filters "Name=default-for-az,Values=true" --query 'Subnets[].SubnetId' --output text --region $(REGION) | tr '\t' ','); \
		echo "$(BLUE)[INFO]$(RESET) Using subnets: $$SUBNET_IDS"; \
		aws eks create-cluster \
			--name $(CLUSTER_NAME) \
			--role-arn $$(aws iam get-role --role-name $(CLUSTER_ROLE_NAME) --query 'Role.Arn' --output text) \
			--resources-vpc-config subnetIds=$$SUBNET_IDS \
			--region $(REGION) \
			$(AWS_OUTPUT) || { echo "$(RED)[ERROR]$(RESET) Cluster creation failed"; exit 1; }; \
		echo "$(BLUE)[INFO]$(RESET) Waiting for cluster to become active (this may take 10-15 minutes)..."; \
		aws eks wait cluster-active --name $(CLUSTER_NAME) --region $(REGION) || { echo "$(RED)[ERROR]$(RESET) Cluster failed to become active"; exit 1; }; \
	fi
	$(call log_success,"EKS cluster ready")

create-oidc-provider: ## Create OIDC provider for IRSA authentication
	$(call log_info,"Setting up OIDC provider for IRSA...")
	@OIDC_URL=$$(aws eks describe-cluster --name $(CLUSTER_NAME) --region $(REGION) --query 'cluster.identity.oidc.issuer' --output text); \
	OIDC_ID=$$(echo $$OIDC_URL | cut -d'/' -f5); \
	echo "$(BLUE)[INFO]$(RESET) OIDC URL: $$OIDC_URL"; \
	echo "$(BLUE)[INFO]$(RESET) OIDC ID: $$OIDC_ID"; \
	aws iam create-open-id-connect-provider \
		--url $$OIDC_URL \
		--client-id-list sts.amazonaws.com \
		--thumbprint-list 9e99a48a9960b14926bb7f3b02e22da2b0ab7280 \
		--output text > /dev/null 2>&1 || echo "$(YELLOW)[WARN]$(RESET) OIDC provider already exists"; \
	echo "$(BLUE)[INFO]$(RESET) Updating EBS CSI role trust policy..."; \
	ACCOUNT_ID=$$(aws sts get-caller-identity --query 'Account' --output text); \
	sed "s/YOUR_ACCOUNT_ID/$$ACCOUNT_ID/g; s/YOUR_OIDC_ID/$$OIDC_ID/g; s/REGION/$(REGION)/g" eks-ebs-csi-role-trust.yaml > eks-ebs-csi-role-trust.yaml.personal; \
	echo "$(BLUE)[INFO]$(RESET) Recreating EBS CSI role with correct OIDC provider..."; \
	aws iam detach-role-policy --role-name $(EBS_CSI_ROLE_NAME) --policy-arn $(EBS_CSI_POLICY) 2>/dev/null || true; \
	aws iam delete-role --role-name $(EBS_CSI_ROLE_NAME) 2>/dev/null || true; \
	aws iam create-role --role-name $(EBS_CSI_ROLE_NAME) --assume-role-policy-document file://eks-ebs-csi-role-trust.yaml.personal $(AWS_OUTPUT); \
	aws iam attach-role-policy --role-name $(EBS_CSI_ROLE_NAME) --policy-arn $(EBS_CSI_POLICY)
	$(call log_success,"OIDC provider configured")

create-nodegroup: ## Create EKS node group
	$(call log_info,"Creating node group: $(CLUSTER_NAME)-nodes")
	@if aws eks describe-nodegroup --cluster-name $(CLUSTER_NAME) --nodegroup-name $(CLUSTER_NAME)-nodes --region $(REGION) >/dev/null 2>&1; then \
		echo "$(YELLOW)[WARN]$(RESET) Node group $(CLUSTER_NAME)-nodes already exists"; \
	else \
		aws eks create-nodegroup \
			--cluster-name $(CLUSTER_NAME) \
			--nodegroup-name $(CLUSTER_NAME)-nodes \
			--node-role $$(aws iam get-role --role-name $(NODEGROUP_ROLE_NAME) --query 'Role.Arn' --output text) \
			--subnets $$(aws ec2 describe-subnets --filters "Name=default-for-az,Values=true" --query 'Subnets[].SubnetId' --output text --region $(REGION) | tr '\n' ' ') \
			--instance-types $(INSTANCE_TYPE) \
			--scaling-config minSize=1,maxSize=10,desiredSize=$(NODE_COUNT) \
			--region $(REGION) \
			$(AWS_OUTPUT) || { echo "$(RED)[ERROR]$(RESET) Node group creation failed"; exit 1; }; \
		echo "$(BLUE)[INFO]$(RESET) Waiting for node group to become active (this may take 5-10 minutes)..."; \
		aws eks wait nodegroup-active --cluster-name $(CLUSTER_NAME) --nodegroup-name $(CLUSTER_NAME)-nodes --region $(REGION) || { echo "$(RED)[ERROR]$(RESET) Node group failed to become active"; exit 1; }; \
	fi
	$(call log_success,"Node group ready")

install-addons: ## Install AWS addons (VPC CNI and EBS CSI driver)
	$(call log_info,"Installing AWS addons...")
	@$(call log_info,"Installing VPC CNI addon...")
	@aws eks create-addon --cluster-name $(CLUSTER_NAME) --addon-name vpc-cni --region $(REGION) $(AWS_OUTPUT) 2>/dev/null || echo "$(YELLOW)[WARN]$(RESET) VPC CNI addon already exists"
	@$(call log_info,"Installing EBS CSI driver addon...")
	@aws eks create-addon --cluster-name $(CLUSTER_NAME) --addon-name aws-ebs-csi-driver \
		--service-account-role-arn $$(aws iam get-role --role-name $(EBS_CSI_ROLE_NAME) --query 'Role.Arn' --output text) \
		--region $(REGION) $(AWS_OUTPUT) 2>/dev/null || echo "$(YELLOW)[WARN]$(RESET) EBS CSI addon already exists"
	$(call log_success,"AWS addons installed")

install-nsm: ## Install Network Service Mesh components
	$(call log_info,"Installing Network Service Mesh...")
	@$(call log_info,"Installing Spire SPIFFE identity framework...")
	@kubectl apply --validate=false -k https://github.com/networkservicemesh/deployments-k8s/examples/spire/single_cluster?ref=$(NSM_VERSION) || { echo "$(RED)[ERROR]$(RESET) Spire installation failed"; exit 1; }
	@$(call log_info,"Waiting for Spire pods to be ready...")
	@kubectl wait -n spire --timeout=4m --for=condition=ready pod -l app=spire-server || { echo "$(RED)[ERROR]$(RESET) Spire server failed to start"; exit 1; }
	@kubectl wait -n spire --timeout=1m --for=condition=ready pod -l app=spire-agent || { echo "$(RED)[ERROR]$(RESET) Spire agent failed to start"; exit 1; }
	@$(call log_info,"Applying ClusterSPIFFEID configurations...")
	@kubectl apply --validate=false -f https://raw.githubusercontent.com/networkservicemesh/deployments-k8s/$(NSM_VERSION)/examples/spire/single_cluster/clusterspiffeid-template.yaml || { echo "$(RED)[ERROR]$(RESET) ClusterSPIFFEID configuration failed"; exit 1; }
	@kubectl apply --validate=false -f https://raw.githubusercontent.com/networkservicemesh/deployments-k8s/$(NSM_VERSION)/examples/spire/base/clusterspiffeid-webhook-template.yaml || { echo "$(RED)[ERROR]$(RESET) ClusterSPIFFEID webhook configuration failed"; exit 1; }
	@$(call log_info,"Installing Network Service Mesh components...")
	@kubectl apply --validate=false -k https://github.com/networkservicemesh/deployments-k8s/examples/basic?ref=$(NSM_VERSION) || { echo "$(RED)[ERROR]$(RESET) NSM installation failed"; exit 1; }
	@kubectl wait -n nsm-system --for=condition=ready --timeout=3m pod -l app=admission-webhook-k8s || { echo "$(RED)[ERROR]$(RESET) NSM admission webhook failed to start"; exit 1; }
	$(call log_success,"Network Service Mesh installed successfully")

setup-kubeconfig: ## Configure kubeconfig for cluster access
	$(call log_info,"Configuring kubeconfig...")
	@aws eks update-kubeconfig --region $(REGION) --name $(CLUSTER_NAME) || { echo "$(RED)[ERROR]$(RESET) Failed to update kubeconfig"; exit 1; }
	$(call log_success,"Kubeconfig configured")

setup-storage: ## Configure default storage class
	$(call log_info,"Configuring default storage class...")
	@kubectl patch storageclass gp2 -p '{"metadata":{"annotations":{"storageclass.kubernetes.io/is-default-class":"true"}}}' 2>/dev/null || echo "$(YELLOW)[WARN]$(RESET) Failed to set default storage class"
	$(call log_success,"Storage configuration completed")

clean-nsm: ## Clean up NSM resources only
	$(call log_info,"Cleaning up NSM resources...")
	@$(call log_info,"Removing NSM CRDs and webhooks...")
	@kubectl delete crd clusterspiffeids.spire.spiffe.io 2>/dev/null || echo "$(YELLOW)[WARN]$(RESET) CRD clusterspiffeids.spire.spiffe.io not found"
	@kubectl delete crd clusterfederatedtrustdomains.spire.spiffe.io 2>/dev/null || echo "$(YELLOW)[WARN]$(RESET) CRD clusterfederatedtrustdomains.spire.spiffe.io not found"
	@kubectl delete validatingwebhookconfiguration.admissionregistration.k8s.io/spire-controller-manager-webhook 2>/dev/null || echo "$(YELLOW)[WARN]$(RESET) Spire webhook not found"
	@kubectl delete ns spire 2>/dev/null || echo "$(YELLOW)[WARN]$(RESET) Spire namespace not found"
	@kubectl delete mutatingwebhookconfiguration nsm-mutating-webhook 2>/dev/null || echo "$(YELLOW)[WARN]$(RESET) NSM webhook not found"
	@kubectl delete ns nsm-system 2>/dev/null || echo "$(YELLOW)[WARN]$(RESET) NSM namespace not found"
	$(call log_success,"NSM resources cleaned up")

clean: ## Delete all resources (cluster, roles, NSM)
	$(call log_warn,"This will permanently delete all resources!")
	@read -p "Are you sure you want to delete cluster $(CLUSTER_NAME)? [y/N] " -n 1 -r; \
	echo ""; \
	if [[ $$REPLY =~ ^[Yy]$$ ]]; then \
		echo "$(BLUE)[INFO]$(RESET) Starting cleanup process..."; \
		echo "$(BLUE)[INFO]$(RESET) Deleting EKS addons..."; \
		aws eks delete-addon --cluster-name $(CLUSTER_NAME) --addon-name aws-ebs-csi-driver --region $(REGION) $(AWS_OUTPUT) 2>/dev/null || echo "$(YELLOW)[WARN]$(RESET) EBS CSI addon not found"; \
		aws eks delete-addon --cluster-name $(CLUSTER_NAME) --addon-name vpc-cni --region $(REGION) $(AWS_OUTPUT) 2>/dev/null || echo "$(YELLOW)[WARN]$(RESET) VPC CNI addon not found"; \
		echo "$(BLUE)[INFO]$(RESET) Deleting node group..."; \
		aws eks delete-nodegroup --cluster-name $(CLUSTER_NAME) --nodegroup-name $(CLUSTER_NAME)-nodes --region $(REGION) $(AWS_OUTPUT) 2>/dev/null || echo "$(YELLOW)[WARN]$(RESET) Node group not found"; \
		if aws eks describe-nodegroup --cluster-name $(CLUSTER_NAME) --nodegroup-name $(CLUSTER_NAME)-nodes --region $(REGION) >/dev/null 2>&1; then \
			echo "$(BLUE)[INFO]$(RESET) Waiting for node group deletion..."; \
			aws eks wait nodegroup-deleted --cluster-name $(CLUSTER_NAME) --nodegroup-name $(CLUSTER_NAME)-nodes --region $(REGION); \
		fi; \
		echo "$(BLUE)[INFO]$(RESET) Deleting EKS cluster..."; \
		aws eks delete-cluster --name $(CLUSTER_NAME) --region $(REGION) $(AWS_OUTPUT) 2>/dev/null || echo "$(YELLOW)[WARN]$(RESET) Cluster not found"; \
		if aws eks describe-cluster --name $(CLUSTER_NAME) --region $(REGION) >/dev/null 2>&1; then \
			echo "$(BLUE)[INFO]$(RESET) Waiting for cluster deletion..."; \
			aws eks wait cluster-deleted --name $(CLUSTER_NAME) --region $(REGION); \
		fi; \
		echo "$(BLUE)[INFO]$(RESET) Deleting IAM roles..."; \
		aws iam detach-role-policy --role-name $(EBS_CSI_ROLE_NAME) --policy-arn $(EBS_CSI_POLICY) 2>/dev/null || true; \
		aws iam delete-role --role-name $(EBS_CSI_ROLE_NAME) 2>/dev/null || echo "$(YELLOW)[WARN]$(RESET) EBS CSI role not found"; \
		aws iam detach-role-policy --role-name $(NODEGROUP_ROLE_NAME) --policy-arn $(EKS_WORKER_NODE_POLICY) 2>/dev/null || true; \
		aws iam detach-role-policy --role-name $(NODEGROUP_ROLE_NAME) --policy-arn $(EKS_CNI_POLICY) 2>/dev/null || true; \
		aws iam detach-role-policy --role-name $(NODEGROUP_ROLE_NAME) --policy-arn $(ECR_READ_ONLY_POLICY) 2>/dev/null || true; \
		aws iam delete-role --role-name $(NODEGROUP_ROLE_NAME) 2>/dev/null || echo "$(YELLOW)[WARN]$(RESET) Node group role not found"; \
		aws iam detach-role-policy --role-name $(CLUSTER_ROLE_NAME) --policy-arn $(EKS_CLUSTER_POLICY) 2>/dev/null || true; \
		aws iam delete-role --role-name $(CLUSTER_ROLE_NAME) 2>/dev/null || echo "$(YELLOW)[WARN]$(RESET) Cluster role not found"; \
		echo "$(BLUE)[INFO]$(RESET) Cleaning up generated files..."; \
		rm -f eks-ebs-csi-role-trust.yaml.personal; \
		echo "$(GREEN)[SUCCESS]$(RESET) All resources have been deleted"; \
	else \
		echo "$(BLUE)[INFO]$(RESET) Cleanup cancelled"; \
	fi
