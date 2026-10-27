# 《度日：Daydrift》三体系 Mod SDK 创作者开发全景指南

本文档为《度日：Daydrift》模组开发官方技术指南，涵盖三体系架构选型标准、Tier 3 原生引擎全能基类 `DaydriftNativeMod` 全量接口与生命周期流转、Tier 2 双端脚本沙盒通信、以及创作者命令行工具链（`ddmod_cli.py`）的标准工作流。

---

## 1. 模组三体系架构选型矩阵

《度日：Daydrift》提供三级分流架构，创作者可根据内容类型、代码要求与能力边界选择最合适的体系：

| 维度 | Tier 1：纯数据扩展 (Data Pack) | Tier 2：轻量逻辑沙盒 (Script Pack) | Tier 3：原生全权扩展 (Native PCK) |
| :--- | :--- | :--- | :--- |
| **受众定位** | 剧情创作者、文案同人、音效画师 | 机制数值设计者、轻度玩法程序员 | 独立游戏开发者、深度魔改工程师 |
| **代码门槛** | 完全零代码 | 基础 Lua 脚本能力 | Godot 4 / GDScript 原生开发能力 |
| **核心格式** | JSON 切片 + CSV 翻译 + 媒体资产 | `.lua` 双端脚本 + 清单 | `.pck` 资源包 + `entry.gd` |
| **执行载体** | 宿主数据合并驱动器 | 纯解释型 Lua 沙盒虚拟机 | Godot 引擎原生挂载与场景树节点 |
| **引擎控制力** | 受限于数据注册表规范 | 受限于白名单 `ModAPI` / `ServerAPI` | 100% 原生代码等价（Full Native Equivalence） |
| **网络同步** | 客户端本地生效 | 双端联动、支持自定义 OpCode 报文 | 自定义网络包、直达底层网络流 |
| **安全评级** | 物理级零风险 | 虚拟指令配额与异常隔离保护 | 启动崩溃自愈锁（booting.lock）兜底 |
| **典型应用** | 追加日常对话、事件切片、新物品、替换BGM | 动态天气事件、交互连锁判定、疲劳/状态效果 | 自定义物理房间门、魔改UI界面、全屏Shader滤镜 |

---

## 2. Tier 3 原生全权基类 `DaydriftNativeMod` 开发手册

### 2.1 架构理念与一等公民设计
`DaydriftNativeMod`（`class_name DaydriftNativeMod extends Node`）是 Tier 3 原生 PCK 模组的核心基类。
模组挂载后，其实例直接挂载在场景树根节点 `/root` 下，默认设置 `process_mode = Node.PROCESS_MODE_ALWAYS`，拥有与游戏本体代码完全对等的引擎支配权，同时内置托管追踪表，在模组停用或重载时实现 100% 干净回滚（Zero-Residue Rollback）。

### 2.2 全域核心引用直达（零反射、零阉割）
子类初始化后可直接访问以下核心单例与引擎服务：
- `tree: SceneTree`：直达 `get_tree()`
- `root_window: Window`：直达 `get_tree().root`
- `event_bus: Node`：直达 `/root/EventBus`（全域信号调度总线）
- `time_manager: Node`：直达 `/root/TimeManager`（四时时钟、天数推进）
- `save_manager: Node`：直达 `/root/SaveManager`（原生存档字典、黑板状态）
- `audio_manager: Node`：直达 `/root/AudioManager`（音频流播放与音效控制）
- `scene_transition: Node`：直达 `/root/SceneTransition`（黑场过渡与切场调度）
- `mod_manager: Node`：直达 `/root/ModManager`（模组发现、跨模组查询）
- `network_manager: Node`：直达 `/root/NetworkManager`（联机底层信令流、报文收发）
- `lan_host_manager: Node`：直达 `/root/LanHostManager`（局域网房主广播管理）

### 2.3 原生生命周期拦截钩子
子类可重写以下虚函数参与游戏运行周期的关键阶段：

