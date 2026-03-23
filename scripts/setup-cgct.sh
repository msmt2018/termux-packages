#!/usr/bin/env bash
# setup CGCT - Cross Gnu Compilers for Termux
# compile glibc-based binaries for Termux

# 加载属性定义
. $(dirname "$(realpath "$0")")/properties.sh
. $(dirname "$(realpath "$0")")/build/termux_download.sh

set -e -u

# 核心变量显式对齐自定义包名
ARCH="x86_64"
REPO_URL="https://service.termux-pacman.dev{ARCH}"
# 强制覆盖为你的自定义路径
CGCT_DIR="/data/data/com.itsaky.androidide/cgct"

if [ "$ARCH" != "$(uname -m)" ]; then
	echo "Error: the requested CGCT is not supported on your architecture"
	exit 1
fi

declare -A CGCT=(
	["cbt"]="2.45.1-0" # Cross Binutils for Termux
	["cgt"]="15.2.0-0" # Cross GCCs for Termux
	["glibc-cgct"]="2.42-0" # Glibc for CGCT
 	["cgct-headers"]="6.18.6-0" # Headers for CGCT
)

: "${TERMUX_PKG_TMPDIR:="/tmp"}"
TMPDIR_CGCT="${TERMUX_PKG_TMPDIR}/cgct"

# 创建临时工作目录
if [ ! -d "$TMPDIR_CGCT" ]; then
	mkdir -p "$TMPDIR_CGCT"
fi

# 清理旧的 CGCT
if [ -d "$CGCT_DIR" ]; then
	echo "Removing the old CGCT..."
	rm -fr "$CGCT_DIR"
fi

# 确保目标基础目录存在
mkdir -p "/data/data/com.itsaky.androidide"

# 开始安装 CGCT 组件
echo "Installing CGCT..."
curl -L "${REPO_URL}/cgct.json" -o "${TMPDIR_CGCT}/cgct.json"
for pkgname in ${!CGCT[@]}; do
	SHA256SUM=$(jq -r '."'$pkgname'"."SHA256SUM"' "${TMPDIR_CGCT}/cgct.json")
	if [ "$SHA256SUM" = "null" ]; then
		echo "Error: package '${pkgname}' not found"
		exit 1
	fi
	version="${CGCT[$pkgname]}"
	version_of_json=$(jq -r '."'$pkgname'"."VERSION"' "${TMPDIR_CGCT}/cgct.json")
	if [ "${version}" != "${version_of_json}" ]; then
		echo "Error: versions do not match: requested - '${version}'; actual - '${version_of_json}'"
		exit 1
	fi
	filename=$(jq -r '."'$pkgname'"."FILENAME"' "${TMPDIR_CGCT}/cgct.json")
	if [ ! -f "${TMPDIR_CGCT}/${filename}" ]; then
		termux_download "${REPO_URL}/${filename}" \
			"${TMPDIR_CGCT}/${filename}" \
			"${SHA256SUM}"
	fi
    
    # 核心修复：解压时通过 transform 将 com.termux 替换为 com.itsaky.androidide
    # 这样文件才会落入正确的 CGCT_DIR 路径
	tar xJf "${TMPDIR_CGCT}/${filename}" --transform 's|com.termux|com.itsaky.androidide|' -C / data
done

# 安装 gcc-libs (来自 Arch Linux)
if [ ! -f "${CGCT_DIR}/lib/libgcc_s.so" ]; then
	pkgname="gcc-libs"
	echo "Installing ${pkgname} for CGCT..."
	termux_download "https://archive.archlinux.org" \
		"${TMPDIR_CGCT}/${pkgname}.pkg.zstd" \
		"6eedd2e4afc53e377b5f1772b5d413de3647197e36ce5dc4a409f993668aa5ed"
	
    tar --use-compress-program=unzstd -xf "${TMPDIR_CGCT}/${pkgname}.pkg.zstd" -C "${TMPDIR_CGCT}" usr/lib
	
    # 确保目标 lib 和 bin 目录存在
    mkdir -p "${CGCT_DIR}/lib" "${CGCT_DIR}/bin"
    cp -r "${TMPDIR_CGCT}/usr/lib/"* "${CGCT_DIR}/lib"
fi

# 检查并运行 setup-cgct
# 此时文件应该已经在 /data/data/com.itsaky.androidide/cgct/bin/ 下了
if [ ! -f "${CGCT_DIR}/bin/setup-cgct" ]; then
	echo "Error: setup-cgct command not found at ${CGCT_DIR}/bin/setup-cgct"
    # 打印目录内容辅助排查
    echo "Directory listing for ${CGCT_DIR}:"
    ls -R "${CGCT_DIR}" | head -n 20
	exit 1
fi

echo "Running setup-cgct..."
"${CGCT_DIR}/bin/setup-cgct" "/usr/lib/x86_64-linux-gnu"
