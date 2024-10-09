---
theme:
  name: catppuccin-latte
  override:
    default:
      margin:
        percent: 8
    footer:
      style: empty
title: Carvel on Bosh
sub_title: A match made in heaven?
author: Ruben Koster
---

About me
===

<!-- column_layout: [1,1] -->

<!-- column: 0 -->
<!-- new_lines: 1 -->

## Ruben Koster

Tech Lead @ VMware Tanzu by Broadcom
<!-- new_lines: 1 -->
Cloud Foundry Foundation:
- Technical Oversight Comittee member
- Tech Lead Foundational Infrastructure Working Group

<!-- new_lines: 1 -->
On the web:

- github.com/rkoster
- linkedin.com/in/rukoster/

<!-- column: 1 -->
<!-- new_lines: 1 -->
<!-- end_slide -->

Prequel
===

<!-- column_layout: [1,1] -->
<!-- column: 0 -->

## Project Carvel: Composable Tools for Application Management

**by:** Daniel Garnier-Moiroux & Soumik Majumder, Broadcom
<!-- new_lines: 0 -->
**at:** KubeCon + CloudNativeCon EU 2024

- **ytt** YAML templating and manipulation
- **kapp** Friendlier kubectl
- **kbld** Resolve image names to their SHA sums
- **imgpkg** Package config files as an OCI image
- **kapp-controller** Compose these tools together for "GitOps"

<!-- column: 1 -->

```
█████████████████████████████████
██ ▄▄▄▄▄ █▀▀ ██▄  ▀██▄██ ▄▄▄▄▄ ██
██ █   █ █▄▀███▀▀ ▀ ▀▀ █ █   █ ██
██ █▄▄▄█ █ ▄ █▄▄    ▄▀▀█ █▄▄▄█ ██
██▄▄▄▄▄▄▄█ █ █▄█ ▀ ▀▄█ █▄▄▄▄▄▄▄██
██▄▄█ ██▄▄█▀█▀▄▄▄▀▀▀▀ ▀█ ▄▄▀▄▄▀██
███ █  █▄▄▄▀▀▀▀ █▀▄█  █▄█▀▄▄  ███
████ ▄█▀▄▄▄▀▄▀ ▄▀▄▄▄▀▀█▀▄▄█▄█▄▄██
██▄▄▀  █▄█▄▄▀▄▀ ▀▀▀  ▀  ▀█▄ ▄ ▄██
███▄█▄ █▄▀█▄██ ▀▄▄█▄▀▄█ ▀ █▀█▄▀██
██▄█▀▀ ▀▄▀█  ▀▀█▀▀█ ▄██▀▄▄▀██  ██
██▄█▄▄██▄▄▀██ ▀▄▄▄█ ██ ▄▄▄ █ ▀▀██
██ ▄▄▄▄▄ █▄▄▀█▀  ▀▄█ ▀ █▄█ ▀▀▄███
██ █   █ █▀▄ █▀▀█▄▄▄ ▀ ▄   ▀▀█▄██
██ █▄▄▄█ █▀ ▀▄▀▀▄██▀▀  ███▄▄▄▀▄██
██▄▄▄▄▄▄▄█▄▄█▄▄▄██▄▄█▄▄▄█████▄███
█████████████████████████████████
```
<!-- end_slide -->


On the menu
===

## 0. Deploy k3s using Bosh
Use the execelent k3s bosh release by Orange as a starting point

## 1. Deploy a local registry with Bosh
Deploy the docker-registry-boshrelease and make sure it is trusted by k3s

## 2. Packaging OCI Images
Relocate a carvel package repository into a bosh release

## 3. Install kapp-controller
Deploy kapp-controller via a k3s addon

## 4. Deploy demo app using PackageInstall CRD
Deploy the app from the prequel with bosh

## 5. Profit

<!-- end_slide -->

1 - Deploy a local registry with Bosh
===

<!-- column_layout: [1,1] -->
<!-- column: 0 -->

