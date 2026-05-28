output "instance_id" {
  description = "OCID of the compute instance"
  value       = oci_core_instance.main.id
}

output "public_ip" {
  description = "Reserved public IP address"
  value       = oci_core_public_ip.main.ip_address
}

output "ssh_command" {
  description = "Command to SSH into the instance"
  value       = "ssh opc@${oci_core_public_ip.main.ip_address}"
}
