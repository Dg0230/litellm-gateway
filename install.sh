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
log_info "  支持三家 Coding Plan 提供商"
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
SALT_KEY=$(openssl rand -hex 16)

# 创建 .env 文件
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

# 创建 LiteLLM 配置 - 三家 Coding Plan 提供商
cat > "$INSTALL_DIR/config/litellm_config.yaml" << 'EOF'
# LiteLLM Gateway 配置
# 文档: https://docs.litellm.ai/docs/

model_list:
  # ===========================================
  # 阿里云 Coding Plan
  # API: https://coding.dashscope.aliyuncs.com/v1
  # 支持模型: qwen3.5-plus, qwen3-max-2026-01-23
  #           qwen3-coder-next, qwen3-coder-plus
  #           kimi-k2.5, MiniMax-M2.5, glm-5, glm-4.7
  # ===========================================

  - model_name: qwen3.5-plus
    litellm_params:
      model: openai/qwen3.5-plus
      api_key: "os.environ/ALIYUN_API_KEY"
      api_base: "https://coding.dashscope.aliyuncs.com/v1"

  - model_name: qwen3-max-2026-01-23
    litellm_params:
      model: openai/qwen3-max-2026-01-23
      api_key: "os.environ/ALIYUN_API_KEY"
      api_base: "https://coding.dashscope.aliyuncs.com/v1"

  - model_name: qwen3-coder-next
    litellm_params:
      model: openai/qwen3-coder-next
      api_key: "os.environ/ALIYUN_API_KEY"
      api_base: "https://coding.dashscope.aliyuncs.com/v1"

  - model_name: qwen3-coder-plus
    litellm_params:
      model: openai/qwen3-coder-plus
      api_key: "os.environ/ALIYUN_API_KEY"
      api_base: "https://coding.dashscope.aliyuncs.com/v1"

  - model_name: kimi-k2.5
    litellm_params:
      model: openai/kimi-k2.5
      api_key: "os.environ/ALIYUN_API_KEY"
      api_base: "https://coding.dashscope.aliyuncs.com/v1"

  - model_name: MiniMax-M2.5
    litellm_params:
      model: openai/MiniMax-M2.5
      api_key: "os.environ/ALIYUN_API_KEY"
      api_base: "https://coding.dashscope.aliyuncs.com/v1"

  - model_name: glm-5
    litellm_params:
      model: openai/glm-5
      api_key: "os.environ/ALIYUN_API_KEY"
      api_base: "https://coding.dashscope.aliyuncs.com/v1"

  - model_name: glm-4.7
    litellm_params:
      model: openai/glm-4.7
      api_key: "os.environ/ALIYUN_API_KEY"
      api_base: "https://coding.dashscope.aliyuncs.com/v1"

  # ===========================================
  # 火山引擎 Coding Plan
  # API: https://ark.cn-beijing.volces.com/api/coding/v1
  # 支持模型: doubao-seed-2.0-lite, doubao-seed-2.0-pro
  #           doubao-seed-2.0-code-preview, doubao-seed-2.0-mini
  #           deepseek-v3-2-251201, kimi-k2.5
  #           glm-4.7, MiniMax-M2.5
  # ===========================================

  - model_name: doubao-seed-2.0-lite
    litellm_params:
      model: openai/doubao-seed-2.0-lite
      api_key: "os.environ/VOLCENGINE_API_KEY"
      api_base: "https://ark.cn-beijing.volces.com/api/coding/v1"

  - model_name: doubao-seed-2.0-pro
    litellm_params:
      model: openai/doubao-seed-2.0-pro
      api_key: "os.environ/VOLCENGINE_API_KEY"
      api_base: "https://ark.cn-beijing.volces.com/api/coding/v1"

  - model_name: doubao-seed-2.0-code-preview
    litellm_params:
      model: openai/doubao-seed-2.0-code-preview
      api_key: "os.environ/VOLCENGINE_API_KEY"
      api_base: "https://ark.cn-beijing.volces.com/api/coding/v1"

  - model_name: doubao-seed-2.0-mini
    litellm_params:
      model: openai/doubao-seed-2.0-mini
      api_key: "os.environ/VOLCENGINE_API_KEY"
      api_base: "https://ark.cn-beijing.volces.com/api/coding/v1"

  - model_name: deepseek-v3-2-251201
    litellm_params:
      model: openai/deepseek-v3-2-251201
      api_key: "os.environ/VOLCENGINE_API_KEY"
      api_base: "https://ark.cn-beijing.volces.com/api/coding/v1"

  - model_name: kimi-k2.5
    litellm_params:
      model: openai/kimi-k2.5
      api_key: "os.environ/VOLCENGINE_API_KEY"
      api_base: "https://ark.cn-beijing.volces.com/api/coding/v1"

  - model_name: glm-4.7
    litellm_params:
      model: openai/glm-4.7
      api_key: "os.environ/VOLCENGINE_API_KEY"
      api_base: "https://ark.cn-beijing.volces.com/api/coding/v1"

  - model_name: MiniMax-M2.5
    litellm_params:
      model: openai/MiniMax-M2.5
      api_key: "os.environ/VOLCENGINE_API_KEY"
      api_base: "https://ark.cn-beijing.volces.com/api/coding/v1"

  # ===========================================
  # 智谱官方 Coding Plan
  # API: https://open.bigmodel.cn/api/coding/paas/v4
  # 支持模型: glm-4.5, glm-4.5-air, glm-4.6, glm-4.7, glm-5
  # ===========================================

  - model_name: glm-4.5
    litellm_params:
      model: openai/glm-4.5
      api_key: "os.environ/ZHIPUAI_API_KEY"
      api_base: "https://open.bigmodel.cn/api/coding/paas/v4"

  - model_name: glm-4.5-air
    litellm_params:
      model: openai/glm-4.5-air
      api_key: "os.environ/ZHIPUAI_API_KEY"
      api_base: "https://open.bigmodel.cn/api/coding/paas/v4"

  - model_name: glm-4.6
    litellm_params:
      model: openai/glm-4.6
      api_key: "os.environ/ZHIPUAI_API_KEY"
      api_base: "https://open.bigmodel.cn/api/coding/paas/v4"

  - model_name: glm-4.7
    litellm_params:
      model: openai/glm-4.7
      api_key: "os.environ/ZHIPUAI_API_KEY"
      api_base: "https://open.bigmodel.cn/api/coding/paas/v4"

  - model_name: glm-5
    litellm_params:
      model: openai/glm-5
      api_key: "os.environ/ZHIPUAI_API_KEY"
      api_base: "https://open.bigmodel.cn/api/coding/paas/v4"