```yaml
# org:  cloudfoundry-community
# repo: docker-registry-boshrelease
instance_groups:
- jobs:
  - { name: ca_certs, release: os-conf }
  - name: registry
    release: docker-registry
    custom_provider_definitions:
    - name: registry # add a custom link
      type: address
      shared: true
    provides:
      registry:
        aliases:
        - domain: registry.bosh
          health_filter: all
        as: registry-address
  properties:
    certs: ((registry_tls.ca))
    docker:
      registry:
        bind: 0.0.0.0
        port: 5000
        ssl:
          cert: ((registry_tls.certificate))
          key: ((registry_tls.private_key))
```

<!-- column: 1 -->
```yaml
variables:
- name: registry_ca
  type: certificate
  update_mode: converge
  options:
    common_name: ca
    is_ca: true
- name: registry_tls
  type: certificate
  update_mode: converge
  options:
    ca: registry_ca
    alternative_names:
    - localhost
    - registry.bosh
    common_name: registry-bosh
  consumes:
    alternative_name:
      from: registry-address
```
<!-- end_slide -->


2.1 - Packaging OCI Images
===

```bash
# Start a temporary registry
export REGISTRY_STORAGE_FILESYSTEM_ROOTDIRECTORY=/tmp/registry
export REGISTRY_HTTP_ADDR="localhost:5000"

registry serve <(echo "version: 0.1")

# Copy the image bundle to our temporary registry
IMAGE=index.docker.io/dgarnier963/carvel-package-repository
VERSION=5fb39deab2298aac206549cd95d023c4095ccdbefcfc376c5486b6df48d2f000

imgpkg copy --bundle "${IMAGE}@sha256:${VERSION}" \
            --to-repo localhost:5000/repo

# Find all blob and repository metadata files
pushd "/tmp/registry/docker/registry/v2/"
  BLOBS=$(find blobs -type f)
  REPOS=$(find repositories -type f)
popd

# Add image blobs as bosh blobs
echo "${BLOBS}" | xargs -I {} bosh add-blob "/tmp/registry/docker/registry/v2/{}" {}

# Copy repository metadata files into release src directory
echo "${REPOS}" | xargs -I {} bash \
  -c 'mkdir -p src/$(dirname {}) && cp /tmp/registry/docker/registry/v2/{} $(dirname src/{})/'
```

<!-- end_slide -->

2.2 - Packaging OCI Images
===

```yaml
# release/packages/registry-data
---
name: registry-data

dependencies: []

files:
- repositories/**/*
- blobs/**/*
```

```bash
# release/packages/packaging
set -e

mkdir -p ${BOSH_INSTALL_TARGET}/docker/registry/v2

cp -r {repositories,blobs} ${BOSH_INSTALL_TARGET}/docker/registry/v2/
```

```yaml
# manifest/manifest.yml
instance_groups:
- properties:
    docker:
      registry:
        root: /var/vcap/packages/registry-data
```

<!-- end_slide -->

3.1 - Install kapp-controller
===

```bash
curl -L -s https://github.com/carvel-dev/kapp-controller/releases/latest/download/release.yml \
   | yq ea '[{"type": "replace",
              "path": "/instance_groups/name=server/properties/k3s/additional-manifests/-",
              "value": .}]'
```

```yaml
- type: replace
  path: /instance_groups/name=server/properties/k3s/additional-manifests/-
  value:
    apiVersion: v1
    kind: Namespace
    metadata:
      name: kapp-controller
- type: replace
  path: /instance_groups/name=server/properties/k3s/additional-manifests/-
  value:
    apiVersion: v1
    kind: Namespace
    metadata:
      name: kapp-controller-packaging-global
...
```

<!-- end_slide -->

3.2 - Install kapp-controller
===

```yaml
# manifest/manifest.yml
instance_groups:
- properties:
    script: |
      #!/bin/bash

      mkdir -p /var/vcap/store/k3s-server/server/manifests
      cat << EOF > /var/vcap/store/k3s-server/server/manifests/registry-ca.yaml
      ---
      apiVersion: v1
      kind: Secret
      metadata:
        name: kapp-controller-config
        namespace: kapp-controller
      stringData:
        caCerts: |
      EOF

      # Fix certificate indentation
      sed 's/^/    /g' >> /var/vcap/store/k3s-server/server/manifests/registry-ca.yaml  <<EOF
      ((registry_tls.ca))
      EOF
```

