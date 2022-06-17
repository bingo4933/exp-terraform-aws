## Terraform DNS to DB Demo on AWS with EC2

### **Exp-01: Introduction**

- In this branch we would create ALB to connect multi-AZ’s private EC2 Instance that APP running in  which communicate to backend database.
- This branch based on branch `v3-ALB-Application-LoadBalancer-PathBasedRouting`
- Define ALB which include three rules to communicate EC2 Instance of `app1`,  `app2`, `usermgmt`

### **Exp-02: Major setting**

#### Exp-02-01: RDS Database Terraform Configs

- Create RDS DB Security Group

  - exp-5-06-securitygroup-rdsdbsg.tf

  ```t
  # Security Group for AWS RDS DB
  module "rdsdb_sg" {
      source = "terraform-aws-modules/security-group/aws"
      version = "4.0.0"
  
      name = "rdsdb-sg"
      description = "Access to MySQL DB for entire VPC CIDR Block"
  
      # VPC
      vpc_id = module.vpc.vpc_id
  
      # Ingress Rules & CIDR Blocks
      ingress_with_cidr_blocks = [
          {
              from_port = 3306
              to_port = 3306
              protocol = "tcp"
              description = "MySQL access from within VPC"
              cidr_blocks = module.vpc.vpc_cidr_block
          },
      ]
  
      # Egress Rule - all-all open
      egress_rules = ["all-all"]
  
      # TAG
      tags = local.common_tags
  }
  ```

- RDS DB Variables with `sensitive` argument for DB password

  - exp-13-01-rdsdb-variables.tf

  ```t
  # Terraform AWS RDS Database variables
  
  # DB Name
  variable "db_name" {
      description = "AWS RDS Database Name"
      type = string
  }
  
  # DB Instance Identifier
  variable "db_instance_identifier" {
      description = "AWS RDS Database Instance identifier"
      type = string
  }
  
  # DB Username - Enable Sensitive flag
  variable "db_username" {
      description = "AWS RDS Database Administrator Username"
      type = string
  }
  
  # DB Password - Enable sensitive flag
  variable "db_password" {
      description = "AWS RDS Database administrator Password"
      type = string
      sensitive = true
  }
  ```

- Create RDS DB Module

  - exp-13-02-rdsdb.tf

  ```t
  # Create AWS RDS Database
  module "rdsdb" {
      source = "terraform-aws-modules/rds/aws"
      version = "3.0.0"
  
      identifier = "${var.db_instance_identifier}"
  
      name = "${var.db_name}"
      username = "${var.db_username}"
      password = "${var.db_password}"
      port = 3306
  
      multi_az = true
      subnet_ids = module.vpc.database_subnets
      vpc_security_group_ids = [module.rdsdb_sg.security_group_id]
  
      # DB option
      engine = "mysql"
      engine_version = "8.0.20"
      family = "mysql8.0"
      major_engine_version = "8.0"
      instance_class = "db.t3.large"
  
      allocated_storage = 20
      max_allocated_storage = 100
      storage_encrypted = false
  
      maintenance_window = "Mon:00:00-Mon:03:00"
      backup_window = "03:00-06:00"
      enabled_cloudwatch_logs_exports = ["general"]
  
      backup_retention_period = 0
      skip_final_snapshot = true
      deletion_protection = false
  
      performance_insights_enabled = true
      performance_insights_retention_period = 7
      create_monitoring_role = true
      monitoring_interval = 60
  
      parameters = [
          {
              name = "character_set_client"
              value = "utf8mb4"
          },
          {
              name = "character_set_server"
              value = "utf8mb4"
          }
      ]
  
      tags = local.common_tags
  
      db_instance_tags = {
          "Sensitive" = "high"
      }
      db_option_group_tags = {
          "Sensitive" = "low"
      }
      db_parameter_group_tags = {
          "Sensitive" = "low"
      }
      db_subnet_group_tags = {
          "Sensitive" = "high"
      }    
  }
  ```


#### Exp-02-02: EC2 Instance Terraform Configs

