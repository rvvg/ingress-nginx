# ingress-nginx with NGINX 1.31.8

This repository is a maintained build of [kubernetes/ingress-nginx](https://github.com/kubernetes/ingress-nginx)
`controller-v1.15.1` / chart `4.15.1`. The upstream project is retired and archived (see [below](#retiring)).
This repository is not affiliated with the Kubernetes project.

The controller code is unchanged from upstream except for a template change and an Ingress status fix (see [Behavior changes](#behavior-changes)).
The NGINX base image is updated to NGINX 1.31.8 (mainline) with the patch set and Lua modules from
[OpenResty v1.31.8.1](https://github.com/openresty/openresty/tree/v1.31.8.1). As in upstream, the build tracks the
NGINX mainline version that OpenResty is based on: upstream used 1.21.6, 1.25.x and 1.27.1, all of which were mainline.

## Versions

Kubernetes 1.36 (v1.36.4) and 1.37 (v1.37.0) are added to the CI matrix on top of the upstream 1.31–1.35: the full
kind e2e suite (regular and chroot) and the chart tests pass on every version in the range.

| Component                 | Upstream v1.15.1 | This build            |
| ------------------------- | ---------------- | --------------------- |
| Controller image tag      | v1.15.1          | v1.15.1-nginx-1.31.8  |
| Helm chart version        | 4.15.1           | 4.15.1-nginx-1.31.8   |
| NGINX base image tag      | v2.2.8           | v2.3.0                |
| NGINX                     | 1.27.1           | 1.31.8                |
| OpenResty patch set       | 1.27.1.2         | 1.31.8.1              |
| lua-nginx-module          | v0.10.28         | v0.10.32rc7           |
| stream-lua-nginx-module   | v0.0.16          | v0.0.20rc3            |
| lua-resty-core            | v0.1.31          | v0.1.35rc2            |
| LuaJIT (openresty/luajit2)| v2.1-20250117    | v2.1-20261023         |
| lua-upstream-nginx-module | v0.07            | v0.08                 |
| ngx_devel_kit             | v0.3.3 (vision5) | v0.3.6 (openresty)    |
| set-misc-nginx-module     | v0.33            | v0.34                 |
| headers-more-nginx-module | v0.37            | v0.40                 |
| lua-cjson                 | 2.1.0.14         | 2.1.0.20              |
| lua-resty-dns / string / memcached / redis | v0.23 / v0.16 / v0.17 / v0.31 | v0.24 / v0.19 / v0.18 / v0.34 |
| njs                       | 0.9.0            | 1.0.2                 |
| Alpine / OpenSSL          | 3.23.3 / 3.5.x   | 3.23.3 / 3.5.9        |
| Kubernetes (e2e-tested)   | 1.31–1.35        | 1.31–1.37             |

Module versions are taken from OpenResty v1.31.8.1 (`util/mirror-tarballs`). OpenResty publishes the Lua modules for this
release line only as `rc` tags. All other modules (ModSecurity, OWASP CRS, geoip2, brotli, OpenTelemetry, mimalloc, ...)
are unchanged from upstream. The full list is in [`images/nginx/rootfs/build.sh`](images/nginx/rootfs/build.sh).

## NGINX patches

[`images/nginx/rootfs/patches/`](images/nginx/rootfs/patches) contains:

- `00_drop-alias-root.patch`: the upstream ingress-nginx patch that removes the `root` and `alias` directives, regenerated for 1.31.8.
- `01`–`37`: OpenResty `patches/nginx/1.31.8`, applied in the same order as OpenResty applies them.

The following OpenResty patches are not applied:

| Patch                                                           | Reason                                                       |
| --------------------------------------------------------------- | ------------------------------------------------------------ |
| `server_header`, `builtin_error_page_footer`                    | OpenResty branding; also not applied by upstream ingress-nginx |
| `no_pool`                                                       | Debug-only build option                                      |
| `CVE-2026-9256`, `hash_overflow`, `setting_args_invalidates_uri` | OpenResty applies them only to older NGINX versions; not needed for 1.31.8 |
| `initialize_quic_transport_id_variable`, `resolver_hosts`       | Present in the patch directory but not applied by OpenResty v1.31.8.1 |

The following upstream ingress-nginx patches were dropped because NGINX now includes the fix or feature:
`CVE-2025-23419` (fixed in NGINX) and `stream_proxy_protocol_v2` (PROXY protocol v2 in the stream module is native since NGINX 1.31.4).

## Behavior changes

Template ([`rootfs/etc/nginx/template/nginx.tmpl`](rootfs/etc/nginx/template/nginx.tmpl)):

- `upstream upstream_balancer` emits `keepalive 0;` when `upstream-keepalive-connections` is `0`. Since NGINX 1.29.7, upstream
  keepalive is enabled by default (`keepalive 32 local`). Without this line, setting the option to `0` would no longer disable it.

Ingress status ([`internal/ingress/status/status.go`](internal/ingress/status/status.go)):

- Without `--publish-service` / `--publish-status-address`, the leader publishes the node addresses of all ready controller
  pods. It selected these pods by all of its own labels. Since Kubernetes 1.35, the `PodTopologyLabels` admission plugin
  copies `topology.kubernetes.io/zone` and `topology.kubernetes.io/region` from the node to every pod, so only pods in the
  leader's zone matched and the status showed a subset of the addresses (typically only the leader's node with
  `hostNetwork`). The selector now ignores `topology.kubernetes.io/*`. Revision labels are still matched as upstream, so
  during a rollout only pods of the leader's revision are published.

NGINX 1.27.1 → 1.31.8 changes that can affect traffic (full list: [CHANGES](https://nginx.org/en/CHANGES)):

- 1.27.3: TLSv1 and TLSv1.1 are disabled by default. ingress-nginx sets `ssl_protocols` explicitly.
- 1.29.4: Host/port validation in the request line, `Host` and `:authority` follows RFC 3986. A bare LF in chunked bodies is an error.
- 1.29.7: Upstream keepalive is on by default. The proxy module defaults to `proxy_http_version 1.1` and no longer sends `Connection`.
  ingress-nginx sets both explicitly per location.
- 1.31.0: HTTP/2 and HTTP/3 requests with `Connection`, `Proxy-Connection`, `Keep-Alive`, `Transfer-Encoding`, `Upgrade`, or a `TE`
  header other than `trailers` are rejected.
- 1.31.2: `$request_id` is generated with SipHash-2-4.
- 1.31.3: HTTP/2 response headers from gRPC/HTTP/2 backends are limited by `grpc_buffer_size` / `proxy_buffer_size`.
- 1.31.4: HTTP/2 and gRPC requests to backends always carry `:authority`, and HTTP/1.1 requests always carry `Host`.
- 1.31.7: HTTP/2 uses RFC 9218 prioritization. RFC 7540 priority signals are ignored.

## Artifacts

Published by [`.github/workflows/release-ghcr.yaml`](.github/workflows/release-ghcr.yaml) for `linux/amd64` and `linux/arm64`:

| Artifact          | Reference                                                    |
| ----------------- | ------------------------------------------------------------ |
| NGINX base image  | `ghcr.io/rvvg/ingress-nginx/nginx:v2.3.0`                    |
| Controller        | `ghcr.io/rvvg/ingress-nginx/controller:v1.15.1-nginx-1.31.8` |
| Controller chroot | `ghcr.io/rvvg/ingress-nginx/controller-chroot:v1.15.1-nginx-1.31.8` |
| Helm chart (OCI)  | `oci://ghcr.io/rvvg/charts/ingress-nginx`, version `4.15.1-nginx-1.31.8` |

The published chart pins `controller.image.{registry,tag,digest,digestChroot}` to the images above. The other images
(`kube-webhook-certgen`, `defaultbackend`) still default to `registry.k8s.io`. `values.yaml` in this repository keeps
the upstream defaults, so the chart unit tests still pass.

## Installation

The chart is an OCI artifact in GHCR: there is no `helm repo add` step, the chart is referenced as
`oci://ghcr.io/rvvg/charts/ingress-nginx` directly. Requires Helm 3.8+. The packages are public, so no
`helm registry login` or `imagePullSecrets` are needed. Always pass `--version`: OCI charts have no index, and the
version is required to pick a release.

Inspect the chart:

```console
helm show chart  oci://ghcr.io/rvvg/charts/ingress-nginx --version 4.15.1-nginx-1.31.8
helm show values oci://ghcr.io/rvvg/charts/ingress-nginx --version 4.15.1-nginx-1.31.8 > values.yaml
```

Install or upgrade, optionally with your own values (the controller image is already set by the chart):

```console
helm upgrade --install ingress-nginx oci://ghcr.io/rvvg/charts/ingress-nginx \
  --version 4.15.1-nginx-1.31.8 \
  --namespace ingress-nginx --create-namespace \
  -f values.yaml
```

Check the deployed image:

```console
kubectl -n ingress-nginx get deploy ingress-nginx-controller \
  -o jsonpath='{.spec.template.spec.containers[0].image}'
```

Download the chart package, e.g. for an air-gapped install or to vendor it:

```console
helm pull oci://ghcr.io/rvvg/charts/ingress-nginx --version 4.15.1-nginx-1.31.8   # ingress-nginx-4.15.1-nginx-1.31.8.tgz
```

As a dependency of an umbrella chart (`Chart.yaml`), followed by `helm dependency update`:

```yaml
dependencies:
  - name: ingress-nginx
    version: 4.15.1-nginx-1.31.8
    repository: oci://ghcr.io/rvvg/charts
```

Argo CD `Application` (Argo CD takes the OCI registry without the `oci://` scheme and needs `enableOCI: true` in
the repository secret when the repository is declared explicitly):

```yaml
spec:
  source:
    repoURL: ghcr.io/rvvg/charts
    chart: ingress-nginx
    targetRevision: 4.15.1-nginx-1.31.8
    helm:
      valuesObject: {}
```

Flux `HelmRepository` + `HelmRelease`:

```yaml
apiVersion: source.toolkit.fluxcd.io/v1
kind: HelmRepository
metadata:
  name: ingress-nginx-ghcr
  namespace: flux-system
spec:
  type: oci
  url: oci://ghcr.io/rvvg/charts
  interval: 1h
---
apiVersion: helm.toolkit.fluxcd.io/v2
kind: HelmRelease
metadata:
  name: ingress-nginx
  namespace: ingress-nginx
spec:
  interval: 1h
  chart:
    spec:
      chart: ingress-nginx
      version: 4.15.1-nginx-1.31.8
      sourceRef:
        kind: HelmRepository
        name: ingress-nginx-ghcr
        namespace: flux-system
```

Switching an existing release installed from `https://kubernetes.github.io/ingress-nginx` keeps the release name and
values; Helm only needs the new chart reference:

```console
helm upgrade ingress-nginx oci://ghcr.io/rvvg/charts/ingress-nginx \
  --version 4.15.1-nginx-1.31.8 --namespace ingress-nginx --reuse-values
```

With `--reuse-values`, image overrides from the previous release win over the chart defaults: remove any
`controller.image.*` overrides first, or the old image keeps running. Uninstall with
`helm uninstall ingress-nginx -n ingress-nginx`.

### Using the upstream chart

To keep the upstream chart `4.15.1`, override only the controller image. The digests point to the multi-arch image
indexes, so every node pulls its own architecture:

```yaml
controller:
  image:
    registry: ghcr.io/rvvg
    image: ingress-nginx/controller
    tag: v1.15.1-nginx-1.31.8
    digest: sha256:ec8b8499592f6d04dc8a50136e98c60a2fdd0245ac536cc6b579af4f21c1772d
    digestChroot: sha256:c74cc97ea0b03970cefec0e76418020685f68656d34cb91c25218482fce391b6
```

```console
helm upgrade ingress-nginx ingress-nginx/ingress-nginx --version 4.15.1 \
  --namespace ingress-nginx --reuse-values -f ghcr-image.yaml
```

- Set `digest` and `digestChroot` together with `tag`; otherwise the chart appends the upstream digest to the new tag
  and the old image is deployed. Use empty strings to deploy by tag only.
- `controller.image.repository`, if set, overrides `registry` and `image`.
- No `imagePullSecrets` are needed: the packages are public.

### Verifying images

Images and the chart are signed with keyless [cosign](https://github.com/sigstore/cosign) from the release workflow,
and every platform image has an SPDX SBOM attestation:

```console
cosign verify ghcr.io/rvvg/ingress-nginx/controller:v1.15.1-nginx-1.31.8 \
  --certificate-identity-regexp '^https://github.com/rvvg/ingress-nginx/' \
  --certificate-oidc-issuer https://token.actions.githubusercontent.com

cosign verify-attestation --type spdxjson \
  ghcr.io/rvvg/ingress-nginx/controller@sha256:1a0bda67c2bcf9eb4d067823b6453a1d076c1ff21b60a857ad1e53159c41769b \
  --certificate-identity-regexp '^https://github.com/rvvg/ingress-nginx/' \
  --certificate-oidc-issuer https://token.actions.githubusercontent.com
```

The second digest is the `linux/amd64` image; `docker buildx imagetools inspect` lists the digests per platform.

## Build

Locally (Docker, single architecture):

```console
# NGINX base image
docker build --platform linux/amd64 -t <registry>/nginx:v2.3.0 images/nginx/rootfs

# Controller on top of it
make build image image-chroot ARCH=amd64 TAG=<tag> REGISTRY=<registry> BASE_IMAGE=<registry>/nginx:v2.3.0
```

CI:

- Pull requests that touch `images/nginx/**` or `NGINX_BASE` run [`ci.yaml`](.github/workflows/ci.yaml). It builds the base
  image and the controller in the job and runs the kind e2e suite against Kubernetes 1.31–1.37, including chroot and chart tests.
- Release: run the `Release (GHCR)` workflow manually from `main` (`gh workflow run release-ghcr.yaml`). It builds on native
  amd64 and arm64 runners and reuses an existing base image tag unless `rebuild-base` is set. It refuses to overwrite an existing
  controller tag unless `force` is set. Use the `revision` input to publish `-rN` builds without an NGINX version change.
  `chart-only` republishes just the chart (same version) and the release notes for already published images.

Versions are derived from the repository: `images/nginx/TAG` for the base image, and `Chart.yaml` `appVersion` / `version`
plus `-nginx-<NGINX_VERSION from build.sh>` for the controller and the chart.

### Updating NGINX

1. Pick the NGINX version of the latest OpenResty release and copy its `patches/nginx/<version>` set. Use the patch order and
   version conditions from `util/mirror-tarballs`.
2. Update `NGINX_VERSION`, the Lua module versions (from the same `mirror-tarballs`) and the checksums in `build.sh`.
   Regenerate `00_drop-alias-root.patch` if it no longer applies.
3. Bump `images/nginx/TAG` and review the NGINX `CHANGES` for default changes that affect `nginx.tmpl`.
4. Open a PR. CI builds the base image and runs e2e. After merging, run `Release (GHCR)`.

---

# Ingress NGINX Retirement

## Retiring

[What You Need to Know about Ingress NGINX Retirement](https://www.kubernetes.io/blog/2025/11/11/ingress-nginx-retirement/):

* Best-effort maintenance will continue until March 2026.
* Afterward, there will be no further releases, no bugfixes, and no updates to resolve any security vulnerabilities that may be discovered.
* Existing deployments of Ingress NGINX will not be broken.
  * Existing project artifacts such as Helm charts and container images will remain available.

# Ingress NGINX Controller

[![CII Best Practices](https://bestpractices.coreinfrastructure.org/projects/5691/badge)](https://bestpractices.coreinfrastructure.org/projects/5691)
[![Go Report Card](https://goreportcard.com/badge/github.com/kubernetes/ingress-nginx)](https://goreportcard.com/report/github.com/kubernetes/ingress-nginx)
[![GitHub license](https://img.shields.io/github/license/kubernetes/ingress-nginx.svg)](https://github.com/kubernetes/ingress-nginx/blob/main/LICENSE)
[![GitHub stars](https://img.shields.io/github/stars/kubernetes/ingress-nginx.svg)](https://github.com/kubernetes/ingress-nginx/stargazers)

## Overview

ingress-nginx was an Ingress controller for Kubernetes using [NGINX](https://www.nginx.org/) as a reverse proxy and load
balancer.

[Learn more about Ingress on the Kubernetes documentation site](https://kubernetes.io/docs/concepts/services-networking/ingress/).

## Usage warnings

If you are not already using ingress-nginx, you should not be deploying it as it is [not being developed](#retiring). Instead you should identify a [Gateway API](https://gateway-api.sigs.k8s.io/guides/) implementation and use it.

Do not use in multi-tenant Kubernetes production installations. This project assumes that users that can create Ingress objects are administrators of the cluster. See the [FAQ](https://kubernetes.github.io/ingress-nginx/faq/#faq) for more.

## Troubleshooting

If you encounter issues, review the [troubleshooting docs](docs/troubleshooting.md),
[search for an issue](https://github.com/kubernetes/ingress-nginx/issues), or talk to us on the
[#ingress-nginx-users channel](https://kubernetes.slack.com/messages/ingress-nginx-users) on the Kubernetes Slack server.

## Changelog

See [the list of releases](https://github.com/kubernetes/ingress-nginx/releases) for all changes.
For detailed changes for each release, please check the [changelog-$version.md](./changelog) file for the release version.
For detailed changes on the `ingress-nginx` helm chart, please check the changelog folder for a specific version.
[CHANGELOG-$current-version.md](./charts/ingress-nginx/changelog) file.

### Supported Versions table

Supported versions for the ingress-nginx project mean that we have completed E2E tests, and they are passing for
the versions listed. Ingress-Nginx versions **may** work on older versions, but the project does not make that guarantee.

| Supported | Ingress-NGINX version | k8s supported version         | Alpine Version | Nginx Version | Helm Chart Version |
| :-------: | --------------------- | ----------------------------- | -------------- | ------------- | ------------------ |
|    🔄     | **v1.15.1**           | 1.35, 1.34, 1.33, 1.32, 1.31  | 3.23.3         | 1.27.1        | 4.15.1             |
|    🔄     | **v1.15.0**           | 1.35, 1.34, 1.33, 1.32, 1.31  | 3.23.3         | 1.27.1        | 4.15.0             |
|    🔄     | **v1.14.5**           | 1.34, 1.33, 1.32, 1.31, 1.30  | 3.23.3         | 1.27.1        | 4.14.5             |
|    🔄     | **v1.14.4**           | 1.34, 1.33, 1.32, 1.31, 1.30  | 3.23.3         | 1.27.1        | 4.14.4             |
|    🔄     | **v1.14.3**           | 1.34, 1.33, 1.32, 1.31, 1.30  | 3.23.2         | 1.27.1        | 4.14.3             |
|    🔄     | **v1.14.2**           | 1.34, 1.33, 1.32, 1.31, 1.30  | 3.23.2         | 1.27.1        | 4.14.2             |
|    🔄     | **v1.14.1**           | 1.34, 1.33, 1.32, 1.31, 1.30  | 3.22.2         | 1.27.1        | 4.14.1             |
|    🔄     | **v1.14.0**           | 1.34, 1.33, 1.32, 1.31, 1.30  | 3.22.2         | 1.27.1        | 4.14.0             |
|    🔄     | **v1.13.9**           | 1.33, 1.32, 1.31, 1.30, 1.29  | 3.23.3         | 1.27.1        | 4.13.9             |
|    🔄     | **v1.13.8**           | 1.33, 1.32, 1.31, 1.30, 1.29  | 3.23.3         | 1.27.1        | 4.13.8             |
|    🔄     | **v1.13.7**           | 1.33, 1.32, 1.31, 1.30, 1.29  | 3.23.2         | 1.27.1        | 4.13.7             |
|    🔄     | **v1.13.6**           | 1.33, 1.32, 1.31, 1.30, 1.29  | 3.23.2         | 1.27.1        | 4.13.6             |
|    🔄     | **v1.13.5**           | 1.33, 1.32, 1.31, 1.30, 1.29  | 3.22.2         | 1.27.1        | 4.13.5             |
|    🔄     | **v1.13.4**           | 1.33, 1.32, 1.31, 1.30, 1.29  | 3.22.2         | 1.27.1        | 4.13.4             |
|    🔄     | **v1.13.3**           | 1.33, 1.32, 1.31, 1.30, 1.29  | 3.22.1         | 1.27.1        | 4.13.3             |
|    🔄     | **v1.13.2**           | 1.33, 1.32, 1.31, 1.30, 1.29  | 3.22.1         | 1.27.1        | 4.13.2             |
|    🔄     | **v1.13.1**           | 1.33, 1.32, 1.31, 1.30, 1.29  | 3.22.1         | 1.27.1        | 4.13.1             |
|    🔄     | **v1.13.0**           | 1.33, 1.32, 1.31, 1.30, 1.29  | 3.22.0         | 1.27.1        | 4.13.0             |
|           | v1.12.8               | 1.32, 1.31, 1.30, 1.29, 1.28  | 3.22.2         | 1.25.5        | 4.12.8             |
|           | v1.12.7               | 1.32, 1.31, 1.30, 1.29, 1.28  | 3.22.1         | 1.25.5        | 4.12.7             |
|           | v1.12.6               | 1.32, 1.31, 1.30, 1.29, 1.28  | 3.22.1         | 1.25.5        | 4.12.6             |
|           | v1.12.5               | 1.32, 1.31, 1.30, 1.29, 1.28  | 3.22.1         | 1.25.5        | 4.12.5             |
|           | v1.12.4               | 1.32, 1.31, 1.30, 1.29, 1.28  | 3.22.0         | 1.25.5        | 4.12.4             |
|           | v1.12.3               | 1.32, 1.31, 1.30, 1.29, 1.28  | 3.21.3         | 1.25.5        | 4.12.3             |
|           | v1.12.2               | 1.32, 1.31, 1.30, 1.29, 1.28  | 3.21.3         | 1.25.5        | 4.12.2             |
|           | v1.12.1               | 1.32, 1.31, 1.30, 1.29, 1.28  | 3.21.3         | 1.25.5        | 4.12.1             |
|           | v1.12.0               | 1.32, 1.31, 1.30, 1.29, 1.28  | 3.21.0         | 1.25.5        | 4.12.0             |
|           | v1.12.0-beta.0        | 1.32, 1.31, 1.30, 1.29, 1.28  | 3.20.3         | 1.25.5        | 4.12.0-beta.0      |
|           | v1.11.8               | 1.30, 1.29, 1.28, 1.27, 1.26  | 3.22.0         | 1.25.5        | 4.11.8             |
|           | v1.11.7               | 1.30, 1.29, 1.28, 1.27, 1.26  | 3.21.3         | 1.25.5        | 4.11.7             |
|           | v1.11.6               | 1.30, 1.29, 1.28, 1.27, 1.26  | 3.21.3         | 1.25.5        | 4.11.6             |
|           | v1.11.5               | 1.30, 1.29, 1.28, 1.27, 1.26  | 3.21.3         | 1.25.5        | 4.11.5             |
|           | v1.11.4               | 1.30, 1.29, 1.28, 1.27, 1.26  | 3.21.0         | 1.25.5        | 4.11.4             |
|           | v1.11.3               | 1.30, 1.29, 1.28, 1.27, 1.26  | 3.20.3         | 1.25.5        | 4.11.3             |
|           | v1.11.2               | 1.30, 1.29, 1.28, 1.27, 1.26  | 3.20.0         | 1.25.5        | 4.11.2             |
|           | v1.11.1               | 1.30, 1.29, 1.28, 1.27, 1.26  | 3.20.0         | 1.25.5        | 4.11.1             |
|           | v1.11.0               | 1.30, 1.29, 1.28, 1.27, 1.26  | 3.20.0         | 1.25.5        | 4.11.0             |
|           | v1.10.6               | 1.30, 1.29, 1.28, 1.27, 1.26  | 3.21.0         | 1.25.5        | 4.10.6             |
|           | v1.10.5               | 1.30, 1.29, 1.28, 1.27, 1.26  | 3.20.3         | 1.25.5        | 4.10.5             |
|           | v1.10.4               | 1.30, 1.29, 1.28, 1.27, 1.26  | 3.20.0         | 1.25.5        | 4.10.4             |
|           | v1.10.3               | 1.30, 1.29, 1.28, 1.27, 1.26  | 3.20.0         | 1.25.5        | 4.10.3             |
|           | v1.10.2               | 1.30, 1.29, 1.28, 1.27, 1.26  | 3.20.0         | 1.25.5        | 4.10.2             |
|           | v1.10.1               | 1.30, 1.29, 1.28, 1.27, 1.26  | 3.19.1         | 1.25.3        | 4.10.1             |
|           | v1.10.0               | 1.29, 1.28, 1.27, 1.26        | 3.19.1         | 1.25.3        | 4.10.0             |
|           | v1.9.6                | 1.29, 1.28, 1.27, 1.26, 1.25  | 3.19.0         | 1.21.6        | 4.9.1              |
|           | v1.9.5                | 1.28, 1.27, 1.26, 1.25        | 3.18.4         | 1.21.6        | 4.9.0              |
|           | v1.9.4                | 1.28, 1.27, 1.26, 1.25        | 3.18.4         | 1.21.6        | 4.8.3              |
|           | v1.9.3                | 1.28, 1.27, 1.26, 1.25        | 3.18.4         | 1.21.6        | 4.8.*              |
|           | v1.9.1                | 1.28, 1.27, 1.26, 1.25        | 3.18.4         | 1.21.6        | 4.8.*              |
|           | v1.9.0                | 1.28, 1.27, 1.26, 1.25        | 3.18.2         | 1.21.6        | 4.8.*              |
|           | v1.8.4                | 1.27, 1.26, 1.25, 1.24        | 3.18.2         | 1.21.6        | 4.7.*              |
|           | v1.7.1                | 1.27, 1.26, 1.25, 1.24        | 3.17.2         | 1.21.6        | 4.6.*              |
|           | v1.6.4                | 1.26, 1.25, 1.24, 1.23        | 3.17.0         | 1.21.6        | 4.5.*              |
|           | v1.5.1                | 1.25, 1.24, 1.23              | 3.16.2         | 1.21.6        | 4.4.*              |
|           | v1.4.0                | 1.25, 1.24, 1.23, 1.22        | 3.16.2         | 1.19.10†      | 4.3.0              |
|           | v1.3.1                | 1.24, 1.23, 1.22, 1.21, 1.20  | 3.16.2         | 1.19.10†      | 4.2.5              |

See [Updating NGINX-Ingress to use the stable Ingress API (July 26, 2021)](https://kubernetes.io/blog/2021/07/26/update-with-ingress-nginx/)
to upgrade to the stable Ingress API before upgrading to Kubernetes 1.22.

## Get Involved

Thanks for taking the time to join our community and start contributing!

- This project adheres to the [Kubernetes Community Code of Conduct](https://git.k8s.io/community/code-of-conduct.md).
  By participating in this project, you agree to abide by its terms.
- **Contributing**: Documentation contributions are welcome.

  - Read [`CONTRIBUTING.md`](CONTRIBUTING.md) for information about the workflow that we
    expect and instructions on the developer certificate of origin that we require.
  - Join our Kubernetes Slack channel for developer discussion : [#ingress-nginx-dev](https://kubernetes.slack.com/archives/C021E147ZA4).
  - Submit GitHub issues for documentation problems.
    - Please make sure to read the [Issue Reporting Checklist](https://github.com/kubernetes/ingress-nginx/blob/main/CONTRIBUTING.md#issue-reporting-guidelines) before opening an issue. Issues not conforming to the guidelines **may be closed immediately**.

- **Support**:

  - Join the [#ingress-nginx-users](https://kubernetes.slack.com/messages/CANQGM8BA/) channel inside the [Kubernetes Slack](http://slack.kubernetes.io/) to ask questions or get support from the maintainers and other users.
  - The [GitHub issues](https://github.com/kubernetes/ingress-nginx/issues) in the repository are **exclusively** for bug reports and feature requests.

## License

[Apache License 2.0](https://github.com/kubernetes/ingress-nginx/blob/main/LICENSE)
