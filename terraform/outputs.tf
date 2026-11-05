output "ec2_public_ip" {
  value = aws_instance.app.public_ip
}

output "ec2_instance_id" {
  value = aws_instance.app.id
}

output "ecr_repository_urls" {
  value = { for name, repo in aws_ecr_repository.services : name => repo.repository_url }
}

output "ssh_command" {
  value = "ssh -i <your-key.pem> ubuntu@${aws_instance.app.public_ip}"
}
