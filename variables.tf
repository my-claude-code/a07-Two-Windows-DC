variable "subscription_id" {
  description = "Azure subscription ID"
  type        = string
  sensitive   = true
}

variable "admin_username" {
  description = "VM and domain administrator username"
  type        = string
  default     = "ivansto"
}

variable "admin_password" {
  description = "Initial VM and domain administrator password"
  type        = string
  default     = "ClaudeCode2023!"
  sensitive   = true
}

variable "vm_size" {
  description = "VM size for both domain controllers"
  type        = string
  default     = "Standard_B2s_v2"
}
