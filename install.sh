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

# 打印函数 (兼容 macOS/Linux)
log_info() { printf "${GREEN}%s${NC}\n" "$1"; }
log_warn() { printf "${YELLOW}%s${NC}\n" "$1"; }
log_error() { printf "${RED}%s${NC}\n" "$1"; }

# 默认配置 - 使用当前目录下的 litellm-gateway
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
INSTALL_DIR="${INSTALL_DIR:-$SCRIPT_DIR/litellm-gateway}"
GATEWAY_PORT="${GATEWAY_PORT:-4000}"

log_info "========================================"
log_info "  LiteLLM Gateway 一键部署脚本"
log_info "  支持 智谱 GLM Coding Plan"
log_info "========================================"
echo ""

# 检查 Docker
log_warn "[1/7] 检查 Docker..."
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

# 创建目录
log_warn "[2/7] 创建目录结构..."
mkdir -p "$INSTALL_DIR"/{config,data,logs,scripts,ssl}
log_info "✓ 目录创建完成: $INSTALL_DIR"

# 生成配置文件
log_warn "[3/7] 生成配置文件..."

# 生成随机密钥
MASTER_KEY="sk-admin-$(openssl rand -hex 16)"

# 创建 .env 文件
cat > "$INSTALL_DIR/.env" << EOF
# ===========================================
# LiteLLM Gateway 环境变量
# 生成时间: $(date)
# ===========================================

# 主密钥 - 仅供应商持有，用于管理
LITELLM_MASTER_KEY=${MASTER_KEY}

# 智谱 Coding Plan API Key
# 获取地址: https://bigmodel.cn/ (需要订阅 Coding Plan 套餐)
ZHIPUAI_API_KEY=YOUR_ZHIPUAI_CODING_PLAN_KEY_HERE

# 数据库连接 (PostgreSQL - 用于 Key 管理)
DATABASE_URL=postgresql://litellm:litellm_db_password@db:5432/litellm
EOF

chmod 600 "$INSTALL_DIR/.env"
log_info "✓ .env 文件已生成"
log_warn "  请编辑 $INSTALL_DIR/.env 填入你的 Coding Plan API Key"

# 创建 LiteLLM 配置 - Coding Plan
cat > "$INSTALL_DIR/config/litellm_config.yaml" << 'EOF'
# LiteLLM Gateway 配置
# 通用模型映射 - 支持 OpenAI/Anthropic 格式
# 文档: https://docs.litellm.ai/docs/

