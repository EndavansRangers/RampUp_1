# Secreto para credenciales de base de datos del backend (Dev)
resource "aws_secretsmanager_secret" "backend_db" {
  name        = "tunefy/dev/backend/db"
  description = "Backend database credentials for Dev environment"

  tags = {
    Name        = "tunefy-dev-backend-db"
    Environment = "dev"
    ManagedBy   = "terraform"
  }
}

resource "aws_secretsmanager_secret_version" "backend_db_v1" {
  secret_id = aws_secretsmanager_secret.backend_db.id
  secret_string = jsonencode({
    username = "tunefy"
    password = "tunefy_dev_password"
    host     = "postgresql.tunefy-dev.svc.cluster.local"
    dbname   = "tunefy"
    port     = 5432
  })
}

# Output
output "backend_db_secret_arn" {
  value       = aws_secretsmanager_secret.backend_db.arn
  description = "ARN del secreto de base de datos del backend"
}
