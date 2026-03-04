#!/bin/bash
#
# LiteLLM Key 管理脚本
#

# 从 .env 读取配置
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
ENV_FILE="$SCRIPT_DIR/../.env"

if [ -f "$ENV_FILE" ]; then
    # 安全地读取环境变量
    LITELLM_MASTER_KEY=$(grep '^LITELLM_MASTER_KEY=' "$ENV_FILE" | cut -d'=' -f2-)
fi

GATEWAY_URL="${GATEWAY_URL:-http://localhost:4000}"

# 颜色
GREEN='\033[0;32m'
NC='\033[0m'

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
            \"models\": [\"gpt-4\", \"gpt-4-turbo\", \"gpt-3.5-turbo\"],
            \"max_budget\": $budget,
            \"duration\": \"${days}d\",
            \"key_alias\": \"$alias\"
        }" | python3 -m json.tool 2>/dev/null || cat
}

# 列出所有 Key
list_keys() {
    echo "所有 Key 列表:"
    curl -s "$GATEWAY_URL/key/info" \
        -H "Authorization: Bearer $LITELLM_MASTER_KEY" | python3 -m json.tool 2>/dev/null || cat
}

# 查看 Key 详情
key_info() {
    local key=$1
    curl -s "$GATEWAY_URL/key/info?key=$key" \
        -H "Authorization: Bearer $LITELLM_MASTER_KEY" | python3 -m json.tool 2>/dev/null || cat
}

# 撤销 Key
revoke_key() {
    local key=$1
    echo "撤销 Key: $key"
    curl -s -X POST "$GATEWAY_URL/key/delete" \
        -H "Authorization: Bearer $LITELLM_MASTER_KEY" \
        -H "Content-Type: application/json" \
        -d "{\"key\": \"$key\"}" | python3 -m json.tool 2>/dev/null || cat
}

# 测试 Key
test_key() {
    local key=$1
    echo "测试 Key: $key"
    curl -s "$GATEWAY_URL/v1/chat/completions" \
        -H "Authorization: Bearer $key" \
        -H "Content-Type: application/json" \
        -d '{"model":"gpt-4","messages":[{"role":"user","content":"say hi"}],"max_tokens":10}' | python3 -m json.tool 2>/dev/null || cat
}

# 帮助
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
    echo "  $0 create customer-a 100 365    # 创建预算\$100有效期365天的Key"
    echo "  $0 list                          # 列出所有Key"
    echo "  $0 test sk-xxx                   # 测试Key是否可用"
}

case "$1" in
    create) create_key "$2" "$3" "$4" ;;
    list) list_keys ;;
    info) key_info "$2" ;;
    revoke) revoke_key "$2" ;;
    test) test_key "$2" ;;
    *) show_help ;;
esac
