terraform {
  backend "local" {
    path = "/tf/data/terraform.tfstate"
  }
}

provider vsphere {}

provider "ignition" {
  version = "1.1.0"
}
