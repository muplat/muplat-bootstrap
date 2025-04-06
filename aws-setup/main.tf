resource "random_string" "suffix" {
  length  = 8
  special = false
  upper   = false
}

module "vpc" {
  source = "terraform-aws-modules/vpc/aws"

  name = "muplat-${random_string.suffix.result}"
  cidr = "10.0.0.0/16"

  azs             = ["${var.region}a", "${var.region}b", "${var.region}c"]
  private_subnets = ["10.0.1.0/24", "10.0.2.0/24", "10.0.3.0/24"]
  public_subnets  = ["10.0.101.0/24", "10.0.102.0/24", "10.0.103.0/24"]

  enable_nat_gateway = true
  enable_vpn_gateway = false

  tags = {
    Terraform = "true"
    Owner     = "muplat"
  }
}

module "eks" {
  source  = "terraform-aws-modules/eks/aws"
  version = "~> 20.0"

  cluster_name                   = "muplat-${random_string.suffix.result}"
  cluster_version                = "1.31"
  cluster_endpoint_public_access = true

  bootstrap_self_managed_addons = false
  cluster_addons = {
    eks-pod-identity-agent = {}
    kube-proxy             = {}
    vpc-cni                = {}
    #    coredns                = {}
  }

  # Optional: Adds the current caller identity as an administrator via cluster access entry
  enable_cluster_creator_admin_permissions = true

  vpc_id                   = module.vpc.vpc_id
  control_plane_subnet_ids = module.vpc.public_subnets
  authentication_mode      = "API_AND_CONFIG_MAP"

  tags = {
    Terraform = "true"
    Owner     = "muplat"
  }
}

module "control_group" {
  source = "terraform-aws-modules/eks/aws//modules/eks-managed-node-group"

  name                  = "control-group"
  cluster_name          = module.eks.cluster_name
  cluster_service_cidr  = module.eks.cluster_service_cidr
  cluster_version       = module.eks.cluster_version
  subnet_ids            = module.vpc.private_subnets

  // The following variables are necessary if you decide to use the module outside of the parent EKS module context.
  // Without it, the security groups of the nodes are empty and thus won't join the cluster.
  cluster_primary_security_group_id = module.eks.cluster_primary_security_group_id
  vpc_security_group_ids            = [module.eks.node_security_group_id]

  disk_size = 20

  min_size     = var.min_node_group_size
  max_size     = var.max_node_group_size
  desired_size = 2

  instance_types = [var.node_type]
  capacity_type  = "ON_DEMAND"

  taints = {
    control-group = {
      key    = "service"
      value  = "control-group"
      effect = "NO_SCHEDULE"
    }
  }

  tags = {
    Terraform = "true"
    Owner     = "muplat"
  }
}

resource "aws_eks_addon" "coredns" {
  cluster_name  = module.eks.cluster_name
  addon_name    = "coredns"
  addon_version = "v1.11.3-eksbuild.1"

  configuration_values = <<EOF
{
  "affinity": {
    "nodeAffinity": {
      "requiredDuringSchedulingIgnoredDuringExecution": {
        "nodeSelectorTerms": [
          {
            "matchExpressions": [
              {
                "key": "kubernetes.io/os",
                "operator": "In",
                "values": ["linux"]
              },
              {
                "key": "kubernetes.io/arch",
                "operator": "In",
                "values": ["amd64", "arm64"]
              }
            ]
          }
        ]
      }
    },
    "podAntiAffinity": {
      "preferredDuringSchedulingIgnoredDuringExecution": [
        {
          "podAffinityTerm": {
            "labelSelector": {
              "matchExpressions": [
                {
                  "key": "k8s-app",
                  "operator": "In",
                  "values": ["kube-dns"]
                }
              ]
            },
            "topologyKey": "kubernetes.io/hostname"
          },
          "weight": 100
        }
      ]
    }
  },
  "autoScaling": {
    "enabled": false
  },
  "tolerations": [
    {
      "key": "CriticalAddonsOnly",
      "operator": "Exists"
    },
    {
      "key": "node-role.kubernetes.io/control-plane",
      "effect": "NoSchedule"
    },
    {
      "key": "service",
      "value": "control-group",
      "effect": "NoSchedule"
    }
  ]
}
EOF

  depends_on = [module.control_group]
}

module "karpenter" {
  source = "terraform-aws-modules/eks/aws//modules/karpenter"

  cluster_name = module.eks.cluster_name


  enable_v1_permissions = true

  enable_pod_identity             = true
  create_pod_identity_association = true
  create_access_entry             = true
  create_node_iam_role            = true
  # Attach additional IAM policies to the Karpenter node IAM role
  node_iam_role_additional_policies = {
    AmazonSSMManagedInstanceCore = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
  }

  tags = {
    Terraform = "true"
    Owner     = "muplat"
  }
}