router_settings:
  routing_strategy: "simple-shuffle"
  num_retries: 3
  timeout: 120
  retry_after: 1
  model_group_retry_policy_fallback: true

general_settings:
  master_key: "os.environ/LITELLM_MASTER_KEY"
  database_url: "os.environ/DATABASE_URL"
  litellm_salt_key: "os.environ/LITELLM_SALT_KEY"

litellm_settings:
  max_tokens: 8192
  drop_params: true
  set_verbose: false
EOF

log_info "✓ LiteLLM 配置已生成 (三家 Coding Plan 提供商)"

# 创建 Nginx 配置
cat > "$INSTALL_DIR/config/nginx.conf" << 'EOF'
events {
    worker_connections 1024;
}

http {
    # 访问日志
    log_format main '$remote_addr - $remote_user [$time_local] "$request" '
                    '$status $body_bytes_sent "$http_referer" '
                    '"$http_user_agent" - $request_time';
    access_log /var/log/nginx/access.log main;

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
      POSTGRES_PASSWORD: ${DB_PASSWORD:-litellm_db_password}
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

# 颜色
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

# 所有可用模型 (必须与 litellm_config.yaml 中的 model_name 一致)
ALL_MODELS='["qwen3.5-plus", "qwen3-max-2026-01-23", "qwen3-coder-next", "qwen3-coder-plus", "kimi-k2.5", "MiniMax-M2.5", "glm-5", "glm-4.7", "doubao-seed-2.0-lite", "doubao-seed-2.0-pro", "doubao-seed-2.0-code-preview", "doubao-seed-2.0-mini", "deepseek-v3-2-251201", "glm-4.5", "glm-4.5-air", "glm-4.6"]'

# 创建 Key
create_key() {
    local alias=$1
    local budget=${2:-100}
    local days=${3:-365}

    if [ -z "$alias" ]; then
        echo "用法: $0 create <alias> [budget] [days]"
        exit 1
    fi

    printf "${GREEN}创建 Key: $alias (预算: \$$budget, 有效期: ${days}天)${NC}\n"

    curl -s -X POST "$GATEWAY_URL/key/generate" \
        -H "Authorization: Bearer $LITELLM_MASTER_KEY" \
        -H "Content-Type: application/json" \
        -d "{
            \"models\": $ALL_MODELS,
            \"max_budget\": $budget,
            \"duration\": \"${days}d\",
            \"key_alias\": \"$alias\"
        }" | python3 -m json.tool 2>/dev/null || cat
}

