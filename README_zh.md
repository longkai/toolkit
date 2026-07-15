# Toolkits

[![Container Image Build](https://github.com/longkai/toolkit/actions/workflows/image-build-and-publish.yaml/badge.svg)](https://github.com/longkai/toolkit/actions/workflows/image-build-and-publish.yaml)

基于容器的工具集，用于 OCI 镜像管理、S3 兼容存储操作和 Envoy 日志分析，由 [Nushell](https://www.nushell.sh/) 驱动。

镜像：`kennylongio/toolkit:latest`

[English](README.md)

> **Dotfiles：** 本仓库还托管了一份极客风 [Ghostty 终端配置](ghostty/README_zh.md)（自动深浅主题、毛玻璃、全局热键、连字），以及一套 [Homebrew 跨平台同步方案](brew/README_zh.md)（拆分式 Brewfile + Git，在 macOS 与 Linux 之间同步软件，可选每日定时器）。

## 内置工具

容器预装了丰富的网络调试工具和 K8s 工具集：

| 分类 | 工具 |
|------|------|
| 网络调试 | `tcpdump`, `dig` (dnsutils), `nc` (netcat), `ping`, `tracepath`, `iftop`, `ssh`, `curl` |
| K8s / 容器 | `kubectl`, `helm`, `crane`, `crictl`, `ctr` |
| 云服务 | `aws` (AWS CLI v2，支持任意 S3 兼容存储) |
| 数据库 | `mysql` (mariadb-client), `redis-cli` |
| 系统工具 | `htop`, `vim`, `less`, `file`, `zip`, `bzip2` |

### 命令补全

工具集使用 [carapace](https://carapace-sh.github.io/) 作为多 shell 补全引擎，**开箱即用地为所有内置工具提供 Tab 补全**，包括 `kubectl`、`helm`、`aws`、`crane`、`git` 等——无需额外配置。

此外，还配置了 [starship](https://starship.rs/) 作为 shell 提示符，提供现代化的终端体验。

## 部署方式

### Deployment（最常见）

适用于日常运维操作，如镜像搬运、S3 文件管理、日志分析等。

```bash
kubectl apply -f deploy/deployment.yaml
kubectl exec -it deploy/toolkit -- nu
```

关键配置说明：

- `hostNetwork: true`：使用宿主机网络，方便访问集群内部服务
- 挂载 `/root/.kube`（可选）：复用宿主机 kubeconfig
- 挂载 `/root/.aws`（可选）：复用 S3 兼容存储凭证
- 挂载 `/root/.docker`（可选）：复用 Docker registry 认证信息

> **说明：** 挂载宿主机凭证目录是可选的。你也可以直接在容器内配置凭证（如手动创建 `~/.aws/credentials`），但这些配置在 Pod 重启后会丢失。挂载路径也是灵活的，不一定是 `/root`，根据容器用户的 home 目录调整即可。

### DaemonSet

适用于需要在**所有节点**上导入镜像的场景（如离线环境批量分发镜像）。挂载 containerd socket 和 `ctr` 二进制，使 toolkit pod 可以直接操作节点的容器运行时。

```bash
kubectl apply -f deploy/daemonset.yaml
```

关键配置说明：

- 挂载 `/run/containerd/containerd.sock`：直接操作节点 containerd
- 挂载 `/usr/local/bin/ctr`：使用节点的 ctr 命令导入镜像

配合 `oci import daemonset` 命令使用，可以将镜像并发导入到所有节点。

---

## 命令使用文档

所有命令通过 nushell module 方式组织，进入 toolkit pod 后即可使用。

> **提示：** 每个命令都内置了详尽的说明和示例，使用 `--help` 即可查看，例如：
>
> ```nu
> s3 presign --help
> oci push s3 --help
> envoy parse-access-log --help
> ```

### S3 命令 (`s3`)

#### `s3 presign` — 生成 S3 预签名 URL

生成一个带有时效的预签名 URL，支持 GET（下载）和 PUT（上传）。

```nu
# 生成下载链接（默认 1 小时有效）
s3 presign "s3://my-bucket/path/to/file.txt"

# 通过管道输入
"s3://my-bucket/path/to/file.txt" | s3 presign

# 生成上传链接，有效期 2 小时
s3 presign "s3://my-bucket/path/to/file.txt" --method PUT --expires-in 2hr

# 使用 ~/.aws/credentials 中 [default] profile 的 bucket 字段
"s3:///path/to/file.txt" | s3 presign
```

参数说明：

| 参数 | 说明 |
|------|------|
| `--access-key` | AWS access key，默认读取 `~/.aws/credentials` |
| `--secret-key` | AWS secret key，默认读取 `~/.aws/credentials` |
| `--expires-in` | 有效期，默认 `1hr` |
| `--method` | HTTP 方法，`GET` 或 `PUT`，默认 `GET` |
| `--endpoint-url` | 自定义 endpoint（如腾讯云 COS） |
| `--region` | 区域，默认 `us-east-1` |

#### `s3 cp` — 复制文件到 S3 并返回预签名 URL

将本地文件或远程 URL 上传到 S3，然后返回一个预签名的下载链接。

```nu
# 上传本地文件
'/path/to/file' | s3 cp "s3://my-bucket/path/to/file"

# 上传到目录（注意末尾 `/`）
'/path/to/file' | s3 cp "s3:///path/to/dir/"

# 从远程 URL 下载后上传到 S3
'https://example.com/file.tar.gz' | s3 cp "s3://my-bucket/path/to/file.tar.gz"
```

---

### OCI 命令 (`oci`)

#### `oci push registry` — 推送镜像到远程 Registry

支持多种输入源：另一个 registry 的镜像、可下载的 tarball URL、本地镜像、本地 tarball 文件。同时支持 Helm Chart。

```nu
# 推送单个镜像到指定 registry
"nginx:latest" | oci push registry "my-registry.com" -n my-namespace

# 批量推送
["nginx:latest", "redis:7"] | oci push registry "my-registry.com" -n library

# 指定 tag
"nginx" | oci push registry "my-registry.com" -n library -t v1.0

# 推送到不安全的 registry
"nginx" | oci push registry "my-registry.com" --insecure

# 指定平台
"nginx" | oci push registry "my-registry.com" --platform linux/amd64
```

参数说明：

| 参数 | 说明 |
|------|------|
| `registry` | 目标 registry 地址 |
| `-n, --namespace` | 目标命名空间 |
| `--name` | 覆盖镜像名称 |
| `-t, --tag` | 覆盖镜像 tag |
| `--insecure` | 允许不安全的 registry |
| `--platform` | 指定平台，如 `linux/amd64` |

#### `oci push s3` — 推送镜像到 S3

将 OCI 镜像下载为 tarball 并同步到 S3，返回预签名下载 URL。适合离线环境的镜像分发。

```nu
# 推送单个镜像
"nginx" | oci push s3

# 批量推送
["nginx:latest", "redis:7", "registry.k8s.io/kube-apiserver:v1.34.1"] | oci push s3

# 自定义参数
"nginx" | oci push s3 --bucket my-bucket --endpoint-url "https://cos.ap-guangzhou.myqcloud.com" --expires-in 12hr
```

返回格式：`record<url: string, image: string>`

#### `oci import` — 导入镜像到本地节点

从 URL 或本地 tarball 导入镜像到当前节点的容器运行时（自动检测 docker 或 ctr）。

```nu
# 从 URL 导入
"https://cos.ap-guangzhou.myqcloud.com/..." | oci import

# 批量导入
["https://url1", "https://url2"] | oci import
```

#### `oci import daemonset` — 批量导入镜像到所有 K8s 节点 ⭐

**需要配合 DaemonSet 部署方式使用。** 通过 kubectl exec 并发在所有 toolkit daemonset pod 上执行镜像导入。

```nu
# 导入到所有节点（使用默认 label selector）
"https://cos.ap-guangzhou.myqcloud.com/..." | oci import daemonset

# 指定 namespace 和 label
"https://..." | oci import daemonset -n kube-system -l name=toolkit

# 批量导入
["https://url1", "https://url2"] | oci import daemonset -n default -l name=toolkit
```

参数说明：

| 参数 | 说明 |
|------|------|
| `-l, --selector` | Pod label selector，默认 `name=toolkit` |
| `-n, --namespace` | Pod 所在 namespace |

---

### Envoy 命令 (`envoy`)

#### `envoy parse-access-log` — 解析 Envoy 访问日志

将 Envoy 文本格式的 access log 解析为结构化表格，方便过滤和分析。

```nu
# 解析日志文件
open /var/log/envoy/access.log | envoy parse-access-log

# 从 kubectl 获取日志并解析
kubectl logs deploy/my-gateway -c istio-proxy | envoy parse-access-log

# 过滤 5xx 错误
kubectl logs deploy/my-gateway -c istio-proxy | envoy parse-access-log | where response-code >= 500

# 按响应时间排序
kubectl logs deploy/my-svc -c istio-proxy | envoy parse-access-log | sort-by duration --reverse

# 腾讯云 API 网关日志（末尾带 action 字段）
open access.log | envoy parse-access-log --tencent-cloud-action

# 转换为 datetime 类型方便时间范围过滤
open access.log | envoy parse-access-log --into-datetime | where start-time > (date now) - 1hr

# 去除空值字段使输出更简洁
open access.log | envoy parse-access-log --strip-missing-value

# 自定义 pattern
open access.log | envoy parse-access-log '[{timestamp}] {method} {path}'
```

参数说明：

| 参数 | 说明 |
|------|------|
| `pattern` | 自定义解析 pattern，默认使用 Envoy 标准格式 |
| `-r, --regex` | 使用正则语法解析 |
| `--tencent-cloud-action` | 追加腾讯云 API action 字段 |
| `--strip-missing-value` | 去除 null 值字段 |
| `--into-datetime` | 将 start-time 转为 datetime 类型 |

默认解析字段：

| 字段 | 类型 | 说明 |
|------|------|------|
| `start-time` | string/datetime | 请求开始时间 |
| `method` | string | HTTP 方法 |
| `path` | string | 请求路径 |
| `protocol` | string | HTTP 协议版本 |
| `response-code` | int | 响应状态码 |
| `response-flags` | string | Envoy 响应标志 |
| `bytes-received` | filesize | 接收字节数 |
| `bytes-sent` | filesize | 发送字节数 |
| `duration` | duration | 请求总耗时 |
| `x-envoy-upstream-service-time` | duration | 上游服务耗时 |
| `x-forwarded-for` | string | 客户端 IP |
| `user-agent` | string | User-Agent |
| `x-request-id` | string | 请求 ID |
| `authority` | string | Host/Authority |
| `upstream-host` | string | 上游地址 |

---

## 典型工作流

### 离线镜像分发（Deployment + DaemonSet 配合）

```nu
# 1. 在 Deployment toolkit 中，将镜像推送到 S3
let images = ["nginx:1.25", "redis:7.2"] | oci push s3
# 返回: [{url: "https://...", image: "nginx:1.25"}, ...]

# 2. 在 DaemonSet toolkit 中，批量导入到所有节点
$images | get url | oci import daemonset -n default -l name=toolkit
```

### 镜像搬运（跨 Registry）

```nu
# 从公网 registry 搬运到内网 registry
["nginx:latest", "redis:7"] | oci push registry "internal-registry.example.com" -n library
```

### S3 文件分享

```nu
# 上传文件并生成 2 小时有效的下载链接
'/tmp/debug-info.tar.gz' | s3 cp "s3:///debug/info.tar.gz"

# 仅生成预签名链接（文件已在 S3）
s3 presign "s3://my-bucket/path/to/file" --expires-in 4hr
```

---

## 凭证配置

S3 命令支持**任意 S3 兼容存储**（AWS S3、腾讯云 COS、阿里云 OSS、MinIO、Ceph RGW 等）。以下示例以腾讯云 COS 为参考，但你可以替换为任何 S3 兼容服务的 endpoint。

凭证可以通过两种方式提供：

1. **从宿主机挂载**（推荐，具备持久性）：将宿主机的凭证目录挂载到容器中
2. **在容器内配置**（临时性）：在 Pod 内手动创建凭证文件——简单但 Pod 重启后丢失

### S3 凭证 (`~/.aws/credentials`)

```ini
[default]
aws_access_key_id = YOUR_ACCESS_KEY
aws_secret_access_key = YOUR_SECRET_KEY
# 任意 S3 兼容的 endpoint，例如：
# 腾讯云 COS: https://cos.ap-guangzhou.myqcloud.com
# 阿里云 OSS: https://oss-cn-hangzhou.aliyuncs.com
# MinIO: http://minio.local:9000
endpoint_url = https://your-s3-compatible-endpoint.com
bucket = your-default-bucket
```

可选的 `~/.aws/config`：

```ini
[default]
region = ap-guangzhou
```

### OCI Registry 凭证

OCI registry 认证依赖 `~/.docker/config.json`（标准 docker 认证格式）。

### 内联凭证

你也可以通过命令行参数直接传递凭证，无需任何配置文件：

```nu
s3 presign "s3://bucket/file" --access-key YOUR_AK --secret-key YOUR_SK --endpoint-url "https://your-endpoint.com"
```
