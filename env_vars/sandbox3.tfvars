terraform_state = {
  bucket = "937405989913-codetools-play-tf-state"
  key    = "hello_world_lambda/terraform.tfstate"
}

namespace = "example"
stage     = "dev"
name      = "hello-world"

tags      = {
  Owner = "Airwalk Consulting"
}
