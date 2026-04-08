# Tabla única: throttle / rate limit (email cooldown + ventana por IP).
# Ítems: pk/sk según convención de la app; TTL = expires_at (Number, epoch seconds).
# Atributos no clave (created_at, updated_at, count, window_start) solo en el backend.

locals {
  api_throttle_locks_table_name = var.api_throttle_locks_table_name != "" ? var.api_throttle_locks_table_name : "cloudflax-${var.environment}-api-throttle-locks"
}

resource "aws_dynamodb_table" "api_throttle_locks" {
  name         = local.api_throttle_locks_table_name
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "pk"
  range_key    = "sk"

  attribute {
    name = "pk"
    type = "S"
  }

  attribute {
    name = "sk"
    type = "S"
  }

  ttl {
    attribute_name = "expires_at"
    enabled        = true
  }

  point_in_time_recovery {
    enabled = true
  }

  server_side_encryption {
    enabled = true
  }

  tags = {
    Name        = local.api_throttle_locks_table_name
    Environment = var.environment
    Project     = "cloudflax"
  }
}
