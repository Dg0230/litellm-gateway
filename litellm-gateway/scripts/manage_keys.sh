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

# Key 存储文件
KEYS_FILE="$SCRIPT_DIR/.saved_keys"

# 颜色
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m'

# 所有模型
ALL_MODELS='["qwen3.5-plus","qwen3-max-2026-01-23","qwen3-coder-next","qwen3-coder-plus","kimi-k2.5","MiniMax-M2.5","glm-5","glm-4.7","doubao-seed-2.0-lite","doubao-seed-2.0-pro","doubao-seed-2.0-code-preview","doubao-seed-2.0-mini","deepseek-v3-2-251201","glm-4.5","glm-4.5-air","glm-4.6","doubao-seed-2-0-pro-vision","doubao-seed-2-0-lite-vision","doubao-seedream-4-5"]'

# 保存 key 到文件
save_key() {
    local alias=$1
    local key=$2
    local budget=$3
    local days=$4
    local created_at=$(date '+%Y-%m-%d %H:%M:%S')
    echo "$alias|$key|$budget|$days|$created_at" >> "$KEYS_FILE"
    chmod 600 "$KEYS_FILE" 2>/dev/null
}

# 显示模型选择菜单 (输出到 stderr)
show_model_menu() {
    # 强制输出到终端，避免缓冲问题
    exec 2>&2  # 确保 stderr 未被重定向
    cat >&2 << 'MENU'

    ══════════════════════════════════════
    [0] 全部模型 (19个)

    ── 阿里云 ──
      [ 1] qwen3.5-plus
      [ 2] qwen3-max-2026-01-23
      [ 3] qwen3-coder-next
      [ 4] qwen3-coder-plus
      [ 5] kimi-k2.5
      [ 6] MiniMax-M2.5
      [ 7] glm-5
      [ 8] glm-4.7

    ── 火山引擎-聊天 ──
      [ 9] doubao-seed-2.0-lite
      [10] doubao-seed-2.0-pro
      [11] doubao-seed-2.0-code-preview
      [12] doubao-seed-2.0-mini
      [13] deepseek-v3-2-251201

    ── 火山引擎-视觉 ──
      [14] doubao-seed-2-0-pro-vision
      [15] doubao-seed-2-0-lite-vision
      [16] doubao-seedream-4-5

    ── 智谱官方 ──
      [17] glm-4.5
      [18] glm-4.5-air
      [19] glm-4.6

MENU
}

# 根据编号获取模型名
get_model_by_id() {
    case "$1" in
        1)  echo "qwen3.5-plus" ;;
        2)  echo "qwen3-max-2026-01-23" ;;
        3)  echo "qwen3-coder-next" ;;
        4)  echo "qwen3-coder-plus" ;;
        5)  echo "kimi-k2.5" ;;
        6)  echo "MiniMax-M2.5" ;;
        7)  echo "glm-5" ;;
        8)  echo "glm-4.7" ;;
        9)  echo "doubao-seed-2.0-lite" ;;
        10) echo "doubao-seed-2.0-pro" ;;
        11) echo "doubao-seed-2.0-code-preview" ;;
        12) echo "doubao-seed-2.0-mini" ;;
        13) echo "deepseek-v3-2-251201" ;;
        14) echo "doubao-seed-2-0-pro-vision" ;;
        15) echo "doubao-seed-2-0-lite-vision" ;;
        16) echo "doubao-seedream-4-5" ;;
        17) echo "glm-4.5" ;;
        18) echo "glm-4.5-air" ;;
        19) echo "glm-4.6" ;;
    esac
}

# 交互式选择模型 (结果存入 SELECTED_MODELS 全局变量)
SELECTED_MODELS=""
select_models() {
    show_model_menu

    printf "${BLUE}请输入模型编号 (多个用空格分隔, 0=全部): ${NC}"
    read -r choices

    # 检查是否选择全部
    for choice in $choices; do
        if [ "$choice" = "0" ]; then
            SELECTED_MODELS="$ALL_MODELS"
            return
        fi
    done

    # 构建选择的模型列表
    local models_json="["
    local first=1
    for choice in $choices; do
        local model
        model=$(get_model_by_id "$choice")
        if [ -n "$model" ]; then
            if [ "$first" = "1" ]; then
                first=0
            else
                models_json="$models_json,"
            fi
            models_json="$models_json\"$model\""
        fi
    done
    models_json="$models_json]"

    if [ "$models_json" = "[]" ]; then
        printf "${RED}未选择任何模型，使用全部模型${NC}\n" >&2
        SELECTED_MODELS="$ALL_MODELS"
        return
    fi

    SELECTED_MODELS="$models_json"
}