# 列出所有 Key (通过数据库查询，LiteLLM API 不支持列出所有)
list_keys() {
    printf "${GREEN}所有 Key 列表:${NC}\n"
    # 直接查询 PostgreSQL 数据库
    docker exec litellm-db psql -U litellm -d litellm -c "
        SELECT
            key_alias AS \"别名\",
            LEFT(token, 20) || '...' AS \"Key前缀\",
            max_budget AS \"预算\",
            ROUND(spend::numeric, 2) AS \"已用\",
            CASE WHEN expires IS NULL THEN '永久'
                 ELSE TO_CHAR(expires, 'YYYY-MM-DD')
            END AS \"过期时间\",
            CASE WHEN blocked = true THEN '已禁用' ELSE '正常' END AS \"状态\"
        FROM \"LiteLLM_VerificationToken\"
        ORDER BY created_at DESC;
    " 2>/dev/null || echo "无法连接数据库，请确保容器运行中"
}

key_info() {
    local key=$1
    if [ -z "$key" ]; then
        echo "用法: $0 info <key>"
        exit 1
    fi
    curl -s "$GATEWAY_URL/key/info?key=$key" \
        -H "Authorization: Bearer $LITELLM_MASTER_KEY" | python3 -m json.tool 2>/dev/null || cat
}

# 按 alias 查找 Key
find_key() {
    local alias=$1
    if [ -z "$alias" ]; then
        echo "用法: $0 find <alias>"
        exit 1
    fi
    curl -s "$GATEWAY_URL/key/info?key_alias=$alias" \
        -H "Authorization: Bearer $LITELLM_MASTER_KEY" | python3 -m json.tool 2>/dev/null || cat
}

revoke_key() {
    local key=$1
    if [ -z "$key" ]; then
        echo "用法: $0 revoke <key>"
        exit 1
    fi
    printf "${YELLOW}撤销 Key: $key${NC}\n"
    curl -s -X POST "$GATEWAY_URL/key/delete" \
        -H "Authorization: Bearer $LITELLM_MASTER_KEY" \
        -H "Content-Type: application/json" \
        -d "{\"key\": \"$key\"}" | python3 -m json.tool 2>/dev/null || cat
}

test_key() {
    local key=$1
    if [ -z "$key" ]; then
        echo "用法: $0 test <key>"
        exit 1
    fi
    printf "${GREEN}测试 Key: $key${NC}\n"
    curl -s "$GATEWAY_URL/v1/chat/completions" \
        -H "Authorization: Bearer $key" \
        -H "Content-Type: application/json" \
        -d '{"model":"gpt-4o","messages":[{"role":"user","content":"说你好"}],"max_tokens":20}' | python3 -m json.tool 2>/dev/null || cat
}

show_help() {
    echo "LiteLLM Key 管理脚本"
    echo ""
    echo "用法: $0 <command> [args]"
    echo ""
    echo "命令:"
    echo "  create <alias> [budget] [days]  创建新 Key (全模型权限)"
    echo "  list                            列出所有 Key"
    echo "  info <key>                      查看 Key 详情"
    echo "  find <alias>                    按 alias 查找 Key"
    echo "  revoke <key>                    撤销 Key"
    echo "  test <key>                      测试 Key"
    echo ""
    echo "示例:"
    echo "  $0 create customer-a 100 365    # 创建预算\$100有效期365天的Key"
    echo "  $0 list                          # 列出所有Key"
    echo "  $0 find test1                    # 查找 alias 为 test1 的 Key"
    echo "  $0 test sk-xxx                   # 测试Key是否可用"
}

case "$1" in
    create) create_key "$2" "$3" "$4" ;;
    list) list_keys ;;
    info) key_info "$2" ;;
    find) find_key "$2" ;;
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
        -d '{"model":"qwen3.5-plus","messages":[{"role":"user","content":"说你好"}],"max_tokens":20}' | python3 -m json.tool 2>/dev/null || cat
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
echo "  阿里云:     ALIYUN_API_KEY=你的密钥"
echo "  火山引擎:   VOLCENGINE_API_KEY=你的密钥"
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
echo "📋 可用模型 (16个，支持负载均衡):"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  阿里云: qwen3.5-plus, qwen3-max, qwen3-coder-*"
echo "          kimi-k2.5, MiniMax-M2.5, glm-5/4.7"
echo "  火山引擎: doubao-seed-*, deepseek-v3-2"
echo "            kimi-k2.5, MiniMax-M2.5, glm-4.7"
echo "  智谱官方: glm-4.5, glm-4.5-air, glm-4.6"
echo "            glm-4.7, glm-5"
echo ""
echo "  负载均衡: glm-4.7(3供应商), glm-5(2供应商)"
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
echo "      model='qwen3.5-plus',  # 或其他模型"
echo "      messages=[{'role': 'user', 'content': '你好'}]"
echo "  )"
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
log_warn "⚠️  请妥善保管管理密钥，不要泄露给客户!"
