# 《度日：Daydrift》模组开发工具包 (Mod SDK)

欢迎来到《度日：Daydrift》的模组 (Mod) 创作者世界！

本仓库是官方对外公开展现与维护的 **Mod SDK**，为创作者提供完整的接口类型定义、代码智能补全、清单结构规范以及参考模组模板。

---

## 目录结构

```text
daydrift-mod-sdk/
├── types/
│   └── mod_api.d.lua          # LuaLS / EmmyLua 全中文类型定义文件
├── schemas/
│   └── manifest.schema.json   # manifest.json 语法规范与校验 Schema
├── templates/
│   └── example_rainy_coffee/  # 官方手冲挂耳咖啡示例模组
└── README.md                  # 本说明指南
```

---

## 快速上手

### 1. 配置 VSCode / Cursor 开发环境（推荐）

1. 在 VSCode 中安装官方扩展 **Lua** (`sumneko.lua`)。
2. 在您的 Mod 工作区根目录下创建或编辑 `.vscode/settings.json`：

```json
{
  "Lua.workspace.library": [
    "path/to/daydrift-mod-sdk/types"
  ],
  "Lua.diagnostics.globals": [
    "ModAPI",
    "on_loaded",
    "on_period_changed",
    "on_day_advanced",
    "on_interacted",
    "on_scene_entered"
  ],
  "json.schemas": [
    {
      "fileMatch": ["manifest.json"],
      "url": "path/to/daydrift-mod-sdk/schemas/manifest.schema.json"
    }
  ]
}
```

配置后，输入 `ModAPI.` 即可自动获得全量中文注释、参数类型及返回值提示！

---

## 模组基础结构

每个《度日》模组是一个独立文件夹（压缩为 ZIP 时根目录包含 `manifest.json`）：

```text
my_awesome_mod/
├── manifest.json              # 必须：模组核心元数据清单
├── preview.webp               # 可选：模组预览封面 (推荐 1280x720)
├── scripts/                   # 可选：Lua 逻辑脚本
│   └── main.lua
└── narrative/                 # 可选：日常交互与叙事对白配置
    └── interactions.json
```

---

## 模组生命周期钩子（在 `scripts/*.lua` 中定义）

| 函数名 | 触发时机 | 参数 |
| :--- | :--- | :--- |
| `on_loaded()` | 模组装载进内存时 | 无 |
| `on_period_changed(prev, curr)` | 世界时段推进时 (0:清晨, 1:正午, 2:傍晚, 3:深夜) | `prev_period`, `curr_period` |
| `on_day_advanced(current_day)` | 深夜结算跨入新一天时 | `current_day` (从 1 递增) |
| `on_interacted(target_id)` | 玩家在场景中调查特定生活交互点时 | `target_id` ("kettle", "window" 等) |
| `on_scene_entered(scene_path)` | 切换进入新场景加载完毕时 | `scene_path` |

---

## 沙箱核心门面接口 (`ModAPI`)

所有游戏能力均封装于全局安全门面 `ModAPI` 中：

- **叙事与提示**：
  - `ModAPI.say(text, speaker?)`：显示对话/独白
  - `ModAPI.choice(speaker, text, choices, callback?)`：弹出多分支选项
  - `ModAPI.add_choice(target_id, choice_text, callback)`：向生活物件注入新选项
  - `ModAPI.toast(message)`：在顶栏弹出像素点阵提示气泡
- **世界与时间**：
  - `ModAPI.get_day()` / `ModAPI.get_period()` / `ModAPI.get_period_name()`
  - `ModAPI.advance_time()`：时段推移
  - `ModAPI.get_flag(key, default?)` / `ModAPI.set_flag(key, value)`：跨场景状态黑板
- **隔离持久化**：
  - `ModAPI.get_data(key, default?)` / `ModAPI.set_data(key, value)`：Mod 独立安全存档

---

## 许可证

本 SDK 遵循 [MIT License](LICENSE)。示例模组采用 CC-BY-4.0 许可。
欢迎社区创作者自由 Fork、扩展并向官方 Mod 商店投稿！
