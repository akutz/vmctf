terraform {
  backend "local" {
    path = "/tf/data/terraform.tfstate"
  }
}

provider vsphere {}
