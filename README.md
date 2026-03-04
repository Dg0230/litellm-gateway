# LiteLLM Gateway 快速部署包

一键部署 OpenAI 兼容的 API 网关，**支持智谱 GLM Coding Plan**。

客户只需更换 `base_url` 和 `api_key` 即可使用，完全无感知。

## 特性

- ✅ 100% OpenAI API 兼容
- ✅ 支持智谱 GLM Coding Plan (GLM-4.7/GLM-4.6)
- ✅ 支持 GLM-4-Flash 免费模型
- ✅ 客户端零改动，只换 base_url + api_key
- ✅ Key 权限隔离，客户无法修改模型
- ✅ PostgreSQL 持久化，支持 Key 管理

## 快速开始

```bash
cd deploy
./install.sh
```

## 模型映射

| 客户调用 | 实际模型 | 说明 |
|----------|----------|------|
| `gpt-4` | GLM-4.7 | Coding Plan，编程最强 |
| `gpt-4-turbo` | GLM-4.6 | Coding Plan，稳定版 |
| `gpt-3.5-turbo` | GLM-4-Flash | 免费，速度快 |

## 目录结构

```
deploy/
├── install.sh           # 一键安装脚本
├── verify.sh            # 部署验证脚本
├── uninstall.sh         # 卸载脚本
├── examples/
│   └── customer_examples.py  # 客户使用示例
└── README.md

# 安装后
litellm-gateway/
├── docker-compose.yml   # Docker 编排 (含 PostgreSQL)
├── .env                 # 环境变量 (API Keys)
├── config/
│   ├── litellm_config.yaml  # LiteLLM 配置
│   └── nginx.conf           # Nginx 配置
├── scripts/
│   ├── manage_keys.sh   # Key 管理
│   └── test_gateway.sh  # 网关测试
├── data/                # 数据库
└── logs/                # 日志
```

## Key 管理

```bash
# 创建客户 Key
./scripts/manage_keys.sh create customer-a 100 365
# 参数: 名称 预算(美元) 有效期(天)

# 列出所有 Key
./scripts/manage_keys.sh list

# 撤销 Key
./scripts/manage_keys.sh revoke sk-xxx

# 测试 Key
./scripts/manage_keys.sh test sk-xxx
```

## 客户使用

将以下信息发给客户:

```python
from openai import OpenAI

client = OpenAI(
    base_url="http://your-server/v1",  # 你的网关地址
    api_key="sk-customer-xxx"          # 分发的 Key
)

# 正常调用，完全兼容 OpenAI
response = client.chat.completions.create(
    model="gpt-4",
    messages=[{"role": "user", "content": "写一个快速排序"}]
)
```

## 常用命令

```bash
# 查看日志
docker compose logs -f litellm

# 重启服务
docker compose restart

# 停止服务
docker compose down

# 更新配置后重启
docker compose down && docker compose up -d
```

## 安全说明

1. **管理密钥** (`LITELLM_MASTER_KEY`) 仅供应商持有
2. 客户 Key 只能调用推理接口，无法访问管理功能
3. Nginx 层阻止了 `/key/`、`/admin/` 等管理接口
4. 定期轮换客户 Key 以确保安全

## Coding Plan 套餐

- 订阅地址: https://bigmodel.cn/
- 价格: 约 200 元/年
- 支持: GLM-4.7, GLM-4.6, GLM-4.5-air

## 故障排查

```bash
# 检查服务状态
docker compose ps

# 查看日志
docker compose logs litellm

# 测试健康检查
curl http://localhost:4000/health

# 测试 API
curl http://localhost:4000/v1/chat/completions \
  -H "Authorization: Bearer sk-xxx" \
  -H "Content-Type: application/json" \
  -d '{"model":"gpt-4","messages":[{"role":"user","content":"hi"}]}'
```
