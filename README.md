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

### **Exp-02: Major TF files**

