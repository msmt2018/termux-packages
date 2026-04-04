# AndroidIDE (`com.itsaky.androidide`) 全环境迁移与 Docker/Bootstrap 构建指南

> 目标：将 Termux 官方构建流程迁移到你自己的账号体系（GitHub + Docker Hub），并使用你自己的 Docker 镜像构建 **全量 rootfs/bootstrap**。

## 0. 先确认 Docker Token 是否可用

你给出的字符串形如：`dckr_pat_...`，这通常是 **Docker Hub Personal Access Token (PAT)** 的格式。

建议立刻做一次本地验证（不要把 token 发到公开位置）：

```bash
echo '你的token' | docker login -u androidzeros --password-stdin
```

如果提示 `Login Succeeded`，说明 token 正常。

如果失败，去 Docker Hub 重新申请：

1. 打开 `https://hub.docker.com/`
2. 右上角头像 -> **Account Settings**
3. 左侧 **Personal access tokens**
4. 点击 **Generate new token**
5. 权限建议至少包含可 push（Write）
6. 保存后只显示一次，立即复制到密码管理器

---

## 1. 账号侧准备（一次性）

- GitHub：fork `termux/termux-packages` 到你自己的仓库（例如 `androidzeros/termux-packages`）。
- Docker Hub：建议创建镜像仓库名：
  - `androidzeros/package-builder`
  - （可选）`androidzeros/package-builder-cgct`

---

## 2. 在仓库中构建并推送你自己的 Docker 镜像

在仓库根目录执行：

```bash
cd /workspace/termux-packages

docker build -t androidzeros/termux-package-builder:latest scripts/
docker push androidzeros/termux-package-builder:latest
```

可选（如果你需要 cgct 镜像）：

```bash
docker build -t androidzeros/termux-package-builder-cgct:latest -f scripts/Dockerfile.cgct scripts/
docker push androidzeros/termux-package-builder-cgct:latest
```

---

## 3. 让构建脚本使用你的镜像

临时方式（推荐先这样验证）：

```bash
export TERMUX_BUILDER_IMAGE_NAME=androidzeros/termux-package-builder:latest
./scripts/run-docker.sh true
```

如果容器正常启动，表示后续构建都会走你的镜像。

---

## 4. 针对 AndroidIDE 路径构建全量包/全量 rootfs

仓库里已经有对 AndroidIDE 前缀路径的支持（例如 `data/data/com.itsaky.androidide/...` 场景）。

### 4.1 构建全量包（示例：按架构）

```bash
# aarch64 示例
./scripts/run-docker.sh ./build-package.sh -a aarch64 -I -f $(./scripts/list-packages.sh)
```

> 说明：全量构建耗时很长、磁盘占用极高，建议分批或按依赖树构建。

### 4.2 生成 bootstrap archives / rootfs

```bash
./scripts/run-docker.sh ./scripts/build-bootstraps.sh --architectures aarch64 -f
```

产物通常在 `output/` 下（按脚本输出为准）。

---

## 5. CI 全迁移到你账号（推荐）

将 GitHub Actions 中涉及的镜像命名从官方/默认改为你的命名空间：

- `androidzeros/termux-package-builder:latest`
- `ghcr.io/androidzeros/termux-package-builder:latest`（若也推 GHCR）

并在 GitHub 仓库 Secret 中配置：

- `DOCKER_USERNAME=androidzeros`
- `DOCKER_TOKEN=<你的PAT>`

---

## 6. 尺寸与正确性建议（非常关键）

- 先固定架构（例如只做 `aarch64`）验证流程。
- 使用与官方一致的 `scripts/Dockerfile`、`scripts/setup-ubuntu.sh`、`scripts/setup-android-sdk.sh`，避免环境漂移。
- 生成 bootstrap 后做最小启动验证：
  - 解压到测试目录
  - 执行 second-stage 脚本
  - 验证 `apt/dpkg` 可用
- 对比官方 bootstrap 的文件结构与关键二进制依赖（`readelf -d` / `ldd` 检查）。

---

## 7. 安全提醒（强烈建议）

你已经在聊天里暴露了 token。建议：

1. 立刻在 Docker Hub **撤销该 token**。
2. 重新生成新 token。
3. 只通过 `--password-stdin` 使用，不要明文写进脚本或日志。

---

## 8. 一键化示例（本地）

```bash
#!/usr/bin/env bash
set -euo pipefail

export DOCKER_USER=androidzeros
export IMAGE=${DOCKER_USER}/termux-package-builder:latest
export TERMUX_BUILDER_IMAGE_NAME=${IMAGE}

# 1) 登录
echo "$DOCKER_TOKEN" | docker login -u "$DOCKER_USER" --password-stdin

# 2) 构建并推送镜像
docker build -t "$IMAGE" scripts/
docker push "$IMAGE"

# 3) 验证容器可用
./scripts/run-docker.sh true

# 4) 生成 bootstrap（示例 aarch64）
./scripts/run-docker.sh ./scripts/build-bootstraps.sh --architectures aarch64 -f

echo "Done"
```

---

如果你愿意，我下一步可以按你的目标架构（`aarch64/arm/i686/x86_64`）给你一份**可直接用在 GitHub Actions 的完整 workflow 文件**（包含自动 build 镜像、push、再构建 bootstrap、最后上传 artifact）。

---

## 9. 你这四个仓库名的全流程（已适配）

你已经创建的仓库：

- `androidzeros/termux-docker`
- `androidzeros/terminal-packaging`
- `androidzeros/termux-package-builder`
- `androidzeros/termux-package-builder-cgct`

仓库里新增了一键脚本：

```bash
scripts/docker/androidzeros-full-pipeline.sh
```

### 9.1 本地一键执行（登录 + 构建 + push）

```bash
export DOCKER_TOKEN='你的新token'
./scripts/docker/androidzeros-full-pipeline.sh \
  --namespace androidzeros \
  --tag latest \
  --login --build --push --verbose
```

### 9.2 拉取四个镜像（验证已上传）

```bash
./scripts/docker/androidzeros-full-pipeline.sh \
  --namespace androidzeros \
  --tag latest \
  --pull --verbose
```

### 9.3 用你自己的 builder 镜像编译 bootstrap

```bash
export TERMUX_BUILDER_IMAGE_NAME=androidzeros/termux-package-builder:latest
./scripts/run-docker.sh true
./scripts/run-docker.sh ./scripts/build-bootstraps.sh --architectures aarch64 -f
```

---

## 10. GitHub Actions 自动化（已给你 workflow）

新增 workflow：

```text
.github/workflows/androidzeros_full_pipeline.yml
```

功能：

1. 登录 Docker Hub（使用 `DOCKER_USERNAME` / `DOCKER_TOKEN` secrets）
2. 构建并 push 你四个仓库的镜像
3. 可选自动构建 bootstrap
4. 上传 bootstrap 产物为 artifact

你只需要在 GitHub 仓库里配置：

- `DOCKER_USERNAME=androidzeros`
- `DOCKER_TOKEN=<新PAT>`

然后在 Actions 页面手动触发 `Androidzeros Full Docker Pipeline` 即可。