model_list:
  # ===========================================
  # Claude 兼容命名 (Claude Code / Anthropic SDK)
  # ===========================================

  # 自定义命名
  - model_name: claude-sonnet-4.6
    litellm_params:
      model: openai/GLM-5
      api_key: "os.environ/ZHIPUAI_API_KEY"
      api_base: "https://api.z.ai/api/coding/paas/v4"

  - model_name: claude-sonnet-4.5
    litellm_params:
      model: openai/GLM-5
      api_key: "os.environ/ZHIPUAI_API_KEY"
      api_base: "https://api.z.ai/api/coding/paas/v4"

  # 主力模型 - Claude Sonnet 4 (映射到 GLM-5)
  - model_name: claude-sonnet-4-20250514
    litellm_params:
      model: openai/GLM-5
      api_key: "os.environ/ZHIPUAI_API_KEY"
      api_base: "https://api.z.ai/api/coding/paas/v4"

  - model_name: claude-sonnet-4
    litellm_params:
      model: openai/GLM-5
      api_key: "os.environ/ZHIPUAI_API_KEY"
      api_base: "https://api.z.ai/api/coding/paas/v4"

  # 兼容旧版 - Claude 3.5 Sonnet
  - model_name: claude-3-5-sonnet-20241022
    litellm_params:
      model: openai/GLM-5
      api_key: "os.environ/ZHIPUAI_API_KEY"
      api_base: "https://api.z.ai/api/coding/paas/v4"

  - model_name: claude-3-5-sonnet
    litellm_params:
      model: openai/GLM-4.7
      api_key: "os.environ/ZHIPUAI_API_KEY"
      api_base: "https://api.z.ai/api/coding/paas/v4"

  # 轻量模型 - Claude Haiku
  - model_name: claude-3-5-haiku-20241022
    litellm_params:
      model: openai/glm-4-flash
      api_key: "os.environ/ZHIPUAI_API_KEY"
      api_base: "https://open.bigmodel.cn/api/paas/v4"

  - model_name: claude-3-5-haiku
    litellm_params:
      model: openai/glm-4-flash
      api_key: "os.environ/ZHIPUAI_API_KEY"
      api_base: "https://open.bigmodel.cn/api/paas/v4"

  # ===========================================
  # OpenAI 兼容命名
  # ===========================================

  # GPT-5 系列 (映射到 GLM-5)
  - model_name: gpt-5.3
    litellm_params:
      model: openai/GLM-5
      api_key: "os.environ/ZHIPUAI_API_KEY"
      api_base: "https://api.z.ai/api/coding/paas/v4"

  - model_name: gpt-5.2
    litellm_params:
      model: openai/GLM-5
      api_key: "os.environ/ZHIPUAI_API_KEY"
      api_base: "https://api.z.ai/api/coding/paas/v4"

  - model_name: gpt-5
    litellm_params:
      model: openai/GLM-5
      api_key: "os.environ/ZHIPUAI_API_KEY"
      api_base: "https://api.z.ai/api/coding/paas/v4"

  # GPT-4o 系列 (映射到 GLM-5)
  - model_name: gpt-4o
    litellm_params:
      model: openai/GLM-5
      api_key: "os.environ/ZHIPUAI_API_KEY"
      api_base: "https://api.z.ai/api/coding/paas/v4"

  - model_name: gpt-4o-2024-11-20
    litellm_params:
      model: openai/GLM-5
      api_key: "os.environ/ZHIPUAI_API_KEY"
      api_base: "https://api.z.ai/api/coding/paas/v4"

  # GPT-4 Turbo (映射到 GLM-4.7)
  - model_name: gpt-4-turbo
    litellm_params:
      model: openai/GLM-4.7
      api_key: "os.environ/ZHIPUAI_API_KEY"
      api_base: "https://api.z.ai/api/coding/paas/v4"

  - model_name: gpt-4-turbo-2024-04-09
    litellm_params:
      model: openai/GLM-4.7
      api_key: "os.environ/ZHIPUAI_API_KEY"
      api_base: "https://api.z.ai/api/coding/paas/v4"

  # GPT-4 (映射到 GLM-5)
  - model_name: gpt-4
    litellm_params:
      model: openai/GLM-5
      api_key: "os.environ/ZHIPUAI_API_KEY"
      api_base: "https://api.z.ai/api/coding/paas/v4"

  # GPT-3.5 经济版
  - model_name: gpt-3.5-turbo
    litellm_params:
      model: openai/glm-4-flash
      api_key: "os.environ/ZHIPUAI_API_KEY"
      api_base: "https://open.bigmodel.cn/api/paas/v4"

  - model_name: gpt-3.5-turbo-0125
    litellm_params:
      model: openai/glm-4-flash
      api_key: "os.environ/ZHIPUAI_API_KEY"
      api_base: "https://open.bigmodel.cn/api/paas/v4"

router_settings:
  routing_strategy: "simple-shuffle"
  num_retries: 3
  timeout: 120
  retry_after: 1

general_settings:
  master_key: "os.environ/LITELLM_MASTER_KEY"
  database_url: "os.environ/DATABASE_URL"

litellm_settings:
  max_tokens: 8192
  drop_params: true
  set_verbose: false
EOF

log_info "✓ LiteLLM 配置已生成 (Coding Plan)"

# 创建 Nginx 配置
cat > "$INSTALL_DIR/config/nginx.conf" << 'EOF'
events {
    worker_connections 1024;
}

