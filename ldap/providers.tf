terraform {
  backend "local" {
    path = "/tf/data/terraform.tfstate"
  }
}

provider vsphere {
  version = "1.14.0"
}

provider "ignition" {
  version = "1.1.0"
}
