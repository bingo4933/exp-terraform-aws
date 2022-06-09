## **Build AWS EC2 Instance, Security Groups using Terraform**



### **Exp-01: Introduction & Pre-requisite**

In this branch we will create a core 3-Tier architecture functionality via these component as below

- aws vpc module
- aws ec2 module
- aws security group module
- aws elasticIP resource 
- nullresource-provisioner
- depends_on meta-argument
- varied type of declaration  variable of terraform 

Will  utilize via these ones:

- [terraform-aws-modules/vpc/aws](https://registry.terraform.io/modules/terraform-aws-modules/vpc/aws/latest)
- [terraform-aws-modules/security-group/aws](https://registry.terraform.io/modules/terraform-aws-modules/security-group/aws/latest)
- [terraform-aws-modules/ec2-instance/aws](https://registry.terraform.io/modules/terraform-aws-modules/ec2-instance/aws/latest)

> Note: need to prepared these staff before implementing
>
> - copy your AWS EC2 key pair `terraform-key.pem` in `private-key` folder
> - folder name to `local-exec-output-files` where `local-exec` provisioner will create file

### **Exp02: Implement to terraform commands**

```t
# terraform initialize
$ terraform init

# terraform validation
$ terraform validate

# terraform plan
$ terraform plan

# apply it
$ terraform apply -auto-approve
```

### **Exp03: Connect to bastion EC2 Instance and Test**

```t
# connecto to ec2 instance
$ ssh -i private-key/terraform-key.pem ec2-user@<PUBLIC_IP_FOR_BASTION_HOST>

# curl to test
$ curl http://<PRIVATE_INSTANCE-1-private-IP>
$ curl http://<PRIVATE_INSTANCE-2-private-IP>

# connect to private EC2 instance from bastion EC2 instance
$ ssh ec2-user@<private-instance-1-private-IP>
$ cd /var/www/html
$ curl http://169.254.169.254/latest/user-data

$ cd /var/log
$ sudo su - 
# more cloud-init-output.log
```

### **Exp04: Clean-Up**

```t
# terraform destroy
$ terraform destroy -auto-approve

# clean up
$ rm -rf .terraform*
$ rm -rf terraform.tfstate*
```

