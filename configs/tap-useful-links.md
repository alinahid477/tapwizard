Setup run cluster and and integrate with GUI cluster:
https://docs.vmware.com/en/VMware-Tanzu-Application-Platform/1.3/tap/GUID-tap-gui-cluster-view-setup.html

**Important**: Must also add the gui cluster itself in the multi cluster section.
for cluster token you can use existing tap-gui sa.
eg: CLUSTER_TOKEN=$(kubectl -n tap-gui get secret $(kubectl -n tap-gui get sa tap-gui -o=json \
| jq -r '.secrets[0].name') -o=json \
| jq -r '.data["token"]' \
| base64 --decode)


Gui Authentication:
https://docs.vmware.com/en/VMware-Tanzu-Application-Platform/1.3/tap/GUID-tap-gui-auth.html


Github Integration:
https://docs.vmware.com/en/VMware-Tanzu-Application-Platform/1.3/tap/GUID-tap-gui-integrations.html