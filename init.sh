#!/bin/bash
# init.sh - Turtle Investment Framework environment setup
# Run at the start of each Claude Code session
#
# 中文说明：
# - 这个脚本用于“在项目根目录创建/复用虚拟环境 + 安装依赖 + 检查 Token + 跑一小轮测试”。
# - 设计目标是：你在不同机器/不同 cwd 下，都能用一条命令把环境拉起到可运行状态。

set -e

# 项目根目录：脚本所在目录
PROJECT_ROOT="$(cd "$(dirname "$0")" && pwd)"
cd "$PROJECT_ROOT"

echo "=== Turtle Investment Framework - Environment Setup ==="
echo "Project root: $PROJECT_ROOT"
echo ""

# Args
FORCE_INSTALL=0
REBUILD_VENV=0
for arg in "$@"; do
    case "$arg" in
        --force-install)
            FORCE_INSTALL=1
            ;;
        --rebuild-venv|--force-recreate-venv)
            REBUILD_VENV=1
            ;;
    esac
done

# 1. Python environment (venv)
# 约定把虚拟环境放在项目根目录的 .venv 目录下（便于版本隔离、避免污染全局 Python）
VENV_DIR="$PROJECT_ROOT/.venv"
# 虚拟环境的 Python 可执行文件路径
if [[ "${OSTYPE:-}" == msys* || "${OSTYPE:-}" == cygwin* || "${OSTYPE:-}" == win32* ]]; then
    PYTHON_BIN="$VENV_DIR/Scripts/python.exe"
    VENV_BIN_DIR="$VENV_DIR/Scripts"
else
    PYTHON_BIN="$VENV_DIR/bin/python"
    VENV_BIN_DIR="$VENV_DIR/bin"
fi

echo "[1/5] Setting up Python environment..."

_to_unix_path() {
    if command -v cygpath >/dev/null 2>&1; then
        cygpath -u "$1"
    else
        echo "$1"
    fi
}

_py_ver_mm() {
    "$1" -c 'import sys; print(f"{sys.version_info.major}.{sys.version_info.minor}")' 2>/dev/null || true
}

_is_py310_plus() {
    local bin="$1"
    local ver
    ver="$(_py_ver_mm "$bin")"
    if [[ "$ver" =~ ^([0-9]+)\.([0-9]+)$ ]]; then
        local major="${BASH_REMATCH[1]}"
        local minor="${BASH_REMATCH[2]}"
        if [[ "$major" -ge 3 && "$minor" -ge 10 ]]; then
            return 0
        fi
    fi
    return 1
}

# Find a Python >= 3.10 by searching common candidates
# 说明：
# - 这里的 PYTHON_SYS 是“用来创建 venv 的系统 Python”
# - 需要 >= 3.10，避免一些依赖在旧 Python 上不可用
PYTHON_SYS=""

# 如果 venv 已经存在，优先复用；但如果版本 < 3.10 或者显式要求重建，则重建 venv
if [ -f "$PYTHON_BIN" ]; then
    if [ "$REBUILD_VENV" -eq 1 ]; then
        echo "  Rebuilding venv at $VENV_DIR ..."
        rm -rf "$VENV_DIR"
    elif _is_py310_plus "$PYTHON_BIN"; then
        PYTHON_SYS="$PYTHON_BIN"
    else
        VENV_PY_VER="$(_py_ver_mm "$PYTHON_BIN")"
        echo "  Detected existing venv Python $VENV_PY_VER (< 3.10). Rebuilding venv..."
        rm -rf "$VENV_DIR"
    fi
fi

