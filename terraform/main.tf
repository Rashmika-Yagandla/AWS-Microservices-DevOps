resource "aws_instance" "app" {
  ami           = data.aws_ami.ubuntu.id
  instance_type = var.instance_type

  subnet_id = "subnet-00f4f30c1fe0241fc"

  key_name = var.key_pair_name

  vpc_security_group_ids = [
    aws_security_group.app.id
  ]
}