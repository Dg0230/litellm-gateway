#!/bin/bash
#
# LiteLLM Key 管理脚本 (交互式)
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

# 所有可用模型 (分类)
declare -A MODEL_GROUPS
MODEL_GROUPS["阿里云"]="qwen3.5-plus qwen3-max-2026-01-23 qwen3-coder-next qwen3-coder-plus"
MODEL_GROUPS["阿里云"]+=" kimi-k2.5 MiniMax-M2.5 glm-5 glm-4.7"
MODEL_GROUPS["火山引擎-聊天"]="doubao-seed-2.0-lite doubao-seed-2.0-pro doubao-seed-2.0-code-preview doubao-seed-2.0-mini"
MODEL_GROUPS["火山引擎-聊天"]+=" deepseek-v3-2-251201 kimi-k2.5 glm-4.7 MiniMax-M2.5"
MODEL_GROUPS["火山引擎-视觉"]="doubao-seed-2-0-pro-vision doubao-seed-2-0-lite-vision doubao-seedream-4-5"
MODEL_GROUPS["智谱官方"]="glm-4.5 glm-4.5-air glm-4.6 glm-4.7 glm-5"

# 所有模型列表
ALL_MODELS=(
    "qwen3.5-plus" "qwen3-max-2026-01-23" "qwen3-coder-next" "qwen3-coder-plus"
    "kimi-k2.5" "MiniMax-M2.5" "glm-5" "glm-4.7"
    "doubao-seed-2.0-lite" "doubao-seed-2.0-pro" "doubao-seed-2.0-code-preview" "doubao-seed-2.0-mini"
    "deepseek-v3-2-251201"
    "doubao-seed-2-0-pro-vision" "doubao-seed-2-0-lite-vision" "doubao-seedream-4-5"
    "glm-4.5" "glm-4.5-air" "glm-4.6"
)

# 交互式选择模型
select_models() {
    local selected_models=()
    local all_selected=false

    echo ""
    printf "${BLUE}════════════════════════════════════════${NC}\n"
    printf "${BLUE}        模型选择 (空格多选, 回车确认)       ${NC}\n"
    printf "${BLUE}════════════════════════════════════════${NC}\n"

    echo ""
    printf "${GREEN}[0] 全部模型 (19个)${NC}\n"
    echo ""

    local idx=1
    for group in "${!MODEL_GROUPS[@]}"; do
        printf "${YELLOW}── $group ──${NC}\n"
        for model in ${MODEL_GROUPS[$group]}; do
            printf "  [%2d] %s\n" $idx "$model"
            ((idx++))
        done
        echo ""
    done

    printf "${BLUE}请输入模型编号 (多个用空格分隔, 0=全部): ${NC}"
    read -r choices

    # 解析选择
    for choice in $choices; do
        if [ "$choice" == "0" ]; then
            all_selected=true
            break
        fi
        if [[ "$choice" =~ ^[0-9]+$ ]] && [ "$choice" -ge 1 ] && [ "$choice" -le ${#ALL_MODELS[@]} ]; then
            selected_models+=("${ALL_MODELS[$((choice-1))]}")
        fi
    done

    if [ "$all_selected" = true ]; then
        echo "["
        echo "  \"qwen3.5-plus\", \"qwen3-max-2026-01-23\", \"qwen3-coder-next\", \"qwen3-coder-plus\","
        echo "  \"kimi-k2.5\", \"MiniMax-M2.5\", \"glm-5\", \"glm-4.7\","
        echo "  \"doubao-seed-2.0-lite\", \"doubao-seed-2.0-pro\", \"doubao-seed-2.0-code-preview\", \"doubao-seed-2.0-mini\","
        echo "  \"deepseek-v3-2-251201\", \"glm-4.5\", \"glm-4.5-air\", \"glm-4.6\","
        echo "  \"doubao-seed-2-0-pro-vision\", \"doubao-seed-2-0-lite-vision\", \"doubao-seedream-4-5\""
        echo "]"
        return
    fi

    if [ ${#selected_models[@]} -eq 0 ]; then
        printf "${RED}未选择任何模型，使用全部模型${NC}\n"
        echo "[\"all\"]"
        return
    fi

    # 输出 JSON 数组
    echo -n "["
    local first=true
    for model in "${selected_models[@]}"; do
        if [ "$first" = true ]; then
            first=false
        else
            echo -n ", "
        fi
        echo -n "\"$model\""
    done
    echo "]"
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
    printf "  预算: \$$budget\n"
    printf "  有效期: ${days}天\n"
    printf "  模型: %s\n" "$(echo "$models_json" | tr '\n' ' ' | head -c 80)..."
    echo ""
    printf "${YELLOW}确认创建? [Y/n]: ${NC}"
    read -r confirm
    if [ "$confirm" == "n" ] || [ "$confirm" == "N" ]; then
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

    printf "${GREEN}创建 Key: $alias (预算: \$$budget, 有效期: ${days}天, 全模型)${NC}\n"

    local models_json='["qwen3.5-plus", "qwen3-max-2026-01-23", "qwen3-coder-next", "qwen3-coder-plus", "kimi-k2.5", "MiniMax-M2.5", "glm-5", "glm-4.7", "doubao-seed-2.0-lite", "doubao-seed-2.0-pro", "doubao-seed-2.0-code-preview", "doubao-seed-2.0-mini", "deepseek-v3-2-251201", "glm-4.5", "glm-4.5-air", "glm-4.6", "doubao-seed-2-0-pro-vision", "doubao-seed-2-0-lite-vision", "doubao-seedream-4-5"]'

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
