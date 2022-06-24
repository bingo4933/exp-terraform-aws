## Demo of Terraform Remote State Storage with two projects

### **Exp-01: Introduction**

In this branch we’re going to implement a demo of usecase to terraform remote state datasource across tow project.

We have a `project-1` which has the entire of VPC configuration, networking related configuration. It also has `terraform.tfstate` under the `project-1` in S3 bucket.

We also have another `project-2` which has nothing but your application. It need some like autoscaling group, application load balancer, route53  and certificates etc. Its `terraform.tfstate` is also on S3 bucket.

so, if `project-2` need to create two instance in the VPC which required refer to `project-1`'s VPC. So, we could access those information using `terraform remote state data source` which meaning, we could able to access the information about this VPC(in `project-1`)

Now, in the `project-1` which working directly to VPC only. Create VPC resource with terraform backend S3 bucket.

In the `project-2` we will create functionality as below based terraform remote state.

- Autoscaling Group
- Application Load Balancer
- AWS route53
- AWS certificate manager
- AWS SNS
- AWS IAM

After definition backend datasource in TF file. Need to create relevant S3 bucket and DynamoDB table on AWS console

go to Amazon S3 service, create bucket

- Name:  **galaxy-1024-terraform-on-aws-for-ec2**

go to that bucket then create directory

- Name: **dev**

create another two directory in `dev` directory

- Name: **project1-vpc**
- Name: **Project2-app1**

create two DynamoDB table

- Table name: **dev-project1-vpc**
- Partition key(Primary Key): **LockID (Type as String)**
- Table settings: **Use default settings(checked)**
- click: **Create table**

- Table name: **dev-project2-app1**
- Partition key(Primary Key): **LockID (Type as String)**
- Table settings: **Use default settings(checked)**
- click: **Create table**

### **Exp-02: Major TF files of project-2**

#### **Exp-02-01: Project-2: exp-0-terraform-remote-state-datasource.tf**

- Create terraform remote state datasource
- In this datasource, we will provide the Terraform State file information of our `project-1`

```t
# Terraform Remote State Datasource
data "terraform_remote_state" "vpc" {
  backend = "s3"
  config = {
      bucket = "galaxy-1024-terraform-on-aws-for-ec2"
      key = "dev/project1-vpc/terraform.tfstate"
      region = "ap-northeast-1"
  }
}
```

#### **Exp-02-02: refer to VPC ID of Security group from project-1**

- there are three file which refer to VPC ID
- exp-5-03-securitygroup-bastionsg.tf

```t
# AWS EC2 Security Group Terraform Module
# Security Group for Public Bastion Host
module "public_bastion_sg" {
  source  = "terraform-aws-modules/security-group/aws"
  version = "4.0.0"

  name = "public-bastion-sg"
  description = "Security Group with SSH port open for everybody (IPv4 CIDR), egress ports are all world open"
  vpc_id = data.terraform_remote_state.vpc.outputs.vpc_id

  # Ingress Rules & CIDR Blocks
  ingress_rules = ["ssh-tcp"]
  ingress_cidr_blocks = ["0.0.0.0/0"]
  
  # Egress Rule - all-all open
  egress_rules = ["all-all"]
  tags = local.common_tags
}
```

- exp-5-04-securitygroup-privatesg.tf

```t
# AWS EC2 Security Group Terraform Module
# Security Group for Private EC2 Instances
module "private_sg" {
  source  = "terraform-aws-modules/security-group/aws"
  version = "4.0.0"
  
  name = "private-sg"
  description = "Security Group with HTTP & SSH port open for entire VPC Block (IPv4 CIDR), egress ports are all world open"
  vpc_id = data.terraform_remote_state.vpc.outputs.vpc_id

  # Ingress Rules & CIDR Blocks
  ingress_rules = ["ssh-tcp", "http-80-tcp", "http-8080-tcp"]
  ingress_cidr_blocks = [data.terraform_remote_state.vpc.outputs.vpc_cidr_block]
  
  # Egress Rule - all-all open
  egress_rules = ["all-all"]
  tags = local.common_tags
}
```

- exp-5-05-securitygroup-loadbalancersg.tf

```t
# Security Group for Public Load Balancer
module "loadbalancer_sg" {
  source  = "terraform-aws-modules/security-group/aws"
  version = "4.0.0"

  name = "loadbalancer-sg"
  description = "Security Group with HTTP open for entire Internet (IPv4 CIDR), egress ports are all world open"
  vpc_id = data.terraform_remote_state.vpc.outputs.vpc_id

  # Ingress Rules & CIDR Blocks
  ingress_rules = ["http-80-tcp", "https-443-tcp"]
  ingress_cidr_blocks = ["0.0.0.0/0"]
  
  # Egress Rule - all-all open
  egress_rules = ["all-all"]
  tags = local.common_tags

  # Open to CIDRs blocks
  ingress_with_cidr_blocks = [
    {
      from_port   = 81
      to_port     = 81
      protocol    = 6
      description = "Allow Port 81 from internet"
      cidr_blocks = "0.0.0.0/0"
    },
  ]
}
```

