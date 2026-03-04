#!/bin/bash
#
# 网关测试脚本
#

GATEWAY_URL="${GATEWAY_URL:-http://localhost:4000}"

echo "=== LiteLLM Gateway 测试 ==="
echo ""

# 测试健康检查
echo "1. 健康检查..."
if curl -s -o /dev/null -w "%{http_code}" "$GATEWAY_URL/health" | grep -q "200"; then
    echo "   ✓ 服务正常"
else
    echo "   ✗ 服务异常"
    exit 1
fi

# 测试 API 调用 (需要 Key)
if [ -n "$1" ]; then
    echo "2. 测试 API 调用..."
    curl -s "$GATEWAY_URL/v1/chat/completions" \
        -H "Authorization: Bearer $1" \
        -H "Content-Type: application/json" \
        -d '{"model":"gpt-4","messages":[{"role":"user","content":"say hello"}],"max_tokens":20}' | python3 -m json.tool 2>/dev/null || cat
fi

echo ""
echo "测试完成!"
