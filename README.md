# Toolkits

[![Container Image Build](https://github.com/longkai/toolkit/actions/workflows/image-build-and-publish.yaml/badge.svg)](https://github.com/longkai/toolkit/actions/workflows/image-build-and-publish.yaml)

A container-based toolkit for OCI image management, S3-compatible storage operations, and Envoy log analysis, powered by [Nushell](https://www.nushell.sh/).

Image: `kennylongio/toolkit:latest`

[中文文档](README_zh.md)

## Built-in Tools

The container comes pre-installed with a rich set of networking/debugging tools and K8s utilities:

| Category | Tools |
|----------|-------|
| Networking | `tcpdump`, `dig` (dnsutils), `nc` (netcat), `ping`, `tracepath`, `iftop`, `ssh`, `curl` |
| K8s / Containers | `kubectl`, `helm`, `crane`, `crictl`, `ctr` |
| Cloud | `aws` (AWS CLI v2, works with any S3-compatible storage) |
| Database | `mysql` (mariadb-client), `redis-cli` |
| System | `htop`, `vim`, `less`, `file`, `zip`, `bzip2` |

### Shell Completions

The toolkit uses [carapace](https://carapace-sh.github.io/) as a multi-shell completion engine, providing **tab-completion for all built-in tools** including `kubectl`, `helm`, `aws`, `crane`, `git`, and many more — out of the box, no extra setup needed.

Additionally, [starship](https://starship.rs/) is configured as the shell prompt for a modern, informative terminal experience.

## Deployment Scenarios

### Deployment (Most Common)

For daily operations such as image transfer, S3 file management, and log analysis.

```bash
kubectl apply -f deploy/deployment.yaml
kubectl exec -it deploy/toolkit -- nu
```

Key configurations:

- `hostNetwork: true`: Uses host network for accessing internal cluster services
- Mount `/root/.kube` (optional): Reuse host kubeconfig
- Mount `/root/.aws` (optional): Reuse S3-compatible storage credentials
- Mount `/root/.docker` (optional): Reuse Docker registry auth

> **Note:** Mounting host credential directories is optional. You can also configure credentials directly inside the container (e.g., manually create `~/.aws/credentials`), but they will not persist across pod restarts. The mount path is also flexible — it does not have to be `/root`; adjust according to your container's user home directory.

### DaemonSet

For importing images on **all nodes** (e.g., offline image distribution). Mounts containerd socket and `ctr` binary so the toolkit pod can directly operate the node's container runtime.

```bash
kubectl apply -f deploy/daemonset.yaml
```

Key configurations:

- Mount `/run/containerd/containerd.sock`: Direct access to node containerd
- Mount `/usr/local/bin/ctr`: Use node's ctr command for image import

Works with `oci import daemonset` command to concurrently import images to all nodes.

---

## Command Reference

All commands are organized as nushell modules, available immediately after entering the toolkit pod.

> **Tip:** Every command has built-in detailed help with descriptions and examples. Use `--help` to view them, e.g.:
>
> ```nu
> s3 presign --help
> oci push s3 --help
> envoy parse-access-log --help
> ```

### S3 Commands (`s3`)

#### `s3 presign` — Generate S3 Pre-signed URL

Generate a time-limited pre-signed URL, supporting GET (download) and PUT (upload).

```nu
# Generate a download link (default 1 hour)
s3 presign "s3://my-bucket/path/to/file.txt"

# Pipeline input
"s3://my-bucket/path/to/file.txt" | s3 presign

# Generate an upload link, valid for 2 hours
s3 presign "s3://my-bucket/path/to/file.txt" --method PUT --expires-in 2hr

# Use the `bucket` field from ~/.aws/credentials [default] profile
"s3:///path/to/file.txt" | s3 presign
```

Parameters:

| Parameter | Description |
|-----------|-------------|
| `--access-key` | AWS access key, defaults to `~/.aws/credentials` |
| `--secret-key` | AWS secret key, defaults to `~/.aws/credentials` |
| `--expires-in` | Expiry duration, default `1hr` |
| `--method` | HTTP method, `GET` or `PUT`, default `GET` |
| `--endpoint-url` | Custom endpoint (e.g., Tencent COS) |
| `--region` | Region, default `us-east-1` |

#### `s3 cp` — Copy File to S3 and Return Pre-signed URL

Upload a local file or remote URL to S3, then return a pre-signed download link.

```nu
# Upload a local file
'/path/to/file' | s3 cp "s3://my-bucket/path/to/file"

# Upload to a directory (note trailing `/`)
'/path/to/file' | s3 cp "s3:///path/to/dir/"

# Download from remote URL then upload to S3
'https://example.com/file.tar.gz' | s3 cp "s3://my-bucket/path/to/file.tar.gz"
```

---

### OCI Commands (`oci`)

#### `oci push registry` — Push Images to Remote Registry

Supports multiple input sources: another registry image, downloadable tarball URL, local image, or local tarball file. Also supports Helm Charts.

```nu
# Push a single image to a registry
"nginx:latest" | oci push registry "my-registry.com" -n my-namespace

# Batch push
["nginx:latest", "redis:7"] | oci push registry "my-registry.com" -n library

# Override tag
"nginx" | oci push registry "my-registry.com" -n library -t v1.0

# Push to insecure registry
"nginx" | oci push registry "my-registry.com" --insecure

# Specify platform
"nginx" | oci push registry "my-registry.com" --platform linux/amd64
```

Parameters:

| Parameter | Description |
|-----------|-------------|
| `registry` | Target registry address |
| `-n, --namespace` | Target namespace |
| `--name` | Override image name |
| `-t, --tag` | Override image tag |
| `--insecure` | Allow insecure registry |
| `--platform` | Specify platform, e.g., `linux/amd64` |

#### `oci push s3` — Push Images to S3

Download OCI images as tarballs and sync to S3, returning pre-signed download URLs. Ideal for offline image distribution.

```nu
# Push a single image
"nginx" | oci push s3

# Batch push
["nginx:latest", "redis:7", "registry.k8s.io/kube-apiserver:v1.34.1"] | oci push s3

# Custom parameters
"nginx" | oci push s3 --bucket my-bucket --endpoint-url "https://cos.ap-guangzhou.myqcloud.com" --expires-in 12hr
```

Returns: `record<url: string, image: string>`

#### `oci import` — Import Images to Local Node

Import images from URLs or local tarballs into the current node's container runtime (auto-detects docker or ctr).

```nu
# Import from URL
"https://cos.ap-guangzhou.myqcloud.com/..." | oci import

# Batch import
["https://url1", "https://url2"] | oci import
```

#### `oci import daemonset` — Batch Import Images to All K8s Nodes ⭐

**Requires DaemonSet deployment.** Concurrently executes image import on all toolkit daemonset pods via kubectl exec.

```nu
# Import to all nodes (default label selector)
"https://cos.ap-guangzhou.myqcloud.com/..." | oci import daemonset

# Specify namespace and label
"https://..." | oci import daemonset -n kube-system -l name=toolkit

# Batch import
["https://url1", "https://url2"] | oci import daemonset -n default -l name=toolkit
```

Parameters:

| Parameter | Description |
|-----------|-------------|
| `-l, --selector` | Pod label selector, default `name=toolkit` |
| `-n, --namespace` | Pod namespace |

---

### Envoy Commands (`envoy`)

#### `envoy parse-access-log` — Parse Envoy Access Logs

Parse Envoy text-based access logs into structured tables for filtering and analysis.

```nu
# Parse a log file
open /var/log/envoy/access.log | envoy parse-access-log

# Parse logs from kubectl
kubectl logs deploy/my-gateway -c istio-proxy | envoy parse-access-log

# Filter 5xx errors
kubectl logs deploy/my-gateway -c istio-proxy | envoy parse-access-log | where response-code >= 500

# Sort by response time
kubectl logs deploy/my-svc -c istio-proxy | envoy parse-access-log | sort-by duration --reverse

# Tencent Cloud API gateway logs (with action field)
open access.log | envoy parse-access-log --tencent-cloud-action

# Convert to datetime for time range filtering
open access.log | envoy parse-access-log --into-datetime | where start-time > (date now) - 1hr

# Strip null fields for cleaner output
open access.log | envoy parse-access-log --strip-missing-value

# Custom pattern
open access.log | envoy parse-access-log '[{timestamp}] {method} {path}'
```

Parameters:

| Parameter | Description |
|-----------|-------------|
| `pattern` | Custom parse pattern, defaults to Envoy standard format |
| `-r, --regex` | Use regex syntax for patterns |
| `--tencent-cloud-action` | Append Tencent Cloud API action field |
| `--strip-missing-value` | Strip null value fields |
| `--into-datetime` | Convert start-time to datetime type |

Default parsed fields:

| Field | Type | Description |
|-------|------|-------------|
| `start-time` | string/datetime | Request start time |
| `method` | string | HTTP method |
| `path` | string | Request path |
| `protocol` | string | HTTP protocol version |
| `response-code` | int | Response status code |
| `response-flags` | string | Envoy response flags |
| `bytes-received` | filesize | Bytes received |
| `bytes-sent` | filesize | Bytes sent |
| `duration` | duration | Total request duration |
| `x-envoy-upstream-service-time` | duration | Upstream service time |
| `x-forwarded-for` | string | Client IP |
| `user-agent` | string | User-Agent |
| `x-request-id` | string | Request ID |
| `authority` | string | Host/Authority |
| `upstream-host` | string | Upstream address |

---

## Typical Workflows

### Offline Image Distribution (Deployment + DaemonSet)

```nu
# 1. In Deployment toolkit, push images to S3
let images = ["nginx:1.25", "redis:7.2"] | oci push s3
# Returns: [{url: "https://...", image: "nginx:1.25"}, ...]

# 2. In DaemonSet toolkit, batch import to all nodes
$images | get url | oci import daemonset -n default -l name=toolkit
```

### Cross-Registry Image Transfer

```nu
# Transfer from public registry to internal registry
["nginx:latest", "redis:7"] | oci push registry "internal-registry.example.com" -n library
```

### S3 File Sharing

```nu
# Upload file and generate a 2-hour download link
'/tmp/debug-info.tar.gz' | s3 cp "s3:///debug/info.tar.gz"

# Generate pre-signed link only (file already in S3)
s3 presign "s3://my-bucket/path/to/file" --expires-in 4hr
```

---

## Credential Configuration

S3 commands work with **any S3-compatible storage** (AWS S3, Tencent COS, Alibaba OSS, MinIO, Ceph RGW, etc.). The examples below use Tencent COS as a reference, but you can replace the endpoint with any S3-compatible service.

Credentials can be provided in two ways:

1. **Mount from host** (recommended for persistence): Mount the host's credential directory into the container
2. **Configure inside container** (ephemeral): Manually create credential files inside the pod — simple but lost on pod restart

### S3 Credentials (`~/.aws/credentials`)

```ini
[default]
aws_access_key_id = YOUR_ACCESS_KEY
aws_secret_access_key = YOUR_SECRET_KEY
# Any S3-compatible endpoint, e.g.:
# Tencent COS: https://cos.ap-guangzhou.myqcloud.com
# Alibaba OSS: https://oss-cn-hangzhou.aliyuncs.com
# MinIO: http://minio.local:9000
endpoint_url = https://your-s3-compatible-endpoint.com
bucket = your-default-bucket
```

Optional `~/.aws/config`:

```ini
[default]
region = ap-guangzhou
```

### OCI Registry Credentials

OCI registry auth relies on `~/.docker/config.json` (standard docker auth format).

### Inline Credentials

Alternatively, you can pass credentials directly via command flags without any config file:

```nu
s3 presign "s3://bucket/file" --access-key YOUR_AK --secret-key YOUR_SK --endpoint-url "https://your-endpoint.com"
```