http {
    upstream litellm {
        server litellm:4000;
    }

    limit_req_zone $binary_remote_addr zone=api:10m rate=30r/s;

    server {
        listen 80;
        server_name _;

        # API 代理 - OpenAI 兼容
        location /v1/ {
            limit_req zone=api burst=50 nodelay;

            proxy_pass http://litellm/v1/;
            proxy_set_header Host $host;
            proxy_set_header X-Real-IP $remote_addr;
            proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
            proxy_set_header X-Forwarded-Proto $scheme;

            proxy_connect_timeout 120s;
            proxy_send_timeout 120s;
            proxy_read_timeout 120s;

            # 流式响应支持
            proxy_buffering off;
            proxy_cache off;
        }

        # 健康检查
        location /health {
            proxy_pass http://litellm/health;
        }

        # 模型列表
        location /v1/models {
            proxy_pass http://litellm/v1/models;
            proxy_set_header Host $host;
        }

        # 阻止管理接口外部访问 - 客户无法访问
        location ~ ^/(key|model|config|admin|spend|user|global) {
            return 403 "Forbidden";
        }
    }
}
EOF

log_info "✓ Nginx 配置已生成"

# 创建 Docker Compose - 含 PostgreSQL
cat > "$INSTALL_DIR/docker-compose.yml" << 'EOF'
version: "3.9"

services:
  # PostgreSQL 数据库 - 用于 Key 管理
  db:
    image: postgres:15-alpine
    container_name: litellm-db
    restart: unless-stopped
    environment:
      POSTGRES_USER: litellm
      POSTGRES_PASSWORD: litellm_db_password
      POSTGRES_DB: litellm
    volumes:
      - postgres-data:/var/lib/postgresql/data
    networks:
      - litellm-network
    healthcheck:
      test: ["CMD-SHELL", "pg_isready -U litellm"]
      interval: 5s
      timeout: 5s
      retries: 5

  # LiteLLM 网关
  litellm:
    image: ghcr.io/berriai/litellm:main-latest
    container_name: litellm-gateway
    restart: unless-stopped
    ports:
      - "4000:4000"
    volumes:
      - ./config/litellm_config.yaml:/app/config.yaml:ro
      - ./data:/app/data
      - ./logs:/app/logs
    env_file:
      - .env
    command:
      - --config
      - /app/config.yaml
      - --port
      - "4000"
    healthcheck:
      test: ["CMD", "curl", "-f", "http://localhost:4000/health"]
      interval: 30s
      timeout: 10s
      retries: 3
    networks:
      - litellm-network
    depends_on:
      db:
        condition: service_healthy
    security_opt:
      - no-new-privileges:true
    logging:
      driver: "json-file"
      options:
        max-size: "10m"
        max-file: "3"

  # Nginx 反向代理
  nginx:
    image: nginx:alpine
    container_name: litellm-nginx
    restart: unless-stopped
    ports:
      - "80:80"
    volumes:
      - ./config/nginx.conf:/etc/nginx/nginx.conf:ro
    depends_on:
      - litellm
    networks:
      - litellm-network

networks:
  litellm-network:
    driver: bridge

volumes:
  postgres-data:
EOF

log_info "✓ Docker Compose 配置已生成 (含 PostgreSQL)"

# 创建 Key 管理脚本
cat > "$INSTALL_DIR/scripts/manage_keys.sh" << 'SCRIPT'
#!/bin/bash
#
# LiteLLM Key 管理脚本
#

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
ENV_FILE="$SCRIPT_DIR/../.env"

if [ -f "$ENV_FILE" ]; then
    LITELLM_MASTER_KEY=$(grep '^LITELLM_MASTER_KEY=' "$ENV_FILE" | cut -d'=' -f2-)
fi

GATEWAY_URL="${GATEWAY_URL:-http://localhost:4000}"

GREEN='\033[0;32m'
NC='\033[0m'

