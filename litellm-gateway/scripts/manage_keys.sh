#!/bin/bash
#
# LiteLLM Key 管理脚本 (交互式)
# 兼容 macOS 旧版 bash
#

# 从 .env 读取配置
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
BLUE='\033[0;34m'
NC='\033[0m'

# 所有模型列表 (编号:名称)
MODELS=(
    "1:qwen3.5-plus"
    "2:qwen3-max-2026-01-23"
    "3:qwen3-coder-next"
    "4:qwen3-coder-plus"
    "5:kimi-k2.5"
    "6:MiniMax-M2.5"
    "7:glm-5"
    "8:glm-4.7"
    "9:doubao-seed-2.0-lite"
    "10:doubao-seed-2.0-pro"
    "11:doubao-seed-2.0-code-preview"
    "12:doubao-seed-2.0-mini"
    "13:deepseek-v3-2-251201"
    "14:glm-4.5"
    "15:glm-4.5-air"
    "16:glm-4.6"
    "17:doubao-seed-2-0-pro-vision"
    "18:doubao-seed-2-0-lite-vision"
    "19:doubao-seedream-4-5"
)

# 显示模型选择菜单
show_model_menu() {
    echo ""
    printf "${BLUE}════════════════════════════════════════${NC}\n"
    printf "${BLUE}        模型选择 (空格多选, 回车确认)       ${NC}\n"
    printf "${BLUE}════════════════════════════════════════${NC}\n"
    echo ""
    printf "${GREEN}[0] 全部模型 (19个)${NC}\n"
    echo ""
    printf "${YELLOW}── 阿里云 ──${NC}\n"
    printf "  [ 1] qwen3.5-plus\n"
    printf "  [ 2] qwen3-max-2026-01-23\n"
    printf "  [ 3] qwen3-coder-next\n"
    printf "  [ 4] qwen3-coder-plus\n"
    printf "  [ 5] kimi-k2.5\n"
    printf "  [ 6] MiniMax-M2.5\n"
    printf "  [ 7] glm-5\n"
    printf "  [ 8] glm-4.7\n"
    echo ""
    printf "${YELLOW}── 火山引擎-聊天 ──${NC}\n"
    printf "  [ 9] doubao-seed-2.0-lite\n"
    printf "  [10] doubao-seed-2.0-pro\n"
    printf "  [11] doubao-seed-2.0-code-preview\n"
    printf "  [12] doubao-seed-2.0-mini\n"
    printf "  [13] deepseek-v3-2-251201\n"
    echo ""
    printf "${YELLOW}── 火山引擎-视觉 ──${NC}\n"
    printf "  [17] doubao-seed-2-0-pro-vision\n"
    printf "  [18] doubao-seed-2-0-lite-vision\n"
    printf "  [19] doubao-seedream-4-5\n"
    echo ""
    printf "${YELLOW}── 智谱官方 ──${NC}\n"
    printf "  [14] glm-4.5\n"
    printf "  [15] glm-4.5-air\n"
    printf "  [16] glm-4.6\n"
    printf "  [ 8] glm-4.7 (负载均衡)\n"
    printf "  [ 7] glm-5 (负载均衡)\n"
    echo ""
}

# 根据编号获取模型名
get_model_by_id() {
    local id=$1
    for entry in "${MODELS[@]}"; do
        local num="${entry%%:*}"
        local name="${entry#*:}"
        if [ "$num" = "$id" ]; then
            echo "$name"
            return
        fi
    done
    echo ""
}

# 交互式选择模型
select_models() {
    show_model_menu

    printf "${BLUE}请输入模型编号 (多个用空格分隔, 0=全部): ${NC}"
    read -r choices

    # 检查是否选择全部
    for choice in $choices; do
        if [ "$choice" = "0" ]; then
            echo '["qwen3.5-plus","qwen3-max-2026-01-23","qwen3-coder-next","qwen3-coder-plus","kimi-k2.5","MiniMax-M2.5","glm-5","glm-4.7","doubao-seed-2.0-lite","doubao-seed-2.0-pro","doubao-seed-2.0-code-preview","doubao-seed-2.0-mini","deepseek-v3-2-251201","glm-4.5","glm-4.5-air","glm-4.6","doubao-seed-2-0-pro-vision","doubao-seed-2-0-lite-vision","doubao-seedream-4-5"]'
            return
        fi
    done

    # 构建选择的模型列表
    local models_json="["
    local first=true
    for choice in $choices; do
        local model
        model=$(get_model_by_id "$choice")
        if [ -n "$model" ]; then
            if [ "$first" = true ]; then
                first=false
            else
                models_json="$models_json,"
            fi
            models_json="$models_json\"$model\""
        fi
    done
    models_json="$models_json]"

    if [ "$models_json" = "[]" ]; then
        printf "${RED}未选择任何模型，使用全部模型${NC}\n"
        echo '["all"]'
        return
    fi

    echo "$models_json"
}

