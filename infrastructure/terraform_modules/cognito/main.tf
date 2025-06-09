resource "aws_cognito_user_pool" "this" {
  name = var.user_pool_name
}

resource "aws_cognito_user_pool_client" "client" {
  name         = "${var.user_pool_name}-client"
  user_pool_id = aws_cognito_user_pool.this.id
  generate_secret = false
}
