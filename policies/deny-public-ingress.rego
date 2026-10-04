package terraform.security.public_ingress

import input.plan as plan

deny := [msg |
    resource := plan.resource_changes[_]
    resource.type == "aws_vpc_security_group_ingress_rule"
    resource.change.after.cidr_ipv4 == "0.0.0.0/0"

    msg := sprintf(
        "%s allows inbound traffic from 0.0.0.0/0. Public ingress is not allowed.",
        [resource.address]
    )
]