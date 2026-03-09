#!/usr/bin/env python3
"""
LiteLLM Key 管理工具
"""

import argparse
import json
import os
import subprocess
import sys
from datetime import datetime
from urllib.request import Request, urlopen
from urllib.error import URLError

# 配置
SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))
ENV_FILE = os.path.join(SCRIPT_DIR, "..", ".env")
KEYS_FILE = os.path.join(SCRIPT_DIR, ".saved_keys")
GATEWAY_URL = os.environ.get("GATEWAY_URL", "http://localhost:4000")

# 颜色
class Color:
    GREEN = "\033[0;32m"
    YELLOW = "\033[1;33m"
    RED = "\033[0;31m"
    BLUE = "\033[0;34m"
    NC = "\033[0m"

    @staticmethod
    def green(text): return f"{Color.GREEN}{text}{Color.NC}"
    @staticmethod
    def yellow(text): return f"{Color.YELLOW}{text}{Color.NC}"
    @staticmethod
    def red(text): return f"{Color.RED}{text}{Color.NC}"
    @staticmethod
    def blue(text): return f"{Color.BLUE}{text}{Color.NC}"

# 所有模型
ALL_MODELS = [
    "qwen3.5-plus", "qwen3-max-2026-01-23", "qwen3-coder-next", "qwen3-coder-plus",
    "kimi-k2.5", "MiniMax-M2.5", "glm-5", "glm-4.7",
    "doubao-seed-2.0-lite", "doubao-seed-2.0-pro", "doubao-seed-2.0-code-preview",
    "doubao-seed-2.0-mini", "deepseek-v3-2-251201",
    "doubao-seed-2-0-pro-vision", "doubao-seed-2-0-lite-vision", "doubao-seedream-4-5",
    "doubao-seedream-5-0",
    "glm-4.5", "glm-4.5-air", "glm-4.6",
]

# 模型菜单
MODEL_MENU = """
    ══════════════════════════════════════
    [0] 全部模型 (20个)

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
      [17] doubao-seedream-5-0

    ── 智谱官方 ──
      [18] glm-4.5
      [19] glm-4.5-air
      [20] glm-4.6
"""

def load_env():
    """加载 .env 文件中的 MASTER_KEY"""
    master_key = None
    if os.path.exists(ENV_FILE):
        with open(ENV_FILE) as f:
            for line in f:
                if line.startswith("LITELLM_MASTER_KEY="):
                    master_key = line.strip().split("=", 1)[1]
                    break
    return master_key

MASTER_KEY = load_env()

def api_request(path, data=None, method=None):
    """发送 API 请求"""
    url = f"{GATEWAY_URL}{path}"
    headers = {"Authorization": f"Bearer {MASTER_KEY}", "Content-Type": "application/json"}

    if data:
        body = json.dumps(data).encode()
    else:
        body = None

    req = Request(url, data=body, headers=headers, method=method)
    try:
        with urlopen(req) as resp:
            return json.loads(resp.read().decode())
    except URLError as e:
        return {"error": str(e)}

def input_prompt(prompt, default=None):
    """输入提示"""
    hint = f" (默认: {default})" if default else ""
    text = input(Color.blue(f"{prompt}{hint}: "))
    return text.strip() if text.strip() else default

def select_models():
    """交互式选择模型"""
    print(MODEL_MENU)
    choices = input(Color.blue("请输入模型编号 (多个用空格分隔, 0=全部): ")).strip()

    if "0" in choices.split():
        return ALL_MODELS

    models = []
    for choice in choices.split():
        try:
            idx = int(choice)
            if 1 <= idx <= len(ALL_MODELS):
                models.append(ALL_MODELS[idx - 1])
        except ValueError:
            continue

    if not models:
        print(Color.red("未选择任何模型，使用全部模型"))
        return ALL_MODELS

    return models

def save_key(alias, key, budget, days):
    """保存 Key 到文件"""
    created_at = datetime.now().strftime("%Y-%m-%d %H:%M:%S")
    with open(KEYS_FILE, "a") as f:
        f.write(f"{alias}|{key}|{budget}|{days}|{created_at}\n")
    os.chmod(KEYS_FILE, 0o600)

def get_saved_key(alias):
    """从文件获取保存的 Key"""
    if not os.path.exists(KEYS_FILE):
        return None
    with open(KEYS_FILE) as f:
        for line in f:
            parts = line.strip().split("|")
            if parts[0] == alias:
                return parts[1] if len(parts) > 1 else None
    return None

