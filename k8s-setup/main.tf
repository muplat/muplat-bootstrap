resource "helm_release" "ingress_nginx" {
  name             = "ingress-nginx"
  repository       = "https://kubernetes.github.io/ingress-nginx"
  chart            = "ingress-nginx"
  # Omit version to install the latest chart version.
  create_namespace = true
  namespace        = "ingress-nginx"

  values = [
    yamlencode({
      controller = {
        service = {
          annotations = {
            "service.beta.kubernetes.io/aws-load-balancer-type"                              = "nlb"
            "service.beta.kubernetes.io/aws-load-balancer-scheme"                            = "internet-facing"
            "service.beta.kubernetes.io/aws-load-balancer-cross-zone-load-balancing-enabled" = "true"
            "service.beta.kubernetes.io/aws-load-balancer-subnets"                           = join(",", data.terraform_remote_state.aws_setup.outputs.public_subnets)
            "service.beta.kubernetes.io/aws-load-balancer-security-groups"                   = data.terraform_remote_state.aws_setup.outputs.ingress_nginx_sg

          }
          type = "LoadBalancer"
        }
        tolerations = [
          {
            key    = "service"
            value  = "control-group"
            effect = "NoSchedule"
          }
        ]
        admissionWebhooks = {
          patch = {
            tolerations = [
              {
                key    = "service"
                value  = "control-group"
                effect = "NoSchedule"
              }
            ]
          }
        }
      }
    })
  ]
}
