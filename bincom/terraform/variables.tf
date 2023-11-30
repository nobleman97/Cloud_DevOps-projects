variable "vpc_cidr" {
  type    = string
  default = "172.16.0.0/16"
}

variable "subnets" {
  type = map(object({
    cidr_block = string
    name       = string
  }))
  default = {
    "web" = {
      name       = "web"
      cidr_block = "172.16.1.0/24"
    }
    "mysql" = {
      name       = "mysql"
      cidr_block = "172.16.2.0/24"
    }
    "nat" = {
      name       = "nat"
      cidr_block = "172.16.3.0/24"
    }
  }
}

variable "vm" {
  type = map(object({
    name       = string
    assign_ip  = bool
    private_ip = list(string)
  }))
  default = {
    "web" = {
      name       = "web"
      assign_ip  = true
      private_ip = ["172.16.1.16"]
    }
    "mysql" = {
      name       = "mysql"
      assign_ip  = false
      private_ip = ["172.16.2.16"]
    }
  }
}