def cmd_create(args):
    """创建 Key"""
    alias = args.alias
    budget = args.budget or 100
    days = args.days or 365

    if not alias:
        alias = input_prompt("请输入 Key 别名")
        if not alias:
            print(Color.red("错误: 别名不能为空"))
            return

    print(Color.green(f"创建 Key: {alias} (全模型, 预算: ${budget}, {days}天)"))

    data = {
        "models": ALL_MODELS,
        "max_budget": budget,
        "duration": f"{days}d",
        "key_alias": alias,
    }

    result = api_request("/key/generate", data)

    if "error" in result:
        print(Color.red(f"创建失败: {result['error']}"))
        return

    print(json.dumps(result, indent=2, ensure_ascii=False))

    if "key" in result:
        save_key(alias, result["key"], budget, days)
        print(Color.green(f"\nKey 已保存到: {KEYS_FILE}"))

def cmd_interactive(args):
    """交互式创建 Key"""
    alias = args.alias or input_prompt("请输入 Key 别名")
    if not alias:
        print(Color.red("错误: 别名不能为空"))
        return

    models = select_models()

    budget = args.budget or input_prompt("请输入预算 (美元)", "100")
    budget = int(budget) if budget else 100

    days = args.days or input_prompt("请输入有效期 (天)", "365")
    days = int(days) if days else 365

    print(f"\n{Color.green(f'创建 Key: {alias}')}")
    print(f"  预算: ${budget}")
    print(f"  有效期: {days}天")

    confirm = input(Color.yellow("确认创建? [Y/n]: ")).strip().lower()
    if confirm == "n":
        print(Color.red("已取消"))
        return

    data = {
        "models": models,
        "max_budget": budget,
        "duration": f"{days}d",
        "key_alias": alias,
    }

    result = api_request("/key/generate", data)

    if "error" in result:
        print(Color.red(f"创建失败: {result['error']}"))
        return

    print(json.dumps(result, indent=2, ensure_ascii=False))

    if "key" in result:
        save_key(alias, result["key"], budget, days)
        print(Color.green(f"\nKey 已保存到: {KEYS_FILE}"))

def cmd_list(args):
    """列出所有 Key"""
    print(Color.green("所有 Key 列表:\n"))
    sql = '''
        SELECT key_alias AS "别名",
               max_budget AS "预算",
               ROUND(spend::numeric, 2) AS "已用",
               CASE WHEN expires IS NULL THEN '永久'
                    ELSE TO_CHAR(expires, 'YYYY-MM-DD') END AS "过期",
               CASE WHEN blocked = true THEN '已禁用' ELSE '正常' END AS "状态"
        FROM "LiteLLM_VerificationToken"
        WHERE key_alias IS NOT NULL
        ORDER BY created_at DESC
    '''
    try:
        subprocess.run(
            ["docker", "exec", "litellm-db", "psql", "-U", "litellm", "-d", "litellm", "-c", sql],
            check=True
        )
        print(f"\n{Color.blue('提示: 使用 alias (别名) 操作 info/revoke/test 命令')}")
    except subprocess.CalledProcessError:
        print("无法连接数据库")

def cmd_saved(args):
    """显示已保存的 Keys"""
    if not os.path.exists(KEYS_FILE):
        print(Color.yellow("暂无保存的 Key"))
        return

    print(Color.green("已保存的 Keys:\n"))
    print(f"{'别名':<20} {'Key':<30} {'预算':<8} {'天数':<6} {'创建时间'}")
    print("-" * 80)

    with open(KEYS_FILE) as f:
        for line in f:
            parts = line.strip().split("|")
            if len(parts) >= 5:
                print(f"{parts[0]:<20} {parts[1]:<30} ${parts[2]:<7} {parts[3]:<6} {parts[4]}")

def get_token_by_alias(alias):
    """通过 alias 从数据库获取 token"""
    sql = f"SELECT token FROM \"LiteLLM_VerificationToken\" WHERE key_alias = '{alias}' LIMIT 1"
    try:
        result = subprocess.run(
            ["docker", "exec", "litellm-db", "psql", "-U", "litellm", "-d", "litellm", "-t", "-c", sql],
            capture_output=True, text=True, check=True
        )
        return result.stdout.strip()
    except subprocess.CalledProcessError:
        return None

