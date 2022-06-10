# Create a Null Resource and Provisioners
# Connection to remote bastion EC2 VM via null_resource

resource "null_resource" "name" {
  depends_on = [ module.ec2_public ]

  # Connection block for provisioners to connect to EC2 Instance
  connection {
      type = "ssh"
      host = aws_eip.bastion_eip.public_ip
      user = "ec2-user"
      password = ""
      private_key = file("private-key/terraform-key.pem")
  }

  # file provisioner: copy the private key file to /home/ec2-user/.ssh
  provisioner "file" {
      source = "private-key/terraform-key.pem"
      destination = "/home/ec2-user/.ssh/terraform-key.pem"
  }

  # remote exec provisioner, fix the private key permission issue
  provisioner "remote-exec" {
    inline = [
      "sudo chmod 400 /home/ec2-user/.ssh/terraform-key.pem"
    ]
  }
  
  # local exec provisioner
  # local-exec provisioner invokes a local executable after a resource is created.
  # this invokes a process on the machine running terraform, not on the resouce

  # demo creation time provisioner and destroy time provisioner
  # creation time provisioner. By default they are created during resource creations(terraform apply)
  # local-exec provisioner, creation-time provisioner, triggered during create resource
  provisioner "local-exec" {
    command = "echo VPC created on `date` and VPC ID: ${module.vpc.vpc_id} >> creation-time-vpc-id.txt"
    working_dir = "local-exec-output-files/"
    #on_failure = continue
  }

  # destroy time provisioner. Will be executed during "terraform destroy" command (when = destroy)
  # local-exec provisioner, destroy-time provisioner, triggered during deletion resource

  # NOTE: this below local-exec section of destroy-time need to be commented out or move to other resource
  provisioner "local-exec" {
    command = "echo Destroy time prov `date` >> destroy-time-prov.txt"
    working_dir = "local-exec-output-files/"
    when = destroy
    #on_failure = continue
  }
}