if [ -z "$PYTHON_SYS" ]; then
    if command -v py >/dev/null 2>&1; then
        for v in 3.14 3.13 3.12 3.11 3.10; do
            exe="$(py -"$v" -c 'import sys; print(sys.executable)' 2>/dev/null || true)"
            if [ -n "$exe" ]; then
                exe_u="$(_to_unix_path "$exe")"
                if [ -x "$exe_u" ] && _is_py310_plus "$exe_u"; then
                    PYTHON_SYS="$exe_u"
                    break
                fi
            fi
        done
    fi

    if [ -z "$PYTHON_SYS" ] && command -v conda >/dev/null 2>&1; then
        CONDA_BASE="$(conda info --base 2>/dev/null || true)"
        if [ -n "$CONDA_BASE" ]; then
            CONDA_BASE_U="$(_to_unix_path "$CONDA_BASE")"
            for env_name in PY310 AI-Trader PY39 base; do
                if [ "$env_name" = "base" ]; then
                    candidate="$CONDA_BASE_U/python.exe"
                else
                    candidate="$CONDA_BASE_U/envs/$env_name/python.exe"
                fi
                if [ -x "$candidate" ] && _is_py310_plus "$candidate"; then
                    PYTHON_SYS="$candidate"
                    break
                fi
            done
        fi
    fi

    if [ -z "$PYTHON_SYS" ]; then
        for candidate in python3 python3.14 python3.13 python3.12 python3.11 python3.10 \
                         /opt/homebrew/bin/python3 /opt/homebrew/bin/python3.14 \
                         /opt/homebrew/bin/python3.13 /opt/homebrew/bin/python3.12 \
                         /opt/homebrew/bin/python3.11 /opt/homebrew/bin/python3.10 \
                         /opt/anaconda3/envs/py10/bin/python; do
            BIN="$(command -v "$candidate" 2>/dev/null || echo "$candidate")"
            if [ -x "$BIN" ] && _is_py310_plus "$BIN"; then
                PYTHON_SYS="$BIN"
                break
            fi
        done
    fi
fi

# 如果没有找到合适的 Python，则直接报错退出（后续 venv/依赖安装都无法继续）
if [ -z "$PYTHON_SYS" ]; then
    echo "  ERROR: No Python >= 3.10 found on this system"
    echo "  Install Python 3.10+ via Homebrew: brew install python@3.12"
    exit 1
fi
# 输出用于创建 venv 的 Python 版本号（仅主.次版本）
PY_VER="$(_py_ver_mm "$PYTHON_SYS")"

# 如果项目还没有 venv，就创建；否则复用已有 venv
if [ ! -f "$PYTHON_BIN" ]; then
    echo "  Creating venv at $VENV_DIR (Python $PY_VER) ..."
    $PYTHON_SYS -m venv "$VENV_DIR"
    VENV_JUST_CREATED=1
else
    VENV_JUST_CREATED=0
fi

# 把 venv 的 bin 目录放到 PATH 前面，确保后续用的是 venv 的 python/pip
export PATH="$VENV_BIN_DIR:$PATH"
echo "  Python: $($PYTHON_BIN --version)"
echo "  Using: $PYTHON_BIN"

# 2. Install dependencies (on first create or --force-install)
# 说明：
# - 首次创建 venv 会自动安装 requirements.txt
# - 如果你想强制重装依赖：bash init.sh --force-install
echo "[2/5] Installing Python dependencies..."
if [ "$VENV_JUST_CREATED" -eq 1 ] || [ "$FORCE_INSTALL" -eq 1 ]; then
    $PYTHON_BIN -m pip install -q -r requirements.txt
    echo "  Dependencies installed."
else
    echo "  Skipped (venv exists). Use 'bash init.sh --force-install' to reinstall."
fi

# 3. Verify Tushare token
# 说明：
# - 如果项目根目录存在 .env，则读取其中的环境变量（只对当前 shell 生效）
# - 如果未设置 TUSHARE_TOKEN，依赖实时 API 的测试会被跳过
echo "[3/5] Checking Tushare token..."
# Source .env file if present
if [ -f "$PROJECT_ROOT/.env" ]; then
    set -a
    source "$PROJECT_ROOT/.env"
    set +a
    echo "  Loaded .env file"
fi
if [ -z "$TUSHARE_TOKEN" ]; then
    echo "  WARNING: TUSHARE_TOKEN not set"
    echo "  Option 1: cp .env.sample .env && edit .env"
    echo "  Option 2: export TUSHARE_TOKEN='your_token_here'"
    echo "  Tests requiring live API will be skipped"
else
    echo "  TUSHARE_TOKEN: set (${#TUSHARE_TOKEN} chars)"
fi

# 4. Create output directory
# 运行期输出统一写入 output/（被 gitignore 忽略）
echo "[4/5] Ensuring output directory..."
mkdir -p output

# 5. Run basic tests
# 只跑一轮快速验证（-x 首个失败就停；-q 简洁输出；--tb=short 简短 traceback）
echo "[5/5] Running verification tests..."
$PYTHON_BIN -m pytest tests/ -x -q --tb=short 2>&1 | tail -5

echo ""
echo "=== Setup complete ==="
echo "To run: python scripts/tushare_collector.py --code 600887.SH --output output/data_pack_market.md"
