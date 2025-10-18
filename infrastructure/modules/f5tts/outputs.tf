output "debug_ami" {
  value = {
    provided_ami_id = var.ami_id
    ami_length      = length(var.ami_id)
    is_ami_empty    = var.ami_id == ""
  }
}