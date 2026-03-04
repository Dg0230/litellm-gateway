#!/bin/bash
#
# LiteLLM Gateway 卸载脚本
#

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

INSTALL_DIR="${INSTALL_DIR:-/opt/litellm-gateway}"

echo -e "${YELLOW}========================================${NC}"
echo -e "${YELLOW}  LiteLLM Gateway 卸载脚本${NC}"
echo -e "${YELLOW}========================================${NC}"
echo ""

read -p "确定要卸载 LiteLLM Gateway? 所有数据将被删除! (yes/no): " confirm

if [ "$confirm" != "yes" ]; then
    echo "取消卸载"
    exit 0
fi

echo -e "${YELLOW}停止服务...${NC}"
cd "$INSTALL_DIR" 2>/dev/null && docker compose down 2>/dev/null || true

echo -e "${YELLOW}删除目录...${NC}"
rm -rf "$INSTALL_DIR"

echo -e "${GREEN}✓ 卸载完成${NC}"