```gdscript
extends DaydriftNativeMod

## PCK 挂载完成、节点入树前触发（可用于提前注入资源与基础翻译）
func _on_mod_init() -> void:
    pass

## 模组入树并处于就绪激活态时触发
func _on_mod_enable() -> void:
    pass

## 场景树中任意节点加入时第 0 帧触发（可实时检测玩家实体、NPC、UI）
func _on_node_added_anywhere(node: Node) -> void:
    if node.is_in_group("player"):
        print("玩家实体进入场景树！")

## 场景切换就绪时触发
func _on_scene_ready(scene_id: String, scene_root: Node) -> void:
    print("当前场景已就绪: ", scene_id)

## 四时时段更迭时触发 (0: 清晨, 1: 正午, 2: 傍晚, 3: 深夜)
func _on_period_changed(day: int, new_period: int, period_name: String) -> void:
    print("时段流转: 第 %d 天 %s" % [day, period_name])

## 跨天结算时触发
func _on_day_advanced(new_day: int) -> void:
    print("跨入新的一天: 第 %d 天" % new_day)

## 原生存档写入前触发（可向 save_data 字典追加自定义字段）
func _on_before_save(save_data: Dictionary) -> void:
    pass

## 原生读档数据加载后触发
func _on_after_load(save_data: Dictionary) -> void:
    pass

## 收到联机模组自定义网络报文时触发
func _on_net_packet(sender_id: String, channel: String, payload: Dictionary) -> void:
    pass

## 模组停用或热卸载前触发（自动触发全量无感知回滚）
func _on_mod_disable() -> void:
    super._on_mod_disable()
```

### 2.4 原生资源劫持与 Monkey Patching
支持在运行时替换游戏本体的任何资源与挂载脚本，并在卸载时自动恢复：
- `hijack_resource(target_res_path: String, replacement_res: Resource) -> void`
  强制接管 `res://` 虚拟路径，例如用模组场景替换原版卧室 `res://src/locations/bedroom/bedroom.tscn`。
- `patch_node_script(target_node: Node, new_script: Script, preserve_state: bool = true) -> void`
  直接替换场上已存在节点的挂载脚本，并保留原有属性状态。
- `register_custom_autoload(singleton_name: String, instance: Node) -> void`
  向 `/root` 动态挂载模组的全局单例节点。

### 2.5 多语言覆写与对话框拦截
- `override_tr(locale: String, key: String, new_text: String) -> void`
  实时替换原版任意 UI、剧情词条或注入新词条，卸载时自动从 `TranslationServer` 撤回。
- `override_tr_batch(locale: String, translations_map: Dictionary) -> void`
  批量替换多语言字典。
- `load_csv_translations(csv_res_path: String) -> Error`
  直接解析并加载模组私有 CSV 翻译文件。
- `register_dialogue_interceptor(interceptor: Callable) -> void`
  注册全局对话框拦截器 `func(ctx: Dictionary) -> Dictionary`，在台词渲染前修改说话人或台词正文。

### 2.6 世界构建、房间门与 UI 注入
- `spawn_physical_door(target_scene_id: String, pos: Vector2, dest_loc_id: String, spawn_pos: Vector2, label_tr: String) -> Node`
  在原版场景中生成一扇物理实体木门（`RoomDoor`），通往新场景。
- `spawn_interactable(target_scene_id: String, node_name: String, pos: Vector2, tex: Texture2D, prompt_tr: String, on_interact: Callable) -> Node`
  在指定坐标生成带碰撞检测与交互提示气泡的物件。
- `inject_interaction_choice(anchor_id: String, choice_tr: String, callback: Callable, condition: Callable = Callable()) -> void`
  为原版家具或 NPC 追加自定义交互选项分支。
- `add_screen_post_shader(layer: int, mat: ShaderMaterial) -> ColorRect`
  向全局挂载全屏后处理着色器（如雨滴、复古扫描线）。
- `mount_ui_node(target_alias_or_path: String, control: Control) -> void`
  将自定义 UI 挂载入 `"MainMenu"`、`"InGameHUD"` 或任意节点。
- `register_keybind(action_name: String, key: Key, joy_btn: JoyButton = JOY_BUTTON_INVALID) -> void`
  动态注册快捷键。
- `connect_managed(sig: Signal, callable: Callable, flags: int = 0) -> void`
  托管连接原生信号，模组卸载时自动断开。
- `add_child_managed(parent: Node, child: Node) -> Node`
  向任意节点挂载子节点，模组卸载时自动调用 `queue_free()` 销毁。

---

## 3. Tier 2 双端脚本沙盒开发手册

