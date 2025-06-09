include {
  path = find_in_parent_folders()
}

terraform {
  source = "../../../modules/cognito"
}

inputs = {
  user_pool_name = "laas-dev-users"
}
