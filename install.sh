#!/bin/bash
#
# LiteLLM Gateway 一键部署脚本
# 支持 智谱 GLM Coding Plan
# 用法: ./install.sh
#

set -e

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

# 打印函数
log_info() { printf "${GREEN}%s${NC}\n" "$1"; }
log_warn() { printf "${YELLOW}%s${NC}\n" "$1"; }
log_error() { printf "${RED}%s${NC}\n" "$1"; }

# 默认配置
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
SOURCE_DIR="$SCRIPT_DIR/litellm-gateway"
INSTALL_DIR="${INSTALL_DIR:-$SOURCE_DIR}"
GATEWAY_PORT="${GATEWAY_PORT:-4000}"

log_info "========================================"
log_info "  LiteLLM Gateway 一键部署脚本"
log_info "  支持三家 Coding Plan 提供商"
log_info "========================================"
echo ""

# 检查 Docker
log_warn "[1/6] 检查 Docker..."
if ! command -v docker &> /dev/null; then
    log_error "Docker 未安装"
    echo "请先安装 Docker: https://docs.docker.com/get-docker/"
    exit 1
fi

if ! docker compose version &> /dev/null; then
    log_error "Docker Compose 未安装"
    exit 1
fi

log_info "✓ Docker 已安装"

# 检查源文件
log_warn "[2/6] 检查源文件..."
if [ ! -d "$SOURCE_DIR" ]; then
    log_error "源目录不存在: $SOURCE_DIR"
    exit 1
fi

if [ ! -f "$SOURCE_DIR/config/litellm_config.yaml" ]; then
    log_error "配置文件不存在: $SOURCE_DIR/config/litellm_config.yaml"
    exit 1
fi

log_info "✓ 源文件检查通过"

# 创建目录结构
log_warn "[3/6] 创建目录结构..."
mkdir -p "$INSTALL_DIR"/{config,data,logs,scripts,ssl}
log_info "✓ 目录创建完成: $INSTALL_DIR"

# 复制配置文件
log_warn "[4/6] 复制配置文件..."
cp "$SOURCE_DIR/config/litellm_config.yaml" "$INSTALL_DIR/config/"
cp "$SOURCE_DIR/config/nginx.conf" "$INSTALL_DIR/config/" 2>/dev/null || true
cp "$SOURCE_DIR/docker-compose.yml" "$INSTALL_DIR/"
cp "$SOURCE_DIR/scripts/manage_keys.py" "$INSTALL_DIR/scripts/"
cp "$SOURCE_DIR/scripts/test_gateway.sh" "$INSTALL_DIR/scripts/" 2>/dev/null || true
chmod +x "$INSTALL_DIR/scripts/"*.py "$INSTALL_DIR/scripts/"*.sh 2>/dev/null || true
log_info "✓ 配置文件已复制"

# 生成 .env 文件（如果不存在）
if [ ! -f "$INSTALL_DIR/.env" ]; then
    log_warn "[5/6] 生成 .env 文件..."

    MASTER_KEY="sk-admin-$(openssl rand -hex 16)"
    SALT_KEY=$(openssl rand -hex 16)

    cat > "$INSTALL_DIR/.env" << EOF
# ===========================================
# LiteLLM Gateway 环境变量
# 生成时间: $(date)
# ===========================================

# 主密钥 - 仅供应商持有，用于管理
LITELLM_MASTER_KEY=${MASTER_KEY}

# 加密密钥 - 用于加密存储的 API Key (首次设置后不可更改!)
LITELLM_SALT_KEY=${SALT_KEY}

# ===========================================
# 阿里云 Coding Plan API Key
# 获取地址: https://dashscope.console.aliyun.com/
ALIYUN_API_KEY=YOUR_ALIYUN_CODING_PLAN_KEY_HERE

# ===========================================
# 火山引擎 Coding Plan API Key
# 获取地址: https://console.volcengine.com/ark
VOLCENGINE_API_KEY=YOUR_VOLCENGINE_CODING_PLAN_KEY_HERE

# 火山引擎 视觉模型专用 Key
VOLCENGINE_VISION_KEY=YOUR_VOLCENGINE_VISION_KEY_HERE

# ===========================================
# 智谱官方 Coding Plan API Key
# 获取地址: https://open.bigmodel.cn/
ZHIPUAI_API_KEY=YOUR_ZHIPUAI_CODING_PLAN_KEY_HERE

# 数据库配置
DB_PASSWORD=litellm_db_password
DATABASE_URL=postgresql://litellm:litellm_db_password@db:5432/litellm
EOF

    chmod 600 "$INSTALL_DIR/.env"
    log_info "✓ .env 文件已生成"
    log_warn "  请编辑 $INSTALL_DIR/.env 填入你的 Coding Plan API Key"
else
    log_info "✓ .env 文件已存在，跳过生成"
fi

# 提示配置 API Key
echo ""
log_warn "请先配置 API Key，然后继续..."
echo ""
echo "编辑 $INSTALL_DIR/.env 文件:"
echo ""
echo "  阿里云:     ALIYUN_API_KEY=你的密钥"
echo "  火山引擎:   VOLCENGINE_API_KEY=你的密钥"
echo "  火山视觉:   VOLCENGINE_VISION_KEY=你的密钥"
echo "  智谱官方:   ZHIPUAI_API_KEY=你的密钥"
echo ""
echo "获取方式:"
echo "  阿里云:   https://dashscope.console.aliyun.com/"
echo "  火山引擎: https://console.volcengine.com/ark"
echo "  智谱:     https://open.bigmodel.cn/"
echo ""

read -p "已配置好 API Key? 按 Enter 继续..."

# 启动服务
echo ""
log_warn "[6/6] 启动服务..."
cd "$INSTALL_DIR"

docker compose pull
docker compose up -d

log_warn "等待服务启动..."
sleep 10

# 检查服务状态
for i in {1..30}; do
    if docker logs litellm-gateway 2>&1 | grep -q "Application startup complete"; then
        log_info "✓ 服务启动成功"
        break
    fi
    if [ $i -eq 30 ]; then
        log_error "✗ 服务启动超时，请检查日志:"
        echo "  docker compose logs -f litellm"
        exit 1
    fi
    sleep 2
done

# 获取管理密钥
MASTER_KEY=$(grep '^LITELLM_MASTER_KEY=' "$INSTALL_DIR/.env" | cut -d'=' -f2-)

echo ""
log_info "========================================"
log_info "  部署完成!"
log_info "========================================"
echo ""
echo "📁 安装目录: $INSTALL_DIR"
echo "🔐 管理密钥: $MASTER_KEY"
echo ""
echo "🔑 Key 管理:"
echo "   python3 $INSTALL_DIR/scripts/manage_keys.py --help"
echo ""
echo "📝 常用命令:"
echo "   查看日志:   cd $INSTALL_DIR && docker compose logs -f litellm"
echo "   重启服务:   cd $INSTALL_DIR && docker compose restart"
echo "   停止服务:   cd $INSTALL_DIR && docker compose down"
echo ""
echo "📖 客户使用方式 (OpenAI 兼容):"
echo ""
echo "  from openai import OpenAI"
echo ""
echo "  client = OpenAI("
echo "      base_url='http://<服务器IP>/v1',"
echo "      api_key='<分发给客户的Key>'"
echo "  )"
echo ""
log_warn "⚠️  请妥善保管管理密钥，不要泄露给客户!"