def cmd_info(args):
    """查看 Key 详情"""
    alias = args.alias
    if not alias:
        print("用法: manage_keys.py info <alias>")
        return

    print(Color.green(f"Key 详情: {alias}\n"))
    sql = f'''
        SELECT key_alias AS "别名",
               token AS "Token",
               max_budget AS "预算",
               ROUND(spend::numeric, 2) AS "已用",
               CASE WHEN expires IS NULL THEN '永久'
                    ELSE TO_CHAR(expires, 'YYYY-MM-DD HH24:MI') END AS "过期时间",
               CASE WHEN blocked = true THEN '已禁用' ELSE '正常' END AS "状态",
               array_to_string(models, ', ') AS "可用模型"
        FROM "LiteLLM_VerificationToken"
        WHERE key_alias = '{alias}'
    '''
    try:
        subprocess.run(
            ["docker", "exec", "litellm-db", "psql", "-U", "litellm", "-d", "litellm", "-c", sql],
            check=True
        )
    except subprocess.CalledProcessError:
        print(f"未找到 alias: {alias}")

def cmd_revoke(args):
    """撤销 Key"""
    alias = args.alias
    if not alias:
        print("用法: manage_keys.py revoke <alias>")
        return

    token = get_token_by_alias(alias)
    if not token:
        print(Color.red(f"未找到 alias: {alias}"))
        return

    print(Color.yellow(f"撤销 Key: {alias}"))
    result = api_request("/key/delete", {"keys": [token]}, method="POST")
    print(json.dumps(result, indent=2, ensure_ascii=False))

def cmd_test(args):
    """测试 Key"""
    key_or_alias = args.key
    if not key_or_alias:
        print("用法: manage_keys.py test <key|alias>")
        return

    # 判断是 key 还是 alias
    if key_or_alias.startswith("sk-"):
        key = key_or_alias
    else:
        key = get_saved_key(key_or_alias)
        if not key:
            print(Color.red(f"未找到 alias: {key_or_alias}"))
            print(Color.yellow("提示: 使用完整 key (sk-xxx 格式) 或先创建 Key"))
            return

    print(Color.green(f"测试 Key: {key_or_alias}"))
    result = api_request("/v1/chat/completions", {
        "model": "qwen3.5-plus",
        "messages": [{"role": "user", "content": "说你好"}],
        "max_tokens": 20
    })
    print(json.dumps(result, indent=2, ensure_ascii=False))

def main():
    parser = argparse.ArgumentParser(description="LiteLLM Key 管理工具")
    subparsers = parser.add_subparsers(dest="command", help="命令")

    # create
    p_create = subparsers.add_parser("create", help="创建新 Key (全模型)")
    p_create.add_argument("alias", nargs="?", help="Key 别名")
    p_create.add_argument("budget", nargs="?", type=int, help="预算")
    p_create.add_argument("days", nargs="?", type=int, help="有效期(天)")
    p_create.set_defaults(func=cmd_create)

    # interactive
    p_i = subparsers.add_parser("i", aliases=["interactive"], help="交互式创建 Key")
    p_i.add_argument("alias", nargs="?", help="Key 别名")
    p_i.add_argument("budget", nargs="?", type=int, help="预算")
    p_i.add_argument("days", nargs="?", type=int, help="有效期(天)")
    p_i.set_defaults(func=cmd_interactive)

    # list
    p_list = subparsers.add_parser("list", help="列出所有 Key (数据库)")
    p_list.set_defaults(func=cmd_list)

    # saved
    p_saved = subparsers.add_parser("saved", help="显示已保存的 Keys")
    p_saved.set_defaults(func=cmd_saved)

    # info
    p_info = subparsers.add_parser("info", help="查看 Key 详情")
    p_info.add_argument("alias", help="Key 别名")
    p_info.set_defaults(func=cmd_info)

    # revoke
    p_revoke = subparsers.add_parser("revoke", help="撤销 Key")
    p_revoke.add_argument("alias", help="Key 别名")
    p_revoke.set_defaults(func=cmd_revoke)

    # test
    p_test = subparsers.add_parser("test", help="测试 Key")
    p_test.add_argument("key", help="Key 或别名")
    p_test.set_defaults(func=cmd_test)

    args = parser.parse_args()

    if args.command:
        args.func(args)
    else:
        parser.print_help()

if __name__ == "__main__":
    main()
