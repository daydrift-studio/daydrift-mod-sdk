# 《度日：Daydrift》模组创作者工具包 (Mod SDK)

欢迎来到《度日：Daydrift》的模组 (Mod) 创作者世界！

本仓库是官方对外公开维护的 **Mod SDK**，包含跨平台创作者 CLI 工具链、三体系脚手架工程模板、严格 JSON Schema 契约定义与双端代码智能补全存根。

- 🌐 **官方主站**：[daydrift.blym.top](https://daydrift.blym.top)
- 📖 **开发者文档中心**：[daydrift-docs.blym.top](https://daydrift-docs.blym.top)
- 🛒 **Mod 注册表与商店**：[daydrift-mods.blym.top](https://daydrift-mods.blym.top)

---

## 目录结构解构

```text
daydrift-mod-sdk/
├── sdk/
│   └── ddmod_cli.py           # 官方创作者 CLI 工具 (纯 Python 3 标准库，零 pip 依赖)
├── schemas/                   # JSON Schema 严格语法与字段契约定义
│   ├── manifest.schema.json   # 模组元数据清单规范 (v2)
│   └── slice.schema.json      # Tier 1 纯数据叙事事件切片规范
├── definitions/               # 智能代码提示与类型补全定义存根
│   ├── client_mod_api.d.lua   # 客户端 LuaLS / EmmyLua 全中文类型定义
│   ├── server_mod_api.d.lua   # 服务端 Go-Lua 沙盒全中文类型定义
│   └── daydrift_native_mod.gd # Tier 3 原生全能扩展基类 GDScript 存根
├── templates/                 # 官方全套模组脚手架工程模板
│   ├── tier1_data_pack/       # Tier 1：纯数据切片模组模板 (零代码)
│   ├── tier2_script_pack/     # Tier 2：轻量双端脚本模组模板 (Lua 沙盒)
│   ├── tier3_native_pck/      # Tier 3：原生全权扩展模组模板 (GDScript/PCK)
│   └── example_rainy_coffee/  # 官方核心示范模组 (覆盖卧室、街道与秘密阁楼三场景)
└── docs/                      # 离线创作者开发手册与接口文档
```

---

## 三体系模组选型矩阵

| 特性维度 | Tier 1：纯数据扩展 (Data Pack) | Tier 2：轻量逻辑沙盒 (Script Pack) | Tier 3：原生全权扩展 (Native PCK) |
| :--- | :--- | :--- | :--- |
| **受众定位** | 剧本策划、文案作者、音乐同人 | 机制数值设计者、轻度玩法程序员 | 独立游戏开发者、深度魔改工程师 |
| **编程门槛** | **完全零代码**（JSON + CSV） | 基础 Lua 脚本开发能力 | Godot 4 / GDScript 原生引擎开发经验 |
| **核心格式** | JSON 切片 + CSV 翻译 + 媒体素材 | `.lua` 双端脚本 + 清单配置 | `.pck` 编译资源包 + `entry.gd` |
| **执行载体** | 引擎内置的数据合并驱动器 | 纯解释型 Lua 沙盒虚拟机 (双端) | Godot 原生引擎挂载与场景树直接执行 |
| **引擎控制力** | 受限于数据注册表规范 | 受限于白名单 `ModAPI` / `ServerAPI` | **100% 原生代码等价 (Full Native Equivalence)** |
| **安全机制** | 物理级零攻击面，无法执行代码 | 虚拟指令配额、内存限制与异常隔离 | 启动崩溃自愈锁（`booting.lock`）兜底 |
| **典型应用** | 追加日常对话、事件切片、新物品、替换BGM | 动态天气事件、交互连锁判定、疲劳/状态效果 | 自定义物理房间门、魔改UI界面、全屏着色器 |

---

## 创作者 CLI 工具链 (`ddmod_cli.py`) 操作手册

工具链采用 Python 3 标准库编写，**无需安装任何 pip 包**，跨平台开箱即用：

### 1. 一键初始化模组工程 (`init`)
```bash
# 初始化 Tier 1 纯数据模组
python sdk/ddmod_cli.py init my_story_pack --tier 1 --name "初晨往事" --author "悠然"

# 初始化 Tier 2 双端脚本模组
python sdk/ddmod_cli.py init my_weather_mod --tier 2 --name "微风气象站" --author "旅人"

# 初始化 Tier 3 原生 PCK 模组
python sdk/ddmod_cli.py init my_arcade_room --tier 3 --name "街机小天地" --author "极客"
```

### 2. 静态安全合规审计 (`validate`)
校验清单格式、必填字段、SemVer 版本号、路径逃逸检测与危险可执行文件拦截：
```bash
python sdk/ddmod_cli.py validate path/to/my_mod
```

### 3. 规范打包输出 (`pack`)
通过审计后压缩为标准 `.ddmod` 分发归档并输出 SHA-256 校验和：
```bash
python sdk/ddmod_cli.py pack path/to/my_mod --out-dir ./dist
```

### 4. 秒级开发热链接 (`dev-link`)
一键将开发工程目录软链接（或同步）至游戏本地 `mods/` 运行目录，实现即改即测：
```bash
python sdk/ddmod_cli.py dev-link path/to/my_mod
```

---

## VSCode / Cursor 现代 IDE 智能补全配置

在模组根目录下创建 `.vscode/settings.json`：

```json
{
  "json.schemas": [
    {
      "fileMatch": ["/manifest.json"],
      "url": "https://daydrift-docs.blym.top/schemas/manifest.schema.json"
    },
    {
      "fileMatch": ["/narrative/*.json"],
      "url": "https://daydrift-docs.blym.top/schemas/slice.schema.json"
    }
  ],
  "Lua.workspace.library": [
    "path/to/daydrift-mod-sdk/definitions"
  ],
  "Lua.diagnostics.globals": [
    "ModAPI",
    "ServerAPI",
    "on_loaded",
    "on_period_changed",
    "on_day_advanced",
    "on_interacted",
    "on_scene_entered"
  ]
}
```

配置后：
1. `manifest.json` 与 `narrative/*.json` 拥有实时字段校验、语法红线与属性描述；
2. 编写 Lua 脚本时，`ModAPI.` 与 `ServerAPI.` 拥有全中文参数类型与文档浮窗提示！

---

## 模组提交与商店发布

当模组开发并经 `ddmod_cli.py validate` 验证通过后，欢迎前往 [daydrift-mods 仓库](https://github.com/daydrift-studio/daydrift-mods) 发起 Pull Request 申请上架，通过官方 CI 自动化审计与 Ed25519 签名后，即可点亮 **Verified (官方认证)** 徽标并在全平台分发！
