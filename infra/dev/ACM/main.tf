# Dev ACM module - placeholder for development certificates
# In a real dev environment, we would either:
# 1. Use self-signed certificates
# 2. Request temporary certificates from ACM
# 3. Use a different approach entirely
#
# For now, we'll leave this as a placeholder since the dev environment
# won't include Client VPN functionality

variable "dev_prefix" {
  description = "Prefix for dev resources"
  type        = string
  default     = "dev/"
}

# This is a placeholder file - in a full implementation, 
# we would define dev-specific certificates here