### 3.1 客户端 `ModAPI` 方法速查
在客户端 Lua 脚本中，全局对象 `ModAPI` 提供受控操作能力：
- **资源解析**：`ModAPI.resolve_path(rel_path)`、`ModAPI.load_texture(rel_path)`、`ModAPI.load_audio(rel_path)`
- **叙事对话**：`ModAPI.say(text, speaker)`、`ModAPI.choice(speaker, text, choices, callback)`、`ModAPI.toast(msg)`
- **时间与世界**：`ModAPI.get_day()`、`ModAPI.get_period()`、`ModAPI.get_period_name()`、`ModAPI.advance_time()`
- **数据黑板**：`ModAPI.get_flag(key, default)`、`ModAPI.set_flag(key, val)`、`ModAPI.get_data(key)`、`ModAPI.set_data(key, val)`
- **事件与分支**：`ModAPI.on_event(event_name, callback)`、`ModAPI.add_interaction_choice(target_id, text, callback)`
- **网络通信**：`ModAPI.send_net_packet(channel, payload)`、`ModAPI.on_net_packet(channel, callback)`

### 3.2 服务端 `ServerAPI` 方法速查
在 Go 服务端 Lua 脚本中，全局对象 `ServerAPI` 承接联机管理逻辑：
- **日志与世界**：`ServerAPI.log(msg)`、`ServerAPI.get_time()`、`ServerAPI.set_time(period, day)`、`ServerAPI.broadcast(msg)`
- **公共黑板**：`ServerAPI.Blackboard.get(key)`、`ServerAPI.Blackboard.set(key, val, broadcast)`
- **自定义报文**：`ServerAPI.Net.send(peer_id, channel, payload)`、`ServerAPI.Net.broadcast(channel, payload)`
- **指令注册**：`ServerAPI.Commands.register(name, description, handler)`
- **全局回调**：`on_player_join(peer_id, nick)`、`on_player_leave(peer_id)`、`on_time_advanced(period, day)`、`on_chat(peer_id, nick, msg)`、`on_net_packet(peer_id, channel, payload)`

---

## 4. 创作者 CLI 工具链 (`ddmod_cli.py`) 操作手册

工具链位于 `sdk/ddmod_cli.py`，采用 Python 3 标准库编写，跨平台零依赖。

### 4.1 初始化模组工程 (`init`)
根据指定体系一键生成标准项目结构与 VSCode 補全配置：
```bash
# 初始化 Tier 1 纯数据模组
python sdk/ddmod_cli.py init my_story_pack --tier 1 --name "初晨往事" --author "悠然"

# 初始化 Tier 2 双端脚本模组
python sdk/ddmod_cli.py init my_weather_mod --tier 2 --name "微风气象站" --author "旅人"

# 初始化 Tier 3 原生 PCK 模组
python sdk/ddmod_cli.py init my_arcade_room --tier 3 --name "街机小天地" --author "极客"
```

### 4.2 静态安全审计 (`validate`)
校验清单格式、必填属性、路径规范与危险可执行文件：
```bash
python sdk/ddmod_cli.py validate path/to/my_mod
```
审计项包括：
1. `manifest.json` 完整性与 JSON 语法；
2. `id` 规范（全小写数字下划线，1-64字符）；
3. 语义化版本号格式（SemVer）；
4. `entry` 入口文件存在性校验；
5. 拦截 `..` 相对路径逃逸；
6. 严格拦截非法的 `.exe`、`.dll`、`.so`、`.bat`、`.sh` 等二进制脚本。

### 4.3 规范打包 (`pack`)
在通过静态审计后，将模组压缩为标准 `.ddmod` 发布包并输出 SHA256 校验和：
```bash
python sdk/ddmod_cli.py pack path/to/my_mod
# 输出：my_mod_v1.0.0.ddmod 与对应 SHA256
```

### 4.4 开发调试热链接 (`dev-link`)
将开发目录一键软链接（或同步）至游戏本地 `Daydrift/mods/` 运行目录，支持秒级热重载：
```bash
python sdk/ddmod_cli.py dev-link path/to/my_mod
```

---

## 5. VSCode 智能提示与补全配置

在模组根目录下创建 `.vscode/settings.json` 即可开启全套智能提示：

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
    "path/to/daydrift/sdk/definitions"
  ]
}
```
配置后：
1. `manifest.json` 与叙事切片 JSON 支持实时字段约束与语法报错；
2. 编写 Lua 脚本时，`ModAPI` 与 `ServerAPI` 提供完整的函数签名、参数类型与中文文档浮窗提示。
