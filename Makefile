


talos:
	kubectl get secret cloudlab-talos -n cluster -o json | jq -r ".data.bundle" | base64 -D

talos-config:
	kubectl get secret cloudlab-talosconfig -n cluster -o json | jq -r ".data.talosconfig" | base64 -D > ${HOME}/.talos/config
