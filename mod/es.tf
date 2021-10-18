# resource "aws_elasticsearch_domain" "es" {
#   domain_name           = "test-es"
#   elasticsearch_version = "7.10"

#   cluster_config {
#     instance_type = "t2.small.elasticsearch"
#   }

#   ebs_options {
#       volume_size = 11
#       ebs_enabled = true
#   }
# #   advanced_security_options {
# #       enabled = true
# #       master_user_options {
# #           master_user_name = "root"
# #           master_user_password = "Allied111*"
# #       }
# #   }
# #   node_to_node_encryption {
# #       enabled = true
# #   }
#   tags = {
#     Domain = "test-es"
#   }
# }