create_key() {
    local alias=$1
    local budget=${2:-100}
    local days=${3:-365}

    if [ -z "$alias" ]; then
        echo "用法: $0 create <alias> [budget] [days]"
        exit 1
    fi

    printf "${GREEN}创建 Key: $alias (预算: \$$budget, 有效期: ${days}天)${NC}\n"

    # 模型列表必须与 litellm_config.yaml 中的 model_name 完全一致
    curl -s -X POST "$GATEWAY_URL/key/generate" \
        -H "Authorization: Bearer $LITELLM_MASTER_KEY" \
        -H "Content-Type: application/json" \
        -d "{
            \"models\": [\"claude-sonnet-4.6\", \"claude-sonnet-4.5\", \"claude-sonnet-4-20250514\", \"claude-sonnet-4\", \"claude-3-5-sonnet-20241022\", \"claude-3-5-sonnet\", \"claude-3-5-haiku-20241022\", \"claude-3-5-haiku\", \"gpt-5.3\", \"gpt-5.2\", \"gpt-5\", \"gpt-4o\", \"gpt-4o-2024-11-20\", \"gpt-4-turbo\", \"gpt-4-turbo-2024-04-09\", \"gpt-4\", \"gpt-3.5-turbo\", \"gpt-3.5-turbo-0125\"],
            \"max_budget\": $budget,
            \"duration\": \"${days}d\",
            \"key_alias\": \"$alias\"
        }" | python3 -m json.tool 2>/dev/null || cat
}

list_keys() {
    echo "所有 Key 列表:"
    curl -s "$GATEWAY_URL/key/info" \
        -H "Authorization: Bearer $LITELLM_MASTER_KEY" | python3 -m json.tool 2>/dev/null || cat
}

key_info() {
    local key=$1
    curl -s "$GATEWAY_URL/key/info?key=$key" \
        -H "Authorization: Bearer $LITELLM_MASTER_KEY" | python3 -m json.tool 2>/dev/null || cat
}

revoke_key() {
    local key=$1
    echo "撤销 Key: $key"
    curl -s -X POST "$GATEWAY_URL/key/delete" \
        -H "Authorization: Bearer $LITELLM_MASTER_KEY" \
        -H "Content-Type: application/json" \
        -d "{\"key\": \"$key\"}" | python3 -m json.tool 2>/dev/null || cat
}

test_key() {
    local key=$1
    echo "测试 Key: $key"
    curl -s "$GATEWAY_URL/v1/chat/completions" \
        -H "Authorization: Bearer $key" \
        -H "Content-Type: application/json" \
        -d '{"model":"gpt-4","messages":[{"role":"user","content":"say hi"}],"max_tokens":20}' | python3 -m json.tool 2>/dev/null || cat
}

show_help() {
    echo "LiteLLM Key 管理脚本"
    echo ""
    echo "用法: $0 <command> [args]"
    echo ""
    echo "命令:"
    echo "  create <alias> [budget] [days]  创建新 Key"
    echo "  list                            列出所有 Key"
    echo "  info <key>                      查看 Key 详情"
    echo "  revoke <key>                    撤销 Key"
    echo "  test <key>                      测试 Key"
    echo ""
    echo "示例:"
    echo "  $0 create customer-a 100 365"
    echo "  $0 list"
    echo "  $0 test sk-xxx"
}

case "$1" in
    create) create_key "$2" "$3" "$4" ;;
    list) list_keys ;;
    info) key_info "$2" ;;
    revoke) revoke_key "$2" ;;
    test) test_key "$2" ;;
    *) show_help ;;
esac
SCRIPT

chmod +x "$INSTALL_DIR/scripts/manage_keys.sh"
log_info "✓ Key 管理脚本已生成"

# 创建测试脚本
cat > "$INSTALL_DIR/scripts/test_gateway.sh" << 'SCRIPT'
#!/bin/bash

GATEWAY_URL="${GATEWAY_URL:-http://localhost:4000}"