# 创建 Key (交互式)
create_key_interactive() {
    local alias=$1
    local budget=$2
    local days=$3

    # 输入别名
    if [ -z "$alias" ]; then
        printf "${BLUE}请输入 Key 别名: ${NC}"
        read -r alias
        [ -z "$alias" ] && printf "${RED}错误: 别名不能为空${NC}\n" && exit 1
    fi

    # 选择模型 (结果存入全局变量 SELECTED_MODELS)
    select_models

    # 输入预算
    if [ -z "$budget" ]; then
        printf "${BLUE}请输入预算 (美元, 默认100): ${NC}"
        read -r budget
        [ -z "$budget" ] && budget=100
    fi

    # 输入有效期
    if [ -z "$days" ]; then
        printf "${BLUE}请输入有效期 (天, 默认365): ${NC}"
        read -r days
        [ -z "$days" ] && days=365
    fi

    printf "\n${GREEN}创建 Key: $alias${NC}\n"
    printf "  预算: \$%s\n" "$budget"
    printf "  有效期: %s天\n" "$days"
    printf "${YELLOW}确认创建? [Y/n]: ${NC}"
    read -r confirm
    if [ "$confirm" = "n" ] || [ "$confirm" = "N" ]; then
        printf "${RED}已取消${NC}\n"
        exit 0
    fi

    local response
    response=$(curl -s -X POST "$GATEWAY_URL/key/generate" \
        -H "Authorization: Bearer $LITELLM_MASTER_KEY" \
        -H "Content-Type: application/json" \
        -d "{
            \"models\": $SELECTED_MODELS,
            \"max_budget\": $budget,
            \"duration\": \"${days}d\",
            \"key_alias\": \"$alias\"
        }")

    echo "$response" | python3 -m json.tool 2>/dev/null || echo "$response"

    # 提取 key 并保存
    local key
    key=$(echo "$response" | python3 -c "import sys,json; print(json.load(sys.stdin).get('key',''))" 2>/dev/null)
    if [ -n "$key" ]; then
        save_key "$alias" "$key" "$budget" "$days"
        printf "\n${GREEN}Key 已保存到: $KEYS_FILE${NC}\n"
    fi
}

# 创建 Key (快速模式，全模型)
create_key() {
    local alias=$1
    local budget=${2:-100}
    local days=${3:-365}

    [ -z "$alias" ] && echo "用法: $0 create <alias> [budget] [days]" && exit 1

    printf "${GREEN}创建 Key: $alias (全模型, 预算: \$%s, %s天)${NC}\n" "$budget" "$days"

    local response
    response=$(curl -s -X POST "$GATEWAY_URL/key/generate" \
        -H "Authorization: Bearer $LITELLM_MASTER_KEY" \
        -H "Content-Type: application/json" \
        -d "{\"models\":$ALL_MODELS,\"max_budget\":$budget,\"duration\":\"${days}d\",\"key_alias\":\"$alias\"}")

    echo "$response" | python3 -m json.tool 2>/dev/null || echo "$response"

    # 提取 key 并保存
    local key
    key=$(echo "$response" | python3 -c "import sys,json; print(json.load(sys.stdin).get('key',''))" 2>/dev/null)
    if [ -n "$key" ]; then
        save_key "$alias" "$key" "$budget" "$days"
        printf "\n${GREEN}Key 已保存到: $KEYS_FILE${NC}\n"
    fi
}

list_keys() {
    printf "${GREEN}所有 Key 列表:${NC}\n\n"
    docker exec litellm-db psql -U litellm -d litellm -c "SELECT key_alias AS \"别名\", max_budget AS \"预算\", ROUND(spend::numeric, 2) AS \"已用\", CASE WHEN expires IS NULL THEN '永久' ELSE TO_CHAR(expires, 'YYYY-MM-DD') END AS \"过期\", CASE WHEN blocked = true THEN '已禁用' ELSE '正常' END AS \"状态\" FROM \"LiteLLM_VerificationToken\" WHERE key_alias IS NOT NULL ORDER BY created_at DESC" 2>/dev/null || echo "无法连接数据库"
    printf "\n${BLUE}提示: 使用 alias (别名) 操作 info/revoke/test 命令${NC}\n"
}

# 通过 alias 获取 token (从数据库)
get_token_by_alias() {
    local alias=$1
    docker exec litellm-db psql -U litellm -d litellm -t -c "SELECT token FROM \"LiteLLM_VerificationToken\" WHERE key_alias = '$alias' LIMIT 1" 2>/dev/null | tr -d ' \n'
}