#### **Exp-02-03: refer to VPC Subnet ID from project-1**

- exp-7-03-ec2instance-bastion.tf

```t
# AWS EC2 Instance Terraform Module
# Bastion Host - EC2 Instance that will be created in VPC Public Subnet
module "ec2_public" {
  source  = "terraform-aws-modules/ec2-instance/aws"
  version = "2.17.0"

  name                   = "${var.environment}-BastionHost"
  ami                    = data.aws_ami.amzlinux2.id
  instance_type          = var.instance_type
  key_name               = var.instance_keypair
  #monitoring             = true
  subnet_id              = data.terraform_remote_state.vpc.outputs.public_subnets[0]
  vpc_security_group_ids = [module.public_bastion_sg.security_group_id]
  tags = local.common_tags
}
```

#### **Exp-02-04: remove module.vpc**

- exp-8-elasticip.tf

```t
# Before
  depends_on = [ module.ec2_public, module.vpc ]
# After
  depends_on = [ module.ec2_public ]
```



#### **Exp-02-05: refer to VPC_ID and public_subnets**

- exp-10-02-ALB-application-loadbalancer.tf

```t
# Before
  vpc_id = module.vpc.vpc_id
  subnets = module.vpc.public_subnets
# After
  vpc_id = data.terraform_remote_state.vpc.outputs.vpc_id 
  subnets = data.terraform_remote_state.vpc.outputs.public_subnets
```

#### **Exp-02-06: setting domain name**

- exp-12-route53-dnsregistration.tf

```t
# DNS Registration 
resource "aws_route53_record" "apps_dns" {
  zone_id = data.aws_route53_zone.mydomain.zone_id 
  name    = "remote-state-datasource.galaxy-aws.top"
  type    = "A"
  alias {
    name                   = module.alb.lb_dns_name
    zone_id                = module.alb.lb_zone_id
    evaluate_target_health = true
  }  
}
```

#### **Exp-02-07: adding backend S3 as remote state storage**

- exp-1-versions.tf

```t
  # Adding Backend as S3 for Remote State Storage
  backend "s3" {
    bucket = "galaxy-1024-terraform-on-aws-for-ec2"
    key    = "dev/project2-app1/terraform.tfstate"
    region = "ap-northeast-1" 

    # For State Locking
    dynamodb_table = "dev-project2-app1"    
  }
}
```

#### **Exp-02-08: refer to VPC private_subnets**

- exp-13-03-autoscaling-resource.tf

```t
# Before
  vpc_zone_identifier = module.vpc.private_subnets

# After
  vpc_zone_identifier = data.terraform_remote_state.vpc.outputs.private_subnets 

```

### **Exp-03: project-1 Execute Terraform Commands**

- Create resources(VPC) in project-1

```t
# Terraform Initialize
terraform init

# Terraform Validate
terraform validate

# Terraform Plan
terraform plan

# Terraform Apply
terraform apply -auto-approve

# Terraform State List
terraform state list

# Observations
1. Verify VPC Resources created
2. Verify S3 bucket on AWS console and terraform.tfstate file for project-1
```

### **Exp-04: project-2 Execute Terraform Commands**

- Create resources in project-2

```t
# Terraform Initialize
terraform init

# Terraform Validate
terraform validate

# Terraform Plan
terraform plan

# Terraform Apply
terraform apply -auto-approve

# Terraform State List
terraform state list
```

### **Exp-05: Verify project-2 resources**

1. Verify S3 bucket and terraform.tfstate file for project-2
2. Verify Security Groups
3. Verify EC2 Instances (Bastion Host and ASG related EC2 Instances)
4. Verify Application Load Balancer and Target Group
5. Verify Autoscaling Group and Launch template
6. Access Application and Test

```t
# Access Application
https://remote-state-datasource.galaxy-aws.top
https://remote-state-datasource.galaxy-aws.top/app1/index.html
https://remote-state-datasource.galaxy-aws.top/app1/metadata.html
```

### **Exp-06: Clean-Up**

```t
# Change Directory 
cd project-2-app1-with-asg-and-alb
# Terraform Destroy
terraform destroy -auto-approve

# Delete files
rm -rf .terraform*

# Change Directory
cd project-1-aws-vpc

# Terraform Destroy
terraform destroy -auto-approve

# Delete files
rm -rf .terraform*
```