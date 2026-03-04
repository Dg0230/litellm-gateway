"""
OpenClaw API 客户端使用示例

使用前请确认:
1. 已获取 API Key
2. 已确认 Gateway 地址

修改下面的配置后即可使用:
"""

# ============ 配置区 ============
BASE_URL = "https://your-gateway.com/v1"  # 替换为你的 Gateway 地址
API_KEY = "sk-customer-your-key-here"      # 替换为你的 API Key
# =================================

# ==================== 方式一: OpenAI SDK (推荐) ====================

from openai import OpenAI

client = OpenAI(
    base_url=BASE_URL,
    api_key=API_KEY
)

# 普通对话
response = client.chat.completions.create(
    model="gpt-4",
    messages=[
        {"role": "system", "content": "你是一个编程助手"},
        {"role": "user", "content": "写一个 Python 快速排序"}
    ]
)
print(response.choices[0].message.content)

# 流式输出
print("\n--- 流式输出 ---")
stream = client.chat.completions.create(
    model="gpt-4",
    messages=[{"role": "user", "content": "解释什么是递归"}],
    stream=True
)

for chunk in stream:
    if chunk.choices[0].delta.content:
        print(chunk.choices[0].delta.content, end="", flush=True)
print()

# ==================== 方式二: requests 库 ====================

import requests
import json

def chat(message: str, model: str = "gpt-4"):
    """简单的聊天函数"""
    response = requests.post(
        f"{BASE_URL}/chat/completions",
        headers={
            "Authorization": f"Bearer {API_KEY}",
            "Content-Type": "application/json"
        },
        json={
            "model": model,
            "messages": [{"role": "user", "content": message}]
        }
    )
    return response.json()

result = chat("Hello!")
print(result["choices"][0]["message"]["content"])

# ==================== 方式三: LangChain 集成 ====================

# from langchain_openai import ChatOpenAI
# from langchain.schema import HumanMessage

# llm = ChatOpenAI(
#     openai_api_base=BASE_URL,
#     openai_api_key=API_KEY,
#     model_name="gpt-4"
# )

# response = llm.invoke([HumanMessage(content="你好!")])
# print(response.content)

# ==================== 方式四: curl 命令 ====================

# 普通请求:
# curl https://your-gateway.com/v1/chat/completions \
#   -H "Authorization: Bearer sk-customer-xxx" \
#   -H "Content-Type: application/json" \
#   -d '{"model":"gpt-4","messages":[{"role":"user","content":"Hello!"}]}'

# 流式请求:
# curl https://your-gateway.com/v1/chat/completions \
#   -H "Authorization: Bearer sk-customer-xxx" \
#   -H "Content-Type: application/json" \
#   -d '{"model":"gpt-4","messages":[{"role":"user","content":"Hello!"}],"stream":true}'

# ==================== 可用模型 ====================

# gpt-4          - 主力模型，适合复杂任务
# gpt-4-turbo    - 高性能模型
# gpt-3.5-turbo  - 经济模型，适合简单任务

# 查看可用模型:
# curl https://your-gateway.com/v1/models \
#   -H "Authorization: Bearer sk-customer-xxx"
