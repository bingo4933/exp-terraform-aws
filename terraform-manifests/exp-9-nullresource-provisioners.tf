resource "null_resource" "name" {
  depends_on = [ module.ec2_public ]

  connection {
      type = "ssh"
      host = aws_eip.bastion_eip.public_ip
      user = "ec2-user"
      password = ""
      private_key = file("private-key/terraform-key.pem")
  }

  provisioner "file" {
      source = "private-key/terraform-key.pem"
      destination = "/home/ec2-user/.ssh/terraform-key.pem"
  }

  provisioner "remote-exec" {
    inline = [
      "sudo chmod 400 /home/ec2-user/.ssh/terraform-key.pem"
    ]
  }
  
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