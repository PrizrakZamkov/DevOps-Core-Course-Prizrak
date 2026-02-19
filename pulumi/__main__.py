"""Lab 04 - Infrastructure as Code with Pulumi (Yandex Cloud)"""

import pulumi
import pulumi_yandex as yandex

# Configuration
config = pulumi.Config()

# Get configuration values
ssh_public_key = config.require("ssh_public_key")
ssh_user = config.get("ssh_user") or "ubuntu"
vm_name = config.get("vm_name") or "lab04-pulumi-vm"

# Get Ubuntu image
ubuntu_image = yandex.get_compute_image(family="ubuntu-2404-lts")

# Create VPC Network
network = yandex.VpcNetwork(
    "lab04-network",
    name=f"{vm_name}-network",
    labels={
        "environment": "lab04",
        "managed_by": "pulumi",
    },
)

# Create Subnet
subnet = yandex.VpcSubnet(
    "lab04-subnet",
    name=f"{vm_name}-subnet",
    zone="ru-central1-a",
    network_id=network.id,
    v4_cidr_blocks=["10.3.0.0/24"],
    labels={
        "environment": "lab04",
        "managed_by": "pulumi",
    },
)

# Create Security Group (без inline-правил)
security_group = yandex.VpcSecurityGroup(
    "lab04-sg",
    name=f"{vm_name}-sg",
    network_id=network.id,
    description="Security group for lab04 Pulumi VM",
    labels={
        "environment": "lab04",
        "managed_by": "pulumi",
    },
)

# Ingress правила (входящий трафик)
yandex.VpcSecurityGroupRule(
    "sg-allow-ssh",
    security_group_binding=security_group.id,   # ← здесь binding вместо id
    direction="ingress",
    description="Allow SSH from anywhere",
    v4_cidr_blocks=["0.0.0.0/0"],
    protocol="tcp",
    port=22,
)

yandex.VpcSecurityGroupRule(
    "sg-allow-http",
    security_group_binding=security_group.id,   # ← здесь binding
    direction="ingress",
    description="Allow HTTP from anywhere",
    v4_cidr_blocks=["0.0.0.0/0"],
    protocol="tcp",
    port=80,
)

yandex.VpcSecurityGroupRule(
    "sg-allow-app-5000",
    security_group_binding=security_group.id,   # ← здесь binding
    direction="ingress",
    description="Allow application port 5000",
    v4_cidr_blocks=["0.0.0.0/0"],
    protocol="tcp",
    port=5000,
)

# Egress правило (исходящий трафик — всё разрешено)
yandex.VpcSecurityGroupRule(
    "sg-allow-all-egress",
    security_group_binding=security_group.id,   # ← здесь binding
    direction="egress",
    description="Allow all outbound traffic",
    v4_cidr_blocks=["0.0.0.0/0"],
    protocol="any",  # или "ANY" — если не пройдёт, попробуй "ANY"
)

# Create VM Instance
vm = yandex.ComputeInstance(
    "lab04-vm",
    name=vm_name,
    platform_id="standard-v3",
    zone="ru-central1-a",
    resources=yandex.ComputeInstanceResourcesArgs(
        cores=2,
        memory=2,
        core_fraction=20,
    ),
    boot_disk=yandex.ComputeInstanceBootDiskArgs(
        initialize_params=yandex.ComputeInstanceBootDiskInitializeParamsArgs(
            image_id=ubuntu_image.id,
            size=10,
            type="network-hdd",
        ),
    ),
    network_interfaces=[
        yandex.ComputeInstanceNetworkInterfaceArgs(
            subnet_id=subnet.id,
            security_group_ids=[security_group.id],
            nat=True,  # Public IP
        )
    ],
    metadata={
        "ssh-keys": f"{ssh_user}:{ssh_public_key}",
    },
    scheduling_policy=yandex.ComputeInstanceSchedulingPolicyArgs(
        preemptible=False,
    ),
    labels={
        "environment": "lab04",
        "managed_by": "pulumi",
        "purpose": "learning",
    },
)

# Export outputs
pulumi.export("vm_id", vm.id)
pulumi.export("vm_name", vm.name)
pulumi.export("vm_external_ip", vm.network_interfaces[0].nat_ip_address)
pulumi.export("vm_internal_ip", vm.network_interfaces[0].ip_address)
pulumi.export(
    "ssh_connection_string",
    vm.network_interfaces[0].nat_ip_address.apply(
        lambda ip: f"ssh {ssh_user}@{ip}"
    ),
)
pulumi.export("network_id", network.id)
pulumi.export("subnet_id", subnet.id)
pulumi.export("security_group_id", security_group.id)