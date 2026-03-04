#!/bin/bash
#
# 部署验证脚本 - 检查所有组件是否正常工作
#

GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m'

GATEWAY_URL="${1:-http://localhost:4000}"
API_KEY="$2"

echo -e "${YELLOW}LiteLLM Gateway 部署验证${NC}"
echo "Gateway URL: $GATEWAY_URL"
echo ""

PASS=0
FAIL=0

# 检查函数
check() {
    local name="$1"
    local result="$2"

    if [ "$result" = "0" ]; then
        echo -e "${GREEN}✓${NC} $name"
        ((PASS++))
    else
        echo -e "${RED}✗${NC} $name"
        ((FAIL++))
    fi
}

# 1. 健康检查
echo "=== 基础检查 ==="
HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" "$GATEWAY_URL/health")
check "健康检查" $([ "$HTTP_CODE" = "200" ] && echo 0 || echo 1)

# 2. 模型列表
HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" "$GATEWAY_URL/v1/models")
check "模型列表接口" $([ "$HTTP_CODE" = "200" ] || [ "$HTTP_CODE" = "401" ] && echo 0 || echo 1)

# 3. Nginx 检查 (如果有)
if command -v docker &> /dev/null; then
    docker ps | grep -q litellm-nginx && check "Nginx 容器" 0 || check "Nginx 容器" 1
    docker ps | grep -q litellm-gateway && check "LiteLLM 容器" 0 || check "LiteLLM 容器" 1
fi

# 需要认证的检查
if [ -n "$API_KEY" ]; then
    echo ""
    echo "=== API 调用测试 ==="

    # 4. Chat Completions
    RESULT=$(curl -s -o /dev/null -w "%{http_code}" "$GATEWAY_URL/v1/chat/completions" \
        -H "Authorization: Bearer $API_KEY" \
        -H "Content-Type: application/json" \
        -d '{"model":"gpt-4","messages":[{"role":"user","content":"hi"}],"max_tokens":5}')

    check "Chat Completions" $([ "$RESULT" = "200" ] && echo 0 || echo 1)

    # 5. 实际响应测试
    RESPONSE=$(curl -s "$GATEWAY_URL/v1/chat/completions" \
        -H "Authorization: Bearer $API_KEY" \
        -H "Content-Type: application/json" \
        -d '{"model":"gpt-4","messages":[{"role":"user","content":"say ok"}],"max_tokens":10}')

    echo "$RESPONSE" | jq -e '.choices[0].message.content' > /dev/null 2>&1
    check "响应格式正确" $?

    # 6. 流式响应
    STREAM_TEST=$(curl -s "$GATEWAY_URL/v1/chat/completions" \
        -H "Authorization: Bearer $API_KEY" \
        -H "Content-Type: application/json" \
        -d '{"model":"gpt-4","messages":[{"role":"user","content":"hi"}],"max_tokens":5,"stream":true}' | head -1)

    echo "$STREAM_TEST" | grep -q "data:" && check "流式响应" 0 || check "流式响应" 1
fi

# 总结
echo ""
echo "=== 测试结果 ==="
echo -e "${GREEN}通过: $PASS${NC}"
echo -e "${RED}失败: $FAIL${NC}"

if [ $FAIL -eq 0 ]; then
    echo -e "${GREEN}所有检查通过!${NC}"
    exit 0
else
    echo -e "${RED}部分检查失败，请排查${NC}"
    exit 1
fi
