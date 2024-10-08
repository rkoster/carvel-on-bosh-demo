## Speaker notes


Bottom right:

```bash
bosh ssh -d carvel-on-bosh-demo server
sudo su -

kubectl get nodes
```

Bottom left:
```bash
./manifest/deploy-1.sh
```

Bottom right:
```bash
curl -I https://registry.bosh:5000
```

Bottom left:
```bash
./bin/sync-blobs
cd release
bosh -n create-release --force && bosh -n upload-release
./manifest/deploy-2.sh
```

Bottom right:
```bash
curl https://registry.bosh:5000/v2/repo/tags/list
```

Bottom left:
```bash
./manifest/deploy-3.sh
```

Bottom right:
```bash
# https://carvel.dev/#install
curl -L https://carvel.dev/install.sh | bash

kubectl -n app-ns describe packagerepository carvel.garnier.wf
kctrl package available list -A
```
Bottom right:
```bash
./manifest/deploy-4.sh
```

Bottom left:
```bash
kctrl package installed list -A
kctrl -n app-ns package installed status -i cfday-pkgi
```
