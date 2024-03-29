variable "default_network_acl_id" {
  description = "The ID of the default acl for the vpc to attach the network acl to"
}

resource "aws_default_network_acl" "default" {
  default_network_acl_id = var.default_network_acl_id

  ingress {
    protocol   = "-1"
    rule_no    = 100
    action     = "deny"
    cidr_block = "195.54.160.0/23"
    from_port  = 0
    to_port    = 0
  }

  ingress {
    protocol   = "-1"
    rule_no    = 101
    action     = "deny"
    cidr_block = "183.136.224.0/22"
    from_port  = 0
    to_port    = 0
  }

  ingress {
    protocol   = "-1"
    rule_no    = 10000
    action     = "allow"
    cidr_block = "0.0.0.0/0"
    from_port  = 0
    to_port    = 0
  }

  egress {
    protocol   = "-1"
    rule_no    = 10000
    action     = "allow"
    cidr_block = "0.0.0.0/0"
    from_port  = 0
    to_port    = 0
  }

  tags = {
    Name = terraform.workspace
  }

  lifecycle {
    ignore_changes = [subnet_ids]
  }
}