- Create EC2 Instance Module for new App3

  - exp-7-06-ec2instance-private-app3.tf

  ```t
  # AWS EC2 Instance Terraform Module
  module "ec2_private_app3" {
    depends_on = [ module.vpc ]
    source = "terraform-aws-modules/ec2-instance/aws"
    version = "2.17.0"
    
    name = "${var.environment}-app3"
    ami = data.aws_ami.amzlinux2.id
    instance_type = "${var.instance_type}"
    key_name = "${var.instance_keypair}"
  
    vpc_security_group_ids = [module.private_sg.security_group_id]
    subnet_ids = [
      module.vpc.private_subnets[0],
      module.vpc.private_subnets[1]
    ]
    instance_count = "${var.private_instance_count}"
    user_data =  templatefile("app3-ums-install.tmpl",{rds_db_endpoint = module.rdsdb.db_instance_address})    
    tags = local.common_tags
  }
  ```

  - app3-ums-install.tmpl

  ```t
  #! /bin/bash
  sudo amazon-linux-extras enable java-openjdk11
  sudo yum clean metadata && sudo yum -y install java-11-openjdk
  mkdir /home/ec2-user/app3-usermgmt && cd /home/ec2-user/app3-usermgmt
  wget https://gitee.com/bingo4933/temp1/attach_files/1097299/download/usermgmt-webapp.war -P /home/ec2-user/app3-usermgmt 
  export DB_HOSTNAME=${rds_db_endpoint}
  export DB_PORT=3306
  export DB_NAME=webappdb
  export DB_USERNAME=dbadmin
  export DB_PASSWORD=dbpassword11
  java -jar /home/ec2-user/app3-usermgmt/usermgmt-webapp.war > /home/ec2-user/app3-usermgmt/ums-start.log &
  ```

- App Port 8080 inbound rule added to Private_SG module `"http-8080-tcp"`

  - exp-5-04-securitygroup-privatesg.tf

  ```t
  # AWS EC2 Security Group Terraform Module
  # Security Group for private Bastion Host
  module "private_sg" {
      source = "terraform-aws-modules/security-group/aws"
      version = "4.0.0"
  
      name = "private-sg"
      description = "Security Group with HTTP & SSH port open for entire VPC Block (IPv4 CIDR), egress ports are all world open"
  
      # VPC
      vpc_id = module.vpc.vpc_id
  
      # Ingress Rules & CIDR Blocks
      ingress_rules = ["ssh-tcp", "http-80-tcp", "http-8080-tcp"]
      ingress_cidr_blocks = ["module.vpc.vpc_cidr_block"]
  
      # Egress Rule - all-all open
      egress_rules = ["all-all"]
  
      # TAG
      tags = local.common_tags
  }
  ```

  

#### Exp-02-03: ALB Terraform Configs

- Create ALB TG for app3 UMS with port 8080 and enable Stickiness for app3 UMS TG

  ```t
          # app3 target group - TG Index = 3
          {
              name_prefix = "app3-"
              backend_protocol = "HTTP"
              backend_port = 8080
              target_type = "instance"
              deregistration_delay = 10
              health_check = {
                  enabled = true
                  interval = true
                  path = "/login"
                  port = "traffic-port"
                  healthy_threshold = 3
                  unhealthy_threshold = 3
                  timeout = 6
                  protocol = "HTTP"
                  matcher = "200-399"
              }
              stickiness = {
                  enabled = true
                  cookie_duration = 86400
                  type = "lb_cookie"
              }
              protocol_version = "HTTP1"
              # app3 target group - Targets
              targets = {
                  my_app3_vm1 = {
                      target_id = module.ec2_private_app3.id[0]
                      port = 8080
                  },
                  my_app3_vm2 = {
                      target_id = module.ec2_private_app3.id[1]
                      port = 8080
                  }
              }
              tags = local.common_tags            
          },
  ```

  

- Create HTTPS Listener Rule for (/db*)

  ```t
          # rule-3: /db should go to db ec2 instance
          {
              https_listener_index = 0
              priority = 3
              actions = [
                  {
                      type = "forward"
                      target_group_index = 3
                  }
              ]
              conditions = [{
                  path_patterns = ["/db*"]
              }]
          },
  ```

#### Exp-02-04: Create Jumpbox server to have mysql client installed

- Using jumpbox userdata, mysql client should be auto-installed.

  - jumpbox-install.sh

  ```t
  #! /bin/bash
  sudo yum update -y
  sudo rpm -e --nodeps mariadb-libs-*
  sudo amazon-linux-extras enable mariadb10.5 
  sudo yum clean metadata
  sudo yum install -y mariadb
  sudo mysql -V
  sudo yum install -y telnet
  ```

#### Exp-02-05: Create DNS Name AWS Route53 Record Set

