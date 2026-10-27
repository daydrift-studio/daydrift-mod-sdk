---@meta
--- ==============================================================================
--- 《度日：Daydrift》Tier 2 客户端轻量脚本沙盒 API 声明存根 (client_mod_api.d.lua)
--- 适用于 VSCode Lua 插件 (Sumneko Lua / LuaLS) 提供智能补全与语法检查。
--- ==============================================================================

---@class ModAPI
ModAPI = {}

--- ==============================================================================
--- 1. 资源安全访问 (Asset Loader)
--- ==============================================================================

--- 安全解析相对于当前 Mod 根目录的绝对文件路径（自动阻断 "../" 路径逃逸）
---@param rel_path string 相对路径，例如 "assets/sfx/bell.ogg"
---@return string abs_path 安全解析后的物理路径
function ModAPI.resolve_path(rel_path) end

--- 动态加载当前 Mod 私有目录下的纹理
---@param rel_path string 图像文件相对路径 (PNG / JPG)
---@return any texture ImageTexture 句柄
function ModAPI.load_texture(rel_path) end

--- 动态加载当前 Mod 私有目录下的音频流
---@param rel_path string 音频文件相对路径 (OGG / WAV)
---@return any stream AudioStream 句柄
function ModAPI.load_audio(rel_path) end

--- ==============================================================================
--- 2. 叙事对话演播 (Dialogue & Narrative)
--- ==============================================================================

--- 调起单句对白或独白展示
---@param text string 对白正文文本
---@param speaker? string 说话人名称（可选）
function ModAPI.say(text, speaker) end

---@class ModChoiceItem
---@field text string 选项显示文字
---@field id? string 选项标识

--- 调起带选项的多分支对白
---@param speaker string 说话人名称
---@param text string 提示引导正文
---@param choices string[]|ModChoiceItem[] 分支选项列表
---@param callback? fun(index: integer, choice_data?: ModChoiceItem) 玩家点选分支后的回调函数
function ModAPI.choice(speaker, text, choices, callback) end

--- 在屏幕中央弹出一条温馨的点阵轻提示气泡
---@param message string 提示文本
function ModAPI.toast(message) end

--- ==============================================================================
--- 3. 四时世界与时间 (World & Time)
--- ==============================================================================

--- 获取当前生存天数 (第 N 天)
---@return integer day 当前天数
function ModAPI.get_day() end

--- 获取当前时段枚举数值 (0: 清晨, 1: 正午, 2: 傍晚, 3: 深夜)
---@return integer period 时段索引 (0-3)
function ModAPI.get_period() end

--- 获取当前时段的可读本地化名称 (如 "清晨", "正午")
---@return string name 时段本地化字符串
function ModAPI.get_period_name() end

--- 主动推进当前时段流转至下一时段
function ModAPI.advance_time() end

--- 读取场景全局黑板状态标记
---@param key string 状态键名
---@param default_value? any 缺省值
---@return any value 读取的值
function ModAPI.get_flag(key, default_value) end

--- 写入场景全局黑板状态标记
---@param key string 状态键名
---@param value any 写入的值
function ModAPI.set_flag(key, value) end

--- ==============================================================================
--- 4. 私有隔离持久化 (Isolated Storage)
--- ==============================================================================

--- 读取当前 Mod 私有命名空间下的持久化存档数据
---@param key string 数据键名
---@param default_value? any 缺省值
---@return any value 数据值
function ModAPI.get_data(key, default_value) end

--- 写入当前 Mod 私有命名空间下的持久化存档数据
---@param key string 数据键名
---@param value any 写入的值
function ModAPI.set_data(key, value) end

--- ==============================================================================
--- 5. 生命周期钩子与分支注入 (Hooks & Interactions)
--- ==============================================================================

--- 注册生命周期监听钩子
---@param event_name "period_changed"|"day_advanced"|"interacted"|"scene_entered" 事件名称
---@param callback fun(...) 事件回调函数
function ModAPI.on_event(event_name, callback) end

--- 向原版场景中的交互物体（如 "kettle", "window", "bed"）注入额外的互动分支选项
---@param target_id string 目标交互物标识
---@param choice_text string 分支选项文字
---@param callback fun() 点击分支后的执行回调
function ModAPI.add_interaction_choice(target_id, choice_text, callback) end

--- 动态覆写或注入多语言词条
---@param locale string 语言代号，如 "zh_CN" 或 "en"
---@param key string 翻译词条键名
---@param new_text string 覆写后的本地化文本
function ModAPI.override_tr(locale, key, new_text) end

--- ==============================================================================
--- 6. 联机自定义报文信道 (Networking)
--- ==============================================================================

--- 向联机网络（服务端或宿主）发送自定义模组报文
---@param channel string 信道名称
---@param payload table 报文负载字典
function ModAPI.send_net_packet(channel, payload) end

--- 监听指定信道的自定义网络报文
---@param channel string 信道名称
---@param callback fun(sender_id: string, payload: table) 收到报文时的回调函数
function ModAPI.on_net_packet(channel, callback) end
