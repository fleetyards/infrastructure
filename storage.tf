resource "aws_s3_bucket" "storage" {
  bucket = "fltyrd-${terraform.workspace}-storage"
}

resource "aws_s3_bucket_cors_configuration" "storage" {
  bucket = aws_s3_bucket.storage.id

  dynamic "cors_rule" {
    for_each = local.env.cors_origins
    content {
      allowed_headers = ["*"]
      allowed_methods = ["GET", "PUT", "DELETE", "HEAD", "POST"]
      allowed_origins = [cors_rule.value]
      expose_headers  = ["ETag"]
      max_age_seconds = 3600
    }
  }
}

resource "aws_s3_bucket" "backups" {
  bucket = "fltyrd-${terraform.workspace}-backups"
}