```yaml
---
apiVersion: packaging.carvel.dev/v1alpha1
kind: PackageRepository
metadata:
  name: carvel.garnier.wf
  namespace: app-ns
spec:
  fetch:
    imgpkgBundle:
      image: registry.bosh:5000/repo@sha256:5fb39deab2298aac206549cd95d023c4095ccdbefcfc376c5486b6df48d2f000
```


<!-- end_slide -->

4 - Deploy demo app using PackageInstall CRD
===
```yaml
---
apiVersion: packaging.carvel.dev/v1alpha1
kind: PackageInstall
metadata:
  name: cfday-pkgi
  namespace: app-ns
spec:
  packageRef:
    refName: carvel.garnier.wf
    versionSelection:
      constraints: 1.0.0
  serviceAccountName: cfday-pkgi-install-sa
  values:
  - secretRef:
      name: cfday-pkgi-values

---
apiVersion: v1
kind: Secret
metadata:
  name: cfday-pkgi-values
  namespace: app-ns
stringData:
  values.yaml: |
    channel: app-crd
    domains:
    - app-echo
    namespace: app-ns
```

<!-- end_slide -->

Future improvements
===

- Simplify image -> bosh release flow by creating wrapper cli
  - imgpkg + distribition (registry) + bosh add-blob
<!-- new_lines: 0 -->  
- Simplify installing kapp-controller with trusted registy ca
  - wrap kapp-controller in bosh job so ca can be rendered using erb
  - additionally add support for airgapped installs by pre-loading the images
<!-- new_lines: 0 -->    
- Support zero downtime updates
  - Copy all blobs and metadata into persistent disk in pre-start
  - Add cron job to delete images which do not exist in registry-data package and are not not being referenced by currently deployed workloads

<!-- end_slide -->

Thank you!
===

<!-- column_layout: [1, 1] -->

<!-- column: 0 -->

**https://github.com/rkoster/carvel-on-bosh-demo**

```
█████████████████████████████████
██ ▄▄▄▄▄ █ ▄▄ ██ █▄ ██▀█ ▄▄▄▄▄ ██
██ █   █ ██▄█▀▀ ▀▀█ ▀▀██ █   █ ██
██ █▄▄▄█ █ ▀▀▄  ▄█▀▄▀█▀█ █▄▄▄█ ██
██▄▄▄▄▄▄▄█ ▀▄█▄█▄▀ █▄▀▄█▄▄▄▄▄▄▄██
██▄  ██ ▄▀▄▄█▄ ▀█▀ ██▀    ▄██  ██
██ ▀▄█▀▀▄▄█▄ ▀ █▀▄▀▄▀ ▄▀▄▄  ▄█▄██
██▀█▀▀▀▀▄█   █▄█▀▀▄█▀ ▀█  ███▀ ██
███▀ ▄▀ ▄▀▄ ▀ ▄█ ▄ █▄ ▀▄  ▄███▄██
██▄▄▀▄▄▀▄▄▀▀██▄▀█▀ ▀▄▀▄▄ ▀██▀▀ ██
██▄▄▄ █ ▄▄██  ▀▄▄▄▀█▀▄▀█▀█ ▄██▄██
██▄▄▄▄█▄▄▄ ▄ ▀ ▀▄  ███ ▄▄▄  ▀▄▀██
██ ▄▄▄▄▄ █▀▄ ▄▀▄▀  █ ▀ █▄█ ██▀ ██
██ █   █ ██ █▀ ██ ▀██   ▄▄  ▀█▀██
██ █▄▄▄█ █ █▄▄▀▄█ ▄▄ █▀▄█▀ ▀█▄▄██
██▄▄▄▄▄▄▄█▄█▄▄▄██▄████▄███▄▄██▄██
█████████████████████████████████
```

<!-- column: 1 -->

## Questions?
