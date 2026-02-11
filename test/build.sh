#!/usr/bin/env zsh

# ==============================================================================
# 配置部分 - 根据您的实际情况修改这些变量
# ==============================================================================
REPO_URL="https://github.com/sbsrf/sbsrf.git"  # 您的仓库地址
LIBRIME_URL="https://github.com/rime/librime/releases/download/1.16.1/rime-de4700e-macOS-universal.tar.bz2" # macOS 版本的 librime
WORK_DIR="${TMPDIR:-/tmp}/sbsrf_local_build_$(date +%Y%m%d%H%M%S)" # 临时工作目录（修复 TMPDIR 为空的情况）

# ==============================================================================
# 函数定义（适配 zsh 语法）
# ==============================================================================
info() {
    echo -e "\033[1;36m=== $1 ===\033[0m"
}

success() {
    echo -e "\033[1;32m✅ $1\033[0m"
}

error() {
    echo -e "\033[1;31m❌ $1\033[0m"
    exit 1
}

# ==============================================================================
# 1. 创建并进入工作目录
# ==============================================================================
info "1. 创建并进入工作目录"
mkdir -p "$WORK_DIR" || error "创建工作目录失败"
cd "$WORK_DIR" || error "进入工作目录失败"
echo "工作目录: $WORK_DIR"

# ==============================================================================
# 2. 克隆仓库
# ==============================================================================
info "2. 克隆仓库"
git clone "$REPO_URL" . || error "克隆仓库失败，请检查网络连接或仓库地址。"

# ==============================================================================
# 3. 下载并解压 librime
# ==============================================================================
info "3. 下载并解压 librime"
mkdir -p librime || error "创建 librime 目录失败"
LIBRIME_ARCHIVE="librime/rime.tar.bz2"

# 下载文件
curl -L -o "$LIBRIME_ARCHIVE" "$LIBRIME_URL" || error "下载 librime 失败。"
# zsh 推荐使用 [[ ]] 做条件判断，兼容性更好
if [[ ! -f "$LIBRIME_ARCHIVE" ]]; then
    error "下载的 librime 文件不存在。"
fi

# 解压文件 (macOS 自带 tar)
tar -xjf "$LIBRIME_ARCHIVE" -C librime/ --strip-components=2 || error "解压 librime 失败。"
success "已解压 librime 到: $WORK_DIR/librime"

# ==============================================================================
# 4. 配置环境变量（新增 DYLD_LIBRARY_PATH）
# ==============================================================================
info "4. 配置环境变量"
LIBRIME_PATH="$WORK_DIR/librime"

# 1. 配置可执行文件路径（PATH）
# 2. 配置动态库路径（DYLD_LIBRARY_PATH，macOS 专属）
export PATH="$LIBRIME_PATH:$PATH"
export DYLD_LIBRARY_PATH="$LIBRIME_PATH:$DYLD_LIBRARY_PATH"

echo "已配置环境变量："
echo "  - PATH: $LIBRIME_PATH (可执行文件)"
echo "  - DYLD_LIBRARY_PATH: $LIBRIME_PATH (动态库)"

# 验证 rime_deployer 和动态库
info "验证 rime_deployer 及依赖库..."
if command -v rime_deployer &> /dev/null; then
    # 额外验证动态库是否能被加载
    if otool -L $(command -v rime_deployer) | grep -q librime; then
        success "rime_deployer 及依赖库均可用。"
    else
        error "rime_deployer 存在，但未找到 librime 动态库依赖！"
    fi
else
    error "无法找到 rime_deployer 命令，请检查解压后的目录结构！"
fi

# ==============================================================================
# 5. 执行构建
# ==============================================================================
info "5. 执行构建"

# 列出当前目录文件（调试用）
echo "构建前当前目录文件:"
ls -la

# 移动文件
echo -e "\n移动 sbxlm 目录下的文件..."
mv -f sbxlm/* . 2>/dev/null || echo "注意: sbxlm 目录可能为空或不存在，跳过移动。"

# 执行构建命令
echo -e "\n运行 rime_deployer --build..."
rime_deployer --build . "$HOME/Library/Rime" || error "构建失败！"

# ==============================================================================
# 6. 清理文件
# ==============================================================================
info "6. 清理不需要的文件"
rm -rf bihua* zhlf* sbfc* *.extended.dict.yaml *2.schema.yaml user.yaml sbpy.base.dict.yaml sbpy.ext.dict.yaml sbpy.tencent.dict.yaml 2>/dev/null
success "文件清理完成。"

# ==============================================================================
# 7. 打包
# ==============================================================================
info "7. 打包生成 sbsrf.zip"
zip -q -r sbsrf.zip build lua opencc *.yaml *.txt 2>/dev/null
# zsh 推荐使用 [[ ]] 做条件判断
if [[ -f "sbsrf.zip" ]]; then
    success "打包成功！文件位于: $WORK_DIR/sbsrf.zip"
else
    echo -e "\033[1;33m⚠️  警告: 打包步骤可能未找到指定文件，未生成 sbsrf.zip。\033[0m"
fi

# ==============================================================================
# 完成
# ==============================================================================
info "本地构建脚本执行完毕"
echo "工作目录: $WORK_DIR"
echo "请检查上述输出，特别是错误信息，以定位问题。"