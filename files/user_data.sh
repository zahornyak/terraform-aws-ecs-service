#!/bin/bash
echo ECS_CLUSTER=${cluster} >> /etc/ecs/ecs.config
echo ECS_AVAILABLE_LOGGING_DRIVERS='["gelf", "awslogs", "json-file"]' >> /etc/ecs/ecs.config
yum update -y
yum install -y awscli
sudo yum install -y https://s3.amazonaws.com/ec2-downloads-windows/SSMAgent/latest/linux_amd64/amazon-ssm-agent.rpm -y
sudo systemctl enable amazon-ssm-agent
sudo systemctl start amazon-ssm-agent