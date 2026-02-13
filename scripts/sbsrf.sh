#!/usr/bin/env zsh

# 先保存原始当前目录（避免 cd 后丢失）
ORIGINAL_DIR=$(pwd)
PARENT_DIR=$(dirname "$ORIGINAL_DIR")
echo "✅ 原始执行目录：$ORIGINAL_DIR"
echo "✅ 父目录：$PARENT_DIR"
# 核心修复2：只保存目录路径，不提前加通配符
SBXLM_DIR="$PARENT_DIR/sbxlm"
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

# 新增：调试函数，打印目录详情
debug_dir() {
    local dir_path="$1"
    echo "📋 调试：目录 $dir_path 详情："
    ls -la "$dir_path" 2>/dev/null || echo "目录不存在或无权限访问"
}

# ==============================================================================
# 前置检查：验证 sbxlm 目录是否存在且有文件
# ==============================================================================
info "前置检查：验证声笔方案目录"
debug_dir "$SBXLM_DIR"

# 检查目录是否存在
if [[ ! -d "$SBXLM_DIR" ]]; then
    error "声笔方案目录不存在：$SBXLM_DIR\n请确认 sbxlm 目录在父目录下，或检查路径是否正确。"
fi

# 检查目录是否为空
if [[ -z "$(ls -A "$SBXLM_DIR" 2>/dev/null)" ]]; then
    error "声笔方案目录为空：$SBXLM_DIR\n请确认目录下有源码文件。"
fi
success "声笔方案目录验证通过：$SBXLM_DIR"

# ==============================================================================
# 1. 创建并进入工作目录
# ==============================================================================
info "1. 创建并进入工作目录"
mkdir -p "$WORK_DIR" || error "创建工作目录失败"
cd "$WORK_DIR" || error "进入工作目录失败"
echo "工作目录: $WORK_DIR"

# ==============================================================================
# 2. 复制声笔方案源码（核心修复）
# ==============================================================================
info "2. 复制声笔方案源码"
setopt +o nomatch
if ! cp -rf "$SBXLM_DIR"/* . 2> copy_error.log; then
    echo "📋 复制错误详情："
    cat copy_error.log
    error "复制声笔方案源码失败。"
fi
unsetopt nomatch

# 验证复制结果
echo "📋 复制后工作目录内容："
ls -la
success "声笔方案源码复制成功"

# ==============================================================================
# 3. 解压 librime
# ==============================================================================
info "3. 解压 librime"
mkdir -p librime || error "创建 librime 目录失败"
LIBRIME_ARCHIVE="/Users/daishilin/Downloads/rime-de4700e-macOS-universal.tar.bz2"

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