key_info() {
    [ -z "$1" ] && echo "用法: $0 info <alias>" && exit 1
    local alias=$1
    printf "${GREEN}Key 详情: $alias${NC}\n\n"
    docker exec litellm-db psql -U litellm -d litellm -c "SELECT key_alias AS \"别名\", token AS \"Token\", max_budget AS \"预算\", ROUND(spend::numeric, 2) AS \"已用\", CASE WHEN expires IS NULL THEN '永久' ELSE TO_CHAR(expires, 'YYYY-MM-DD HH24:MI') END AS \"过期时间\", CASE WHEN blocked = true THEN '已禁用' ELSE '正常' END AS \"状态\", array_to_string(models, ', ') AS \"可用模型\" FROM \"LiteLLM_VerificationToken\" WHERE key_alias = '$alias'" 2>/dev/null || echo "未找到 alias: $alias"
}

revoke_key() {
    [ -z "$1" ] && echo "用法: $0 revoke <alias>" && exit 1
    local alias=$1
    local token
    token=$(get_token_by_alias "$alias")
    [ -z "$token" ] && printf "${RED}未找到 alias: $alias${NC}\n" && exit 1
    printf "${YELLOW}撤销 Key: $alias${NC}\n"
    curl -s -X POST "$GATEWAY_URL/key/delete" \
        -H "Authorization: Bearer $LITELLM_MASTER_KEY" \
        -H "Content-Type: application/json" \
        -d "{\"keys\": [\"$token\"]}" | python3 -m json.tool 2>/dev/null || cat
}

test_key() {
    [ -z "$1" ] && echo "用法: $0 test <key|alias>" && exit 1
    local input=$1
    local key

    if [[ "$input" == sk-* ]]; then
        key="$input"
    elif [ -f "$KEYS_FILE" ]; then
        # 从保存的文件中查找
        key=$(grep "^$input|" "$KEYS_FILE" 2>/dev/null | head -1 | cut -d'|' -f2)
        if [ -z "$key" ]; then
            printf "${RED}未找到 alias: $input${NC}\n"
            printf "${YELLOW}提示: 使用完整 key (sk-xxx 格式) 或先创建 Key${NC}\n"
            exit 1
        fi
    else
        printf "${RED}test 命令需要完整的 key (sk-xxx 格式) 或已保存的 alias${NC}\n"
        exit 1
    fi

    printf "${GREEN}测试 Key: $input${NC}\n"
    curl -s "$GATEWAY_URL/v1/chat/completions" \
        -H "Authorization: Bearer $key" \
        -H "Content-Type: application/json" \
        -d '{"model":"qwen3.5-plus","messages":[{"role":"user","content":"说你好"}],"max_tokens":20}' | python3 -m json.tool 2>/dev/null || cat
}

# 显示已保存的 keys
saved_keys() {
    if [ ! -f "$KEYS_FILE" ]; then
        printf "${YELLOW}暂无保存的 Key${NC}\n"
        return
    fi
    printf "${GREEN}已保存的 Keys:${NC}\n\n"
    printf "%-20s %-30s %-8s %-6s %s\n" "别名" "Key" "预算" "天数" "创建时间"
    printf "%-20s %-30s %-8s %-6s %s\n" "----" "---" "----" "----" "--------"
    while IFS='|' read -r alias key budget days created; do
        printf "%-20s %-30s \$%-7s %-6s %s\n" "$alias" "$key" "$budget" "$days" "$created"
    done < "$KEYS_FILE"
}

show_help() {
    echo "LiteLLM Key 管理脚本"
    echo ""
    echo "用法: $0 <command> [args]"
    echo ""
    echo "命令:"
    echo "  create <alias> [budget] [days]  创建新 Key (全模型)"
    echo "  i, create-interactive           交互式创建 Key"
    echo "  list                            列出所有 Key (数据库)"
    echo "  saved                           显示已保存的 Keys"
    echo "  info <alias>                    查看 Key 详情"
    echo "  revoke <alias>                  撤销 Key"
    echo "  test <key|alias>                测试 Key"
    echo ""
    echo "说明: Key 创建后自动保存，可用 alias 进行 test"
}

case "$1" in
    create) create_key "$2" "$3" "$4" ;;
    create-interactive|i) create_key_interactive "$2" "$3" "$4" ;;
    list) list_keys ;;
    saved) saved_keys ;;
    info) key_info "$2" ;;
    revoke) revoke_key "$2" ;;
    test) test_key "$2" ;;
    *) show_help ;;
esac
