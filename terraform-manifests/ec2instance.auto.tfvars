# EC2 Instance Variables
# these defined value of variable will overwrite to exp-7-01-ec2instance-variables.tf in higher priority
# understand this point, so, I will set those value same with exp-7-01-ec2instance-variables.tf in this case
instance_type = "t2.micro"
instance_keypair = "terraform-key"
private_instance_count = 2