- Give `app-to-db` DNS name for Route53 record

  - exp-12-route53-dnsregistration.tf

  ```t
  # registrate a domain name in Route53
  resource "aws_route53_record" "apps_dns" {
      zone_id = data.aws_route53_zone.mydomain.zone_id
      name = "app-to-db.galaxy-aws.top"
      type = "A"
      alias {
        name = module.alb.lb_dns_name
        zone_id = module.alb.lb_zone_id
        evaluate_target_health = true
      }
  }
  ```

#### Exp-02-06: Create ALB and Listener rules

```t
    # HTTPS Listener Rules
    https_listener_rules = [
        # rule-1: /app1* should go to app1 ec2 instance
        {
            https_listener_index = 0
            priority = 1
            actions = [
                {
                    type = "forward"
                    target_group_index = 0
                }
            ]
            conditions = [{
                path_patterns = ["/app1*"]
            }]
        },
        # rule-2: /app2* should go to app2 ec2 instance
        {
            https_listener_index = 0
            priority = 2
            actions = [
                {
                    type = "forward"
                    target_group_index = 1
                }
            ]
            conditions = [{
                path_patterns = ["/app2*"]
            }]
        },
        # rule-3: /db should go to db ec2 instance
        {
            https_listener_index = 0
            priority = 3
            actions = [
                {
                    type = "forward"
                    target_group_index = 3
                }
            ]
            conditions = [{
                path_patterns = ["/db*"]
            }]
        },
    ]
```

#### Exp-02-07: Create app3 Target Group

- Create app3 Target Group

```t
    # App3 Target Group - TG Index = 2
    {
      name_prefix          = "app3-"
      backend_protocol     = "HTTP"
      backend_port         = 80
      target_type          = "instance"
      deregistration_delay = 10 
      health_check = {
        enabled             = true
        interval            = 30
        path                = "/login"
        port                = "traffic-port"
        healthy_threshold   = 3
        unhealthy_threshold = 3
        timeout             = 6
        protocol            = "HTTP"
        matcher             = "200-399"
      }
      stickiness = {
        enabled = true
        cookie_duration = 86400
        type = "lb_cookie"
      }
      protocol_version = "HTTP1"
      # App3 Target Group - Targets
      targets = {
        my_app3_vm1 = {
          target_id = module.ec2_private_app3.id[0]
          port      = 8080
        },
        my_app3_vm2 = {
          target_id = module.ec2_private_app3.id[1]
          port      = 8080
        }
      }
      tags =local.common_tags # Target Group Tags
    }
```

#### Exp-02-08: exp-12-route53-dnsregistration.tf

- register DNS name

```t
  name    = "app-to-db.galaxy-aws.top"
```

### **Exp-03: Execute Terraform Commands**

```t
terraform init 

terraform validate

terraform plan -var-file="secrets.tfvars"

terraform apply -var-file="secrets.tfvars"
```

#### Exp-03-01: Verify AWS Resources creation on Cloud

1. EC2 Instance app1, app2, app3, bastion host
2. RDS Databases
3. ALB Listeners and routing rules
4. ALB Target Groups app1, app2 and app3 if they are healthy

#### Exp-03-02: Connect to DB

- login to bastion then connect DB to test if default db and tables created.
- Connect via bastion to DB to verify webappdb, tables and Content inside

```t
# Connect to MySQL DB on bastion
mysql -h webappdb.cxojydmxwly6.ap-northeast-1.rds.amazonaws.com -u dbadmin -pYOUR_DB_PASSWORD
mysql> show schemas;
mysql> use webappdb;
mysql> show tables;
mysql> select * from user;
```

- **Important Note: ** If you the tables created and `default admin user` present in `user` that confirms our `User Management Web Application` is up and running on `app3 EC Instance`

#### Exp-03-03: Access application and test

```t
# App1
https://app-to-db.galaxy-aws.top/app1/index.html

# App2
https://app-to-db.galaxy-aws.top/app2/index.html

# App3
https://app-to-db.galaxy-aws.top/db
Username: admin101
Password: password101
1. Create a user, List User
2. Verify user in DB
```

#### Exp-03-04: Additional Troubleshooting for app3

- Connect to app3 Instances

```t
# Connect to App3 EC2 Instance from bastion
ssh  ec2-user@<App3-Ec2Instance-1-Private-IP>

# Check logs
cd app3-usermgmt
more ums-start.log

# For further troubleshooting
- Shutdown one EC2 instance from App3 and test with 1 instance
```

### **Exp-04: Clean-Up**

```t
# Destroy Resources
terraform destroy -auto-approve

# Delete Files
rm -rf .terraform*
rm -rf terraform.tfstate
```

