output "cluster_name" {
    value = module.eks.cluster_name
}

output "public_subnets" {
    value = module.vpc.public_subnets
}

output "cluster_ca_certificate" {
    value = module.eks.cluster_certificate_authority_data
}

output "cluster_endpoint" {
    value = module.eks.cluster_endpoint
}

output "ingress_nginx_sg" {
    value = aws_security_group.ingress_nginx_sg.id
}