echo "=== LiteLLM Gateway 测试 ==="
echo ""

echo "1. 健康检查..."
if curl -s -o /dev/null -w "%{http_code}" "$GATEWAY_URL/health" | grep -q "200\|401"; then
    echo "   ✓ 服务正常"
else
    echo "   ✗ 服务异常"
    exit 1
fi

if [ -n "$1" ]; then
    echo "2. 测试 API 调用..."
    curl -s "$GATEWAY_URL/v1/chat/completions" \
        -H "Authorization: Bearer $1" \
        -H "Content-Type: application/json" \
        -d '{"model":"gpt-4","messages":[{"role":"user","content":"说你好"}],"max_tokens":20}' | python3 -m json.tool 2>/dev/null || cat
fi

echo ""
echo "测试完成!"
SCRIPT

chmod +x "$INSTALL_DIR/scripts/test_gateway.sh"
log_info "✓ 测试脚本已生成"

# 提示用户配置 API Key
echo ""
log_warn "[4/7] 配置 API Key..."
echo ""
echo "请编辑 $INSTALL_DIR/.env 文件，填入你的 Coding Plan API Key:"
echo ""
echo "  ZHIPUAI_API_KEY=你的CodingPlan密钥"
echo ""
echo "获取方式:"
echo "  1. 访问 https://bigmodel.cn/"
echo "  2. 订阅 Coding Plan 套餐 (约 200 元/年)"
echo "  3. 获取 API Key"
echo ""

read -p "已配置好 API Key? 按 Enter 继续..."

# 启动服务
echo ""
log_warn "[5/7] 拉取镜像..."
cd "$INSTALL_DIR"
docker compose pull

log_warn "[6/7] 启动服务..."
docker compose up -d

log_warn "等待服务启动 (约 15 秒)..."
sleep 15

# 检查服务状态
echo ""
log_warn "[7/7] 检查服务状态..."

# 等待数据库初始化
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

# 创建示例 Key
echo ""
log_warn "创建示例客户 Key..."
EXAMPLE_KEY=$("$INSTALL_DIR/scripts/manage_keys.sh" create demo-customer 100 365 2>/dev/null | grep -o '"key": "[^"]*"' | head -1 | cut -d'"' -f4)

echo ""
log_info "========================================"
log_info "  部署完成!"
log_info "========================================"
echo ""
echo "📁 安装目录: $INSTALL_DIR"
echo "🔐 管理密钥: $MASTER_KEY"
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "📋 模型映射:"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  gpt-4          → GLM-4.7 (Coding Plan)"
echo "  gpt-4-turbo    → GLM-4.6 (Coding Plan)"
echo "  gpt-3.5-turbo  → GLM-4-Flash (免费)"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "📝 常用命令:"
echo "   查看日志:   cd $INSTALL_DIR && docker compose logs -f litellm"
echo "   重启服务:   cd $INSTALL_DIR && docker compose restart"
echo "   停止服务:   cd $INSTALL_DIR && docker compose down"
echo ""
echo "🔑 Key 管理:"
echo "   创建 Key:   $INSTALL_DIR/scripts/manage_keys.sh create <名称> <预算>"
echo "   列出 Key:   $INSTALL_DIR/scripts/manage_keys.sh list"
echo "   测试 Key:   $INSTALL_DIR/scripts/manage_keys.sh test <key>"
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "📖 客户使用方式 (OpenAI 兼容):"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "  from openai import OpenAI"
echo ""
echo "  client = OpenAI("
echo "      base_url='http://<服务器IP>/v1',"
echo "      api_key='<分发给客户的Key>'"
echo "  )"
echo ""
echo "  response = client.chat.completions.create("
echo "      model='gpt-4',  # 实际调用 GLM-4.7"
echo "      messages=[{'role': 'user', 'content': '你好'}]"
echo "  )"
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
log_warn "⚠️  请妥善保管管理密钥，不要泄露给客户!"
