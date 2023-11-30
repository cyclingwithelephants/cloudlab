terraform {
  required_providers {
    authentik = {
      source  = "goauthentik/authentik"
      version = "2023.10.0"
    }
  }
#   backend "kubernetes" {
#     secret_suffix     = "authentik"
#     namespace         = "default"
#     in_cluster_config = true
#   }
}

provider "authentik" {
  url   = "https://authentik.prod.adamland.xyz"
  token = "DiSx7zkkyg@9ijsijGp!#@p@DJAt#QWE*8G8Tf2Svq%4SbK^qR"
}