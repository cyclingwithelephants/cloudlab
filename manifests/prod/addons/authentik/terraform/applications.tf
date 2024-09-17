# locals {
#   media_applications = toset([
#     "overseerr",
#     "tautulli",
#   ])

#   download_applications = toset([
#     "bazarr",
#     "prowlarr",
#     "qbittorrent",
#     "radarr",
#     "readarr",
#     "sabnzbd",
#     "sonarr",
#   ])

#   infra_applications = toset([
#     "longhorn",
#     "nas",
#     "tdarr"
#   ])

#   proxy_list = concat(
#     values(authentik_provider_proxy.download_proxy)[*].id,
#     values(authentik_provider_proxy.media_proxy)[*].id,
#     values(authentik_provider_proxy.infra_proxy)[*].id,
#     [authentik_provider_proxy.hass_proxy.id]
#   )
# }

### Proxy Providers ###
## Downloads ##
# resource "authentik_provider_proxy" "download_proxy" {
#   for_each              = local.download_applications
#   name                  = "${each.value}-provider"
#   external_host         = "http://${each.value}.${data.sops_file.authentik_secrets.data["cluster_domain"]}"
#   mode                  = "forward_single"
#   authorization_flow    = resource.authentik_flow.provider-authorization-implicit-consent.uuid
#   access_token_validity = "hours=4"
# }

# resource "authentik_application" "download_application" {
#   for_each           = local.download_applications
#   name               = title(each.value)
#   slug               = authentik_provider_proxy.download_proxy[each.value].name
#   protocol_provider  = authentik_provider_proxy.download_proxy[each.value].id
#   group              = authentik_group.downloads.name
#   open_in_new_tab    = true
#   meta_icon          = "https://raw.githubusercontent.com/LilDrunkenSmurf/k3s-home-cluster/main/icons/${each.value}.png"
#   policy_engine_mode = "all"
# }

## Infra ##
# resource "authentik_provider_proxy" "infra_proxy" {
#   for_each              = local.infra_applications
#   name                  = "${each.value}-provider"
#   external_host         = "http://${each.value}.${data.sops_file.authentik_secrets.data["cluster_domain"]}"
#   mode                  = "forward_single"
#   authorization_flow    = resource.authentik_flow.provider-authorization-implicit-consent.uuid
#   access_token_validity = "hours=4"
# }

# resource "authentik_application" "infra_application" {
#   for_each           = local.infra_applications
#   name               = title(each.value)
#   slug               = authentik_provider_proxy.infra_proxy[each.value].name
#   protocol_provider  = authentik_provider_proxy.infra_proxy[each.value].id
#   group              = authentik_group.infrastructure.name
#   open_in_new_tab    = true
#   meta_icon          = "https://raw.githubusercontent.com/LilDrunkenSmurf/k3s-home-cluster/main/icons/${each.value}.png"
#   policy_engine_mode = "all"
# }

## Media ##
# resource "authentik_provider_proxy" "media_proxy" {
#   for_each                      = local.media_applications
#   name                          = "${each.value}-provider"
#   basic_auth_enabled            = true
#   basic_auth_username_attribute = data.sops_file.authentik_secrets.data["${each.value}_username"]
#   basic_auth_password_attribute = data.sops_file.authentik_secrets.data["${each.value}_password"]
#   external_host                 = "http://${each.value}.${data.sops_file.authentik_secrets.data["cluster_domain"]}"
#   mode                          = "forward_single"
#   authorization_flow            = resource.authentik_flow.provider-authorization-implicit-consent.uuid
#   access_token_validity         = "hours=4"
# }

# resource "authentik_application" "media_application" {
#   for_each           = local.media_applications
#   name               = title(each.value)
#   slug               = authentik_provider_proxy.media_proxy[each.value].name
#   protocol_provider  = authentik_provider_proxy.media_proxy[each.value].id
#   group              = authentik_group.media.name
#   open_in_new_tab    = true
#   meta_icon          = "https://raw.githubusercontent.com/LilDrunkenSmurf/k3s-home-cluster/main/icons/${each.value}.png"
#   policy_engine_mode = "all"
# }

## HASS ##
# resource "authentik_provider_proxy" "hass_proxy" {
#   name                  = "home-assistant-provider"
#   external_host         = "http://hass.${data.sops_file.authentik_secrets.data["cluster_domain"]}"
#   mode                  = "forward_single"
#   authorization_flow    = resource.authentik_flow.provider-authorization-implicit-consent.uuid
#   access_token_validity = "hours=4"
# }

# resource "authentik_application" "hass_application" {
#   name               = "Home-Assistant"
#   slug               = authentik_provider_proxy.hass_proxy.name
#   protocol_provider  = authentik_provider_proxy.hass_proxy.id
#   group              = authentik_group.home.name
#   open_in_new_tab    = true
#   meta_icon          = "https://raw.githubusercontent.com/walkxcode/dashboard-icons/main/png/home-assistant.png"
#   policy_engine_mode = "all"
# }

# ### Oauth2 Providers ###
# ## Grafana ##
# resource "authentik_provider_oauth2" "grafana_oauth2" {
#   name                  = "grafana-provider"
#   client_id             = data.sops_file.authentik_secrets.data["grafana_id"]
#   client_secret         = data.sops_file.authentik_secrets.data["grafana_secret"]
#   authorization_flow    = resource.authentik_flow.provider-authorization-implicit-consent.uuid
#   property_mappings     = data.authentik_scope_mapping.oauth2.ids
#   access_token_validity = "hours=4"
#   redirect_uris         = ["https://grafana.${data.sops_file.authentik_secrets.data["cluster_domain"]}/login/generic_oauth"]
# }
# 
# resource "authentik_application" "grafana_application" {
#   name               = "Grafana"
#   slug               = authentik_provider_oauth2.grafana_oauth2.name
#   protocol_provider  = authentik_provider_oauth2.grafana_oauth2.id
#   group              = authentik_group.monitoring.name
#   open_in_new_tab    = true
#   meta_icon          = "https://raw.githubusercontent.com/walkxcode/dashboard-icons/main/png/grafana.png"
#   meta_launch_url    = "https://grafana.${data.sops_file.authentik_secrets.data["cluster_domain"]}/login/generic_oauth"
#   policy_engine_mode = "all"
# }
