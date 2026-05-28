variable "tenancy_ocid" {
  description = "OCID of your OCI tenancy"
  type        = string
}

variable "user_ocid" {
  description = "OCID of the OCI user making API calls"
  type        = string
}

variable "fingerprint" {
  description = "Fingerprint of the API signing key"
  type        = string
}

variable "private_key_path" {
  description = "Local path to the private API signing key (.pem)"
  type        = string
}

variable "region" {
  description = "OCI region to deploy into"
  type        = string
  default     = "us-ashburn-1"
}

variable "compartment_ocid" {
  description = "OCID of the compartment to create resources in"
  type        = string
}

variable "availability_domain" {
  description = "Availability domain name (e.g. Uocm:US-ASHBURN-AD-1)"
  type        = string
}

variable "ssh_public_key" {
  description = "Public SSH key content to install on the instance"
  type        = string
}

variable "ssh_cidr" {
  description = "CIDR range allowed to SSH into the instance"
  type        = string
}

variable "instance_shape" {
  description = "Compute shape (VM.Standard.A1.Flex is always-free ARM)"
  type        = string
  default     = "VM.Standard.A1.Flex"
}

variable "ocpus" {
  description = "Number of OCPUs (free tier: up to 4 total across all ARM instances)"
  type        = number
  default     = 1
}

variable "memory_in_gbs" {
  description = "Memory in GBs (free tier: up to 24 total across all ARM instances)"
  type        = number
  default     = 6
}

variable "boot_volume_size_in_gbs" {
  description = "Boot volume size in GBs (free tier: 200 GB total across all volumes)"
  type        = number
  default     = 50
}

variable "docker_compose_version" {
  description = "Docker Compose version to install"
  type        = string
  default     = "v2.29.0"
}

variable "owner" {
  description = "Owner tag value"
  type        = string
  default     = "admin"
}

variable "purpose" {
  description = "Purpose tag value"
  type        = string
  default     = "Traefik Deployment"
}
