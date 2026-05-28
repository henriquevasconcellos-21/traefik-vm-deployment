locals {
  stack_name  = "traefik-vm"
  common_tags = {
    owner   = var.owner
    purpose = var.purpose
  }

  user_data = <<-EOT
    #!/bin/bash
    set -euo pipefail
    dnf update -y
    dnf install -y docker git
    systemctl enable docker
    systemctl start docker
    usermod -a -G docker opc
    mkdir -p /usr/local/lib/docker/cli-plugins
    curl -SL https://github.com/docker/compose/releases/download/${var.docker_compose_version}/docker-compose-linux-aarch64 -o /usr/local/lib/docker/cli-plugins/docker-compose
    chmod +x /usr/local/lib/docker/cli-plugins/docker-compose
    ln -s /usr/local/lib/docker/cli-plugins/docker-compose /usr/bin/docker-compose
    mkdir -p /home/opc/app
    chown opc:opc /home/opc/app
  EOT
}

# --- Networking ---

resource "oci_core_vcn" "main" {
  compartment_id = var.compartment_ocid
  cidr_blocks    = ["10.0.0.0/16"]
  display_name   = "${local.stack_name}-vcn"
  dns_label      = "main"
  freeform_tags  = local.common_tags
}

resource "oci_core_internet_gateway" "main" {
  compartment_id = var.compartment_ocid
  vcn_id         = oci_core_vcn.main.id
  display_name   = "${local.stack_name}-igw"
  freeform_tags  = local.common_tags
}

resource "oci_core_route_table" "main" {
  compartment_id = var.compartment_ocid
  vcn_id         = oci_core_vcn.main.id
  display_name   = "${local.stack_name}-rt"
  freeform_tags  = local.common_tags

  route_rules {
    network_entity_id = oci_core_internet_gateway.main.id
    destination       = "0.0.0.0/0"
    destination_type  = "CIDR_BLOCK"
  }
}

resource "oci_core_security_list" "main" {
  compartment_id = var.compartment_ocid
  vcn_id         = oci_core_vcn.main.id
  display_name   = "${local.stack_name}-sl"
  freeform_tags  = local.common_tags

  egress_security_rules {
    destination = "0.0.0.0/0"
    protocol    = "all"
  }

  ingress_security_rules {
    protocol = "6"
    source   = "0.0.0.0/0"
    tcp_options {
      min = 80
      max = 80
    }
  }

  ingress_security_rules {
    protocol = "6"
    source   = "0.0.0.0/0"
    tcp_options {
      min = 443
      max = 443
    }
  }

  ingress_security_rules {
    protocol = "6"
    source   = var.ssh_cidr
    tcp_options {
      min = 22
      max = 22
    }
  }
}

resource "oci_core_subnet" "main" {
  compartment_id    = var.compartment_ocid
  vcn_id            = oci_core_vcn.main.id
  cidr_block        = "10.0.1.0/24"
  display_name      = "${local.stack_name}-subnet"
  dns_label         = "main"
  route_table_id    = oci_core_route_table.main.id
  security_list_ids = [oci_core_security_list.main.id]
  freeform_tags     = local.common_tags
}

# --- Compute ---

data "oci_core_images" "oracle_linux" {
  compartment_id           = var.compartment_ocid
  operating_system         = "Oracle Linux"
  operating_system_version = "9"
  shape                    = var.instance_shape
  sort_by                  = "TIMECREATED"
  sort_order               = "DESC"
}

resource "oci_core_instance" "main" {
  compartment_id      = var.compartment_ocid
  availability_domain = var.availability_domain
  shape               = var.instance_shape
  display_name        = "${local.stack_name}-server"
  freeform_tags       = local.common_tags

  shape_config {
    ocpus         = var.ocpus
    memory_in_gbs = var.memory_in_gbs
  }

  source_details {
    source_type             = "image"
    source_id               = data.oci_core_images.oracle_linux.images[0].id
    boot_volume_size_in_gbs = var.boot_volume_size_in_gbs
  }

  create_vnic_details {
    subnet_id        = oci_core_subnet.main.id
    display_name     = "${local.stack_name}-vnic"
    assign_public_ip = false
    freeform_tags    = local.common_tags
  }

  metadata = {
    ssh_authorized_keys = var.ssh_public_key
    user_data           = base64encode(local.user_data)
  }
}

# --- Reserved Public IP ---

data "oci_core_vnic_attachments" "main" {
  compartment_id = var.compartment_ocid
  instance_id    = oci_core_instance.main.id
}

data "oci_core_vnic" "main" {
  vnic_id = data.oci_core_vnic_attachments.main.vnic_attachments[0].vnic_id
}

data "oci_core_private_ips" "main" {
  ip_address = data.oci_core_vnic.main.private_ip_address
  subnet_id  = oci_core_subnet.main.id
}

resource "oci_core_public_ip" "main" {
  compartment_id = var.compartment_ocid
  lifetime       = "RESERVED"
  display_name   = "${local.stack_name}-ip"
  freeform_tags  = local.common_tags
  private_ip_id  = data.oci_core_private_ips.main.private_ips[0].id
}