# 创建 Key (交互式)
create_key_interactive() {
    local alias=$1
    local budget=${2:-100}
    local days=${3:-365}

    if [ -z "$alias" ]; then
        printf "${BLUE}请输入 Key 别名: ${NC}"
        read -r alias
        if [ -z "$alias" ]; then
            printf "${RED}错误: 别名不能为空${NC}\n"
            exit 1
        fi
    fi

    # 选择模型
    local models_json
    models_json=$(select_models)

    printf "\n${GREEN}创建 Key: $alias${NC}\n"
    printf "  预算: \$%s\n" "$budget"
    printf "  有效期: %s天\n" "$days"
    printf "  模型: %s\n" "$(echo "$models_json" | tr -d '\n' | head -c 100)..."
    echo ""
    printf "${YELLOW}确认创建? [Y/n]: ${NC}"
    read -r confirm
    if [ "$confirm" = "n" ] || [ "$confirm" = "N" ]; then
        printf "${RED}已取消${NC}\n"
        exit 0
    fi

    curl -s -X POST "$GATEWAY_URL/key/generate" \
        -H "Authorization: Bearer $LITELLM_MASTER_KEY" \
        -H "Content-Type: application/json" \
        -d "{
            \"models\": $models_json,
            \"max_budget\": $budget,
            \"duration\": \"${days}d\",
            \"key_alias\": \"$alias\"
        }" | python3 -m json.tool 2>/dev/null || cat
}

# 创建 Key (快速模式，全模型)
create_key() {
    local alias=$1
    local budget=${2:-100}
    local days=${3:-365}

    if [ -z "$alias" ]; then
        echo "用法: $0 create <alias> [budget] [days]"
        echo "      $0 create-interactive    # 交互式选择模型"
        exit 1
    fi

    printf "${GREEN}创建 Key: $alias (预算: \$%s, 有效期: %s天, 全模型)${NC}\n" "$budget" "$days"

    local models_json='["qwen3.5-plus","qwen3-max-2026-01-23","qwen3-coder-next","qwen3-coder-plus","kimi-k2.5","MiniMax-M2.5","glm-5","glm-4.7","doubao-seed-2.0-lite","doubao-seed-2.0-pro","doubao-seed-2.0-code-preview","doubao-seed-2.0-mini","deepseek-v3-2-251201","glm-4.5","glm-4.5-air","glm-4.6","doubao-seed-2-0-pro-vision","doubao-seed-2-0-lite-vision","doubao-seedream-4-5"]'

    curl -s -X POST "$GATEWAY_URL/key/generate" \
        -H "Authorization: Bearer $LITELLM_MASTER_KEY" \
        -H "Content-Type: application/json" \
        -d "{
            \"models\": $models_json,
            \"max_budget\": $budget,
            \"duration\": \"${days}d\",
            \"key_alias\": \"$alias\"
        }" | python3 -m json.tool 2>/dev/null || cat
}

# 列出所有 Key
list_keys() {
    printf "${GREEN}所有 Key 列表:${NC}\n"
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
        WHERE key_alias IS NOT NULL
        ORDER BY created_at DESC;
    " 2>/dev/null || echo "无法连接数据库，请确保容器运行中"
}

# 查看 Key 详情
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

# 撤销 Key
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
        -d "{\"keys\": [\"$key\"]}" | python3 -m json.tool 2>/dev/null || cat
}

# 测试 Key
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
        -d '{"model":"qwen3.5-plus","messages":[{"role":"user","content":"说你好"}],"max_tokens":20}' | python3 -m json.tool 2>/dev/null || cat
}

# 帮助
show_help() {
    echo "LiteLLM Key 管理脚本 (交互式)"
    echo ""
    echo "用法: $0 <command> [args]"
    echo ""
    echo "命令:"
    echo "  create <alias> [budget] [days]  创建新 Key (全模型权限)"
    echo "  create-interactive              交互式创建 Key (选择模型)"
    echo "  list                            列出所有 Key"
    echo "  info <key>                      查看 Key 详情"
    echo "  find <alias>                    按 alias 查找 Key"
    echo "  revoke <key>                    撤销 Key"
    echo "  test <key>                      测试 Key"
    echo ""
    echo "示例:"
    echo "  $0 create-interactive           # 交互式选择模型创建Key"
    echo "  $0 create customer-a 100 365    # 快速创建全模型Key"
    echo "  $0 list                          # 列出所有Key"
    echo "  $0 test sk-xxx                   # 测试Key是否可用"
}

case "$1" in
    create) create_key "$2" "$3" "$4" ;;
    create-interactive|i) create_key_interactive "$2" "$3" "$4" ;;
    list) list_keys ;;
    info) key_info "$2" ;;
    find) find_key "$2" ;;
    revoke) revoke_key "$2" ;;
    test) test_key "$2" ;;
    *) show_help ;;
esac
