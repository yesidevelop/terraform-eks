resource "aws_elasticache_subnet_group" "default" {
  name       = var.environment_name
  subnet_ids = concat(aws_subnet.private.*.id, aws_subnet.public.*.id)
}

output "redis_elasticache_subnet_group_name" {
  value = aws_elasticache_subnet_group.default.name
}

# resource "aws_elasticache_parameter_group" "default" {
#   name   = "cache-params"
#   family = "redis2.8"

#   parameter {
#     name  = "activerehashing"
#     value = "yes"
#   }

#   parameter {
#     name  = "min-slaves-to-write"
#     value = "2"
#   }
# }

resource "aws_elasticache_cluster" "default" {
  count      = var.redis_enabled ? 1 : 0
  cluster_id = var.environment_name

  engine    = "redis"
  node_type = var.redis_node_type

  num_cache_nodes = 1
  engine_version  = var.redis_engine_version
  // TODO: Need to implement the parameter group
  // parameter_group_name = aws_elasticache_parameter_group.default.id
  port = 6379

  subnet_group_name  = aws_elasticache_subnet_group.default.name
  security_group_ids = [aws_security_group.node.id]

  tags = {
    "KubespotEnvironment" = var.environment_name
  }
}
