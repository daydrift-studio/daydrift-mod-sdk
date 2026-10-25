---@meta
--- 《度日：Daydrift》Mod 安全沙箱门面接口定义文件 (ModAPI Definition)
--- 供创作者在 VS Code / EmmyLua / LuaLS 环境下获得全量中文智能提示、语法检查与参数补全

---@class ModAPI
---Mod 安全沙箱唯一暴露的门面接口，严禁直接访问底层操作系统或文件系统
ModAPI = {}

-- ==============================================================================
-- 1. 叙事对话与轻量提示 (Narrative & Dialogue)
-- ==============================================================================

---在游戏画面中弹出对白或内心独白
---@param text string 对白正文内容
---@param speaker? string 讲述者名字（默认 "我"）
function ModAPI.say(text, speaker) end

---向玩家展示多分支选项对话框
---@param speaker string 讲述者名字
---@param text string 提问或前置对白
---@param choices string[]|table[] 分支选项文本数组，或包含 id 与 text 的字典数组
---@param callback_func_name? string 玩家点击选项后回调的函数名（接收选项索引与数据）
function ModAPI.choice(speaker, text, choices, callback_func_name) end

---向场景交互物体（如 "kettle", "window", "bed"）注入额外的互动选项
---@param target_id string 交互物体 ID（例如 "kettle"）
---@param choice_text string 选项展示文本（例如 "[模组] 冲泡一杯热挂耳咖啡"）
---@param callback_func_name string 点击该选项后调用的本地函数名
function ModAPI.add_choice(target_id, choice_text, callback_func_name) end

---在屏幕顶部弹出轻量化点阵气泡通知
---@param message string 提示文本
function ModAPI.toast(message) end

-- ==============================================================================
-- 2. 世界时钟与四时状态 (World & Time)
-- ==============================================================================

---获取当前游戏生存天数（从 1 开始累加）
---@return integer day 当前天数
function ModAPI.get_day() end

---获取当前离散时段枚举整数 (0: 清晨, 1: 正午, 2: 傍晚, 3: 深夜)
---@return integer period 当前时段数值 (0-3)
function ModAPI.get_period() end

---获取当前时段的可读本地化名称（例如 "清晨", "正午", "傍晚", "深夜"）
---@return string period_name 时段中文名称
function ModAPI.get_period_name() end

---将当前世界时段推进一个档位（清晨 -> 正午 -> 傍晚 -> 深夜 -> 次日清晨）
function ModAPI.advance_time() end

---获取全局场景黑板标记（跨场景共享状态）
---@param key string 状态键名
---@param default_value? any 若键不存在时的默认返回值
---@return any value 存储的状态值
function ModAPI.get_flag(key, default_value) end

---写入全局场景黑板标记
---@param key string 状态键名
---@param value any 需要保存的值
function ModAPI.set_flag(key, value) end

-- ==============================================================================
-- 3. 隔离持久化存档 (Isolated Mod Storage)
-- ==============================================================================

---读取本 Mod 私有命名空间下的持久化数据（与原版核心存档完全隔离）
---@param key string 键名
---@param default_value? any 默认值
---@return any value 存储的值
function ModAPI.get_data(key, default_value) end

---写入本 Mod 私有命名空间下的持久化数据
---@param key string 键名
---@param value any 需要保存的值
function ModAPI.set_data(key, value) end

-- ==============================================================================
-- 4. 资源加载与生命周期钩子规范 (Lifecycle Hooks)
-- ==============================================================================

---动态加载 Mod 内部的 PNG 贴图资源（免 .import 缓存，缺失时自动回退占位图）
---@param rel_path string 相对于本 Mod 根目录的相对路径（严禁包含 ".."）
---@return any texture 纹理对象引用
function ModAPI.load_texture(rel_path) end

---动态加载 Mod 内部的 OGG 音频流资源
---@param rel_path string 相对于本 Mod 根目录的相对路径
---@return any audio_stream 音频流对象引用
function ModAPI.load_audio(rel_path) end

-- ==============================================================================
-- 5. 标准生命周期回调函数（创作者在脚本中直接定义）
-- ==============================================================================

---当 Mod 装载进游戏内存时触发
function on_loaded() end

---当时段发生更迭推进时触发
---@param prev_period integer 变更前时段 (0-3)
---@param curr_period integer 变更后时段 (0-3)
function on_period_changed(prev_period, curr_period) end

---当深夜结算并跨入新的一天时触发
---@param current_day integer 新的一天数
function on_day_advanced(current_day) end

---当主角在场景中与特定生活物件交互时触发
---@param target_id string 交互点 ID (如 "kettle", "window", "bed", "street_bench")
function on_interacted(target_id) end

---当进入新场景加载完毕时触发
---@param scene_path string 场景路径标识
function on_scene_entered(scene_path) end
