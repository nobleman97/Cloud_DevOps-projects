locals {

  cidr = "10.0.0.0/18" # Last Ip address in the range is "10.0.63.253"
  azs  = ["us-east-1a", "us-east-1b"]

  public_subnets = [
    "10.0.1.0/24",
  ]

  private_subnets = [
    "10.0.20.0/24",

  ]

  # Amazon Linux 2023 AMI from Nov 2025 (older version for kernel upgrade demo)
  ami_id = "ami-0fa3fe0fa7920f68e" # al2023-ami-2023.9.20251117.1-kernel-6.1-x86_64

  resource_name_segment = "demo-${var.environment}-${var.region}"

  # Ansible inventory content - auto-generated for SSM connectivity
  ansible_inventory_content = yamlencode({
    all = {
      children = {
        kernel_update_targets = {
          hosts = merge([
            for instance_name, instance in module.ec2-instance : {
              "${instance.id}" = {
                ansible_host           = instance.id
                ansible_connection     = "aws_ssm"
                ansible_aws_ssm_region = var.region
                private_ip             = instance.private_ip
                public_ip              = instance.public_ip
                instance_name          = instance_name
              }
            }
          ]...)
        }
      }
    }
  })

}

################
# Networking
################
module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "6.0.1"

  name = local.resource_name_segment

  cidr = local.cidr
  azs  = local.azs

  enable_nat_gateway     = false
  single_nat_gateway     = true
  one_nat_gateway_per_az = false

  enable_dns_hostnames = true
  enable_dns_support   = true

  map_public_ip_on_launch = true
  public_subnets          = local.public_subnets
  private_subnets         = local.private_subnets


  tags = merge(var.common_tags, {
    "Environment" = var.environment
  })
}

module "ec2_security_groups" {
  source  = "terraform-aws-modules/security-group/aws"
  version = "5.3.0"

  name        = "${local.resource_name_segment}-sg"
  description = "EC2 security group - no inbound access, SSM access via VPC endpoints"
  vpc_id      = module.vpc.vpc_id

  egress_with_cidr_blocks = [
    {
      rule = "all-all"
    }
  ]

  tags = merge(var.common_tags, {
    "Environment" = var.environment
  })

}

##################
# EC2 
##################
module "ec2-instance" {
  for_each = var.instances

  source  = "terraform-aws-modules/ec2-instance/aws"
  version = "6.0.2"

  name = each.key

  ami           = each.value.ami_id
  instance_type = each.value.instance_type

  monitoring = true
  subnet_id  = module.vpc.public_subnets[0]

  iam_instance_profile = aws_iam_instance_profile.ec2_ssm_profile.name

  create_security_group = false
  vpc_security_group_ids = [
    module.ec2_security_groups.security_group_id
  ]

  #   user_data = file("${path.module}/scripts/user_data.sh")

  root_block_device = {
    type                  = "gp3"
    size                  = 20
    delete_on_termination = true
    encrypted             = true
  }

  tags = merge(var.common_tags, {
    "Purpose"     = "Linux Kernel Update Demo"
    "Environment" = var.environment
    "Name"        = each.key
  })
}


# IAM Roles
resource "aws_iam_role" "ec2_ssm_role" {
  name = "${local.resource_name_segment}-ec2-ssm-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Service = "ec2.amazonaws.com"
        }
        Action = "sts:AssumeRole"
      }
    ]
  })

  tags = merge(var.common_tags, {
    "Environment" = var.environment
  })
}

resource "aws_iam_role_policy_attachment" "ssm_core_managed" {
  role       = aws_iam_role.ec2_ssm_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

# S3 access for SSM session logs
resource "aws_iam_role_policy" "ssm_s3_access" {
  name = "${local.resource_name_segment}-ssm-s3-access"
  role = aws_iam_role.ec2_ssm_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "s3:PutObject",
          "s3:GetObject",
          "s3:GetEncryptionConfiguration"
        ]
        Resource = [
          "arn:aws:s3:::devopsroyale-state-files-ccsji365i/ssm-sessions/*",
          "arn:aws:s3:::devopsroyale-state-files-ccsji365i/ansible-ssm/*"
        ]
      },
      {
        Effect = "Allow"
        Action = [
          "s3:GetBucketLocation"
        ]
        Resource = "arn:aws:s3:::devopsroyale-state-files-ccsji365i"
      }
    ]
  })
}

# IAM Instance Profile
resource "aws_iam_instance_profile" "ec2_ssm_profile" {
  name = "${local.resource_name_segment}-ec2-ssm-profile"
  role = aws_iam_role.ec2_ssm_role.name
}

################
# Ansible Inventory Generation
################
resource "local_file" "ansible_inventory" {
  content  = local.ansible_inventory_content
  filename = "${path.module}/ansible/inventory/hosts.yml"

  depends_on = [module.ec2-instance]
}

################
# Ansible Execution
################
resource "null_resource" "ansible_kernel_update" {
  count = var.run_ansible ? 1 : 0

  triggers = {
    instance_ids      = join(",", [for k, v in module.ec2-instance : v.id])
    kernel_version    = var.ansible_kernel_package
    release_version   = var.linux_kernel_version
    inventory_content = local.ansible_inventory_content
    # always_run        = timestamp()
  }

  provisioner "local-exec" {
    working_dir = "${path.module}/ansible"
    command     = <<-EOT
      echo "Installing Ansible collections..."
      ansible-galaxy collection install -r requirements.yml --force

      echo "Waiting for SSM agent to be ready..."
      sleep 30

      echo "Running kernel update playbook..."
      ansible-playbook playbooks/kernel_update.yml \
        -i inventory/hosts.yml \
        -e "kernel_version=${var.ansible_kernel_package}" \
        -e "release_version=${var.linux_kernel_version}" \
        -e "kernel_update_check_only=${var.ansible_check_only}" \
        -e "serial_batch_size=${var.ansible_serial_batch_size}"
    EOT
  }

  depends_on = [
    local_file.ansible_inventory,
    module.ec2-instance
  ]
}
