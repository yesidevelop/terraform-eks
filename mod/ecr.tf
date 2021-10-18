# resource "aws_ecr_repository" "testecr" {
#   name                 = "testecr"
#   image_tag_mutability = "MUTABLE"

#   image_scanning_configuration {
#     scan_on_push = true
#   }
# }