## **Demo to Build a Terraform Module manually**

### **Exp-01: Introduction**

In this branch, we’re going to implement a demo of static website on AWS S3 bucket. First step will achieve that via resource of terraform registry then do that via module which from scratch.

### **Exp-02:  Major terraform file of v1 branch**

#### **Exp-02-01 build website on S3 manually**

First, I will brief descript the steps to build static website on S3 bucket on AWS console.

##### **Exp-02-01-01:  Create AWS S3 Bucket**

- Go to AWS Services -> S3 -> Create Bucket
- **Bucket Name:** galaxy-mybucket-1024(Note: bucket name should be unique across AWS)
- **Region: ** ap-northeast-1
- Rest all leave to defaults
- Click on **Create bucket**

##### **Exp-02-01-02:  Enable Static website hosting**

- Go to AWS Services -> S3 -> Buckets -> mybucket-1045 -> Properties Tab -> At the end
- Edit to enable **Static website hosting**
- **Static website hosting:** enable
- **Index document:** index.html
- Click on **Save Changes**

##### **Exp-02-01-03:  Remove Block public access(bucket settings)**

- Go to AWS Services -> S3 -> Buckets -> mybucket-1045 -> Permissions Tab
- Edit **Block public access (bucket settings)**
- Uncheck **Block all public access**
- Click on **Save Changes**
- Provide text `confirm` and Click on **Confirm**

##### **Exp-02-01-04: Add Bucket policy for public read by bucket owners**

- Update your bucket name in the below listed policy

```t
{
  "Version": "2012-10-17",
  "Statement": [
      {
          "Sid": "PublicReadGetObject",
          "Effect": "Allow",
          "Principal": "*",
          "Action": [
              "s3:GetObject"
          ],
          "Resource": [
              "arn:aws:s3:::galaxy-mybucket-1024/*"
          ]
      }
  ]
}
```

- Go to AWS Services -> S3 -> Buckets -> mybucket-1045 -> Permissions Tab
- Edit -> **Bucket policy** -> Copy paste the policy above with your bucket name
- Click on **Save Changes**

##### **Exp-02-01-05: Upload index.html**

- **Location:** v1-create-static-website-on-s3-using-aws-mgmt-console/index.html
- Go to AWS Services -> S3 -> Buckets -> mybucket-1045 -> Objects Tab
- Upload **index.html**

##### **Exp-02-01-06: Access Static Website using S3 Website Endpoint**

- Access the newly uploaded `index.html` to S3 bucket using browser

```t
# Endpoint Link
http://galaxy-mybucket-1024.s3-website.ap-northeast-1.amazonaws.com/
```

#### **Exp-02-02: build static website on S3 bucket via terraform resources**

- main.tf

```t
# Create S3 Bucket Resource
resource "aws_s3_bucket" "s3_bucket" {
  bucket = "${var.bucket_name}"
  acl = "public-read"
  policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "PublicReadGetObject",
      "Effect": "Allow",
      "Principal": "*",
      "Action": [
        "s3:GetObject"
      ],
      "Resource": [
        "arn:aws:s3:::${var.bucket_name}/*"
      ]
    }
  ]
}
EOF
  website {
    index_document = "index.html"
    error_document = "error.html"
  }
  tags = "${var.tags}"
  force_destroy = true
}
```

- terraform.tfvars

```t
bucket_name = "galaxy-mybucket-1024"
tags = {
  Terraform = "true"
  Environment = "dev"
}
```

- variables.tf

```t
# Input variable definitions

variable "bucket_name" {
  description = "Name of the S3 bucket. Must be Unique across AWS"
  type        = string
}

variable "tags" {
  description = "Tages to set on the bucket"
  type        = map(string)
  default     = {}
}
```

#### **Exp-02-03: Execute Terraform Commands & Verify the bucket**

```t
# Terraform Initialize
terraform init

# Terraform Validate
terraform validate

# Terraform Plan
terraform plan

# Terraform Apply
terraform apply -auto-approve

# Verify 
1. Bucket has static website hosting enabled
2. Bucket has public read access enabled using policy
3. Bucket has "Block all public access" unchecked
```

#### **Exp-02-04: Upload index.html and access**

```t
# upload index.html file then visite endpoint of website in browser
http://galaxy-mybucket-1024.s3-website.ap-northeast-1.amazonaws.com/
```

#### **Exp-02-05: Destroy and Clean-Up**

```t
# Terraform Destroy
terraform destroy -auto-approve

# Delete Terraform files 
rm -rf .terraform*
rm -rf terraform.tfstate*
```

### **Exp-03: Major terraform file of v2 branch**

#### **Exp-03-01: module folder structure**

- Create `modules` folder then enter it to create a module named `aws-s3-static-website-bucket`
- Copy required files from previous branch for this respective module
- Working directory: `v2-host-static-website-on-s3-using-terraform-module`
  - internal module
    - Module name: aws-s3-static-website-bucket
      - LICENSE
      - main.tf
      - variables.tf
      - outputs.tf
      - README.md
- from inner module `modules/aws-s3-static-website-bucket` directory, copy these files as below to `v2-host-static-website-on-s3-using-terraform-module` 
  - main.tf
  - variables.tf
  - outputs.tf

#### **Exp-03-02: Call module from Working Directory(external module)**

- Modify copied  terraform file
- exp-3-s3bucket.tf

```t
module "website_s3_bucket" {
  source = "./modules/aws-s3-static-website-bucket"
  bucket_name = var.my_s3_bucket
  tags = var.my_s3_tags
}
```

- exp-4-outputs.tf

```t
## S3 Bucket ARN
output "website_bucket_arn" {
  description = "ARN of the bucket"
  value = module.website_s3_bucket.arn 
}

## S3 Bucket Name
output "website_bucket_name" {
  description = "Name (id) of the bucket"
  value = module.website_s3_bucket.name
}

## S3 Bucket Domain
output "website_bucket_domain" {
  description = "Name (id) of the bucket"
  value = module.website_s3_bucket.domain
}

## S3 Bucket Endpoint
output "website_bucket_endpoint" {
  description = "Name (id) of the bucket"
  value = module.website_s3_bucket.endpoint
}
```

#### **Exp-03-03: Execute Terraform Commands**

```t
# Terraform Initialize
terraform init

# Terraform Plan
terraform plan

# Terraform Apply
terraform apply -auto-approve

# Verify 
1. Bucket has static website hosting enabled
2. Bucket has public read access enabled using policy
3. Bucket has "Block all public access" unchecked
```

#### **Exp-03-04: Upload index.html file and test**

```t
# upload index.html file then visite endpoint of website in browser
http://galaxy-mybucket-1025.s3-website.ap-northeast-1.amazonaws.com/
```

#### **Exp-03-05: Destroy and Clean-Up**

```t
# Terraform Destroy
terraform destroy -auto-approve

# Delete Terraform files 
rm -rf .terraform*
rm -rf terraform.tfstate*
```

