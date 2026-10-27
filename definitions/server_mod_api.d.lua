---@meta
--- ==============================================================================
--- 《度日：Daydrift》Tier 2 服务端 Lua 扩展 API 声明存根 (server_mod_api.d.lua)
--- 适用于 Go 服务端 (server/internal/modhost) 沙盒环境，提供智能补全与语法检查。
--- ==============================================================================

---@class ServerBlackboard
local ServerBlackboard = {}

--- 读取服务端公共黑板键值
---@param key string 键名
---@return string value 存储的字符串值
function ServerBlackboard.get(key) end

--- 写入服务端公共黑板键值并可选择向全服在线旅人广播增量补丁
---@param key string 键名
---@param val string 键值
---@param broadcast? boolean 是否立即向全体在线客户端广播 (默认为 true)
function ServerBlackboard.set(key, val, broadcast) end


---@class ServerNet
local ServerNet = {}

--- 向指定 peer_id 客户端发送模组自定义数据报文
---@param peer_id integer 客户端 Peer ID
---@param channel string 信道标识
---@param payload table 负载数据表
---@return boolean success, string? error
function ServerNet.send(peer_id, channel, payload) end

--- 向全服所有在线旅人广播模组自定义数据报文
---@param channel string 信道标识
---@param payload table 负载数据表
---@return boolean success, string? error
function ServerNet.broadcast(channel, payload) end


---@class ServerCommands
local ServerCommands = {}

--- 动态向服务端管理路由注册自定义命令 (/name args...)
---@param name string 指令名称（不含斜杠）
---@param description string 指令帮助描述
---@param handler fun(args: string[]): string 执行函数，返回输出字符串
function ServerCommands.register(name, description, handler) end


---@class ServerAPI
---@field Blackboard ServerBlackboard 公共黑板管理接口
---@field blackboard ServerBlackboard 兼容小写引用
---@field Net ServerNet 网络数据报文传输接口
---@field net ServerNet 兼容小写引用
---@field Commands ServerCommands 服务端管理指令注册接口
---@field commands ServerCommands 兼容小写引用
ServerAPI = {}

--- 打印带有模组前缀的服务端日志
---@param msg string 日志正文
function ServerAPI.log(msg) end

--- 获取服务端当前世界时段与天数
---@return string period 时段名称 ("morning" | "noon" | "dusk" | "night")
---@return integer day 当前生存天数
function ServerAPI.get_time() end

--- 强制设置服务端时段与天数，并向全体在线玩家广播通知
---@param period string 时段名称 ("morning" | "noon" | "dusk" | "night")
---@param day integer 天数
function ServerAPI.set_time(period, day) end

--- 向全体在线旅人广播系统公约消息
---@param msg string 消息内容
function ServerAPI.broadcast(msg) end

--- 获取当前在线玩家总数
---@return integer count 在线人数
function ServerAPI.get_player_count() end

--- ==============================================================================
--- 服务端生命周期全局回调函数（由模组脚本实现并在全局声明）
--- ==============================================================================

--- 当新玩家完成握手加入房间时触发
---@param peer_id integer 玩家会话 Peer ID
---@param nickname string 玩家昵称
function on_player_join(peer_id, nickname) end

--- 当玩家断开连接离开房间时触发
---@param peer_id integer 玩家会话 Peer ID
function on_player_leave(peer_id) end

--- 当四时更迭或天数流转时触发
---@param period string 新时段
---@param day integer 新天数
function on_time_advanced(period, day) end

--- 当玩家发送公屏聊天时触发。返回 false 可拦截该条聊天消息
---@param peer_id integer 发送者 Peer ID
---@param nickname string 发送者昵称
---@param message string 聊天内容
---@return boolean? allow 是否允许广播（返回 false 阻断）
function on_chat(peer_id, nickname, message) end

--- 当收到客户端发送的 mod_custom 模组自定义网络报文时触发
---@param peer_id integer 来源客户端 Peer ID
---@param channel string 信道名称
---@param payload table 报文负载数据表
function on_net_packet(peer_id, channel, payload) end
