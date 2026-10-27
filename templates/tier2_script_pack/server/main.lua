-- ==============================================================================
-- 《度日：Daydrift》Tier 2 Go 服务端扩展入口 (server/main.lua)
-- ==============================================================================

local weather_states = {"晴朗", "微雨", "薄雾", "宁静阴天"}
local current_index = 1

ServerAPI.log("气象站服务端模组已就绪")

-- 注册服务端管理指令 /weather [name]
ServerAPI.Commands.register("weather", "查看或切换全服天气状态", function(args)
    if #args > 0 then
        local new_w = args[1]
        ServerAPI.Blackboard.set("server_weather", new_w, true)
        ServerAPI.Net.broadcast("weather_update", { weather = new_w })
        return string.format("已将全服天气切换为：%s 并广播", new_w)
    else
        local curr = ServerAPI.Blackboard.get("server_weather")
        if curr == "" then curr = weather_states[current_index] end
        return string.format("当前全服天气为：%s", curr)
    end
end)

-- 时段推进钩子
function on_time_advanced(period, day)
    current_index = (current_index % #weather_states) + 1
    local next_weather = weather_states[current_index]
    ServerAPI.Blackboard.set("server_weather", next_weather, true)
    ServerAPI.Net.broadcast("weather_update", { weather = next_weather })
    ServerAPI.broadcast(string.format("【全服气象】进入第 %d 天 %s，天气变幻为：%s", day, period, next_weather))
end

-- 玩家加入钩子
function on_player_join(peer_id, nickname)
    local curr = ServerAPI.Blackboard.get("server_weather")
    if curr == "" then curr = weather_states[current_index] end
    ServerAPI.Net.send(peer_id, "weather_update", { weather = curr })
end

-- 接收客户端自定义网络报文
function on_net_packet(peer_id, channel, payload)
    if channel == "query_weather" then
        local curr = ServerAPI.Blackboard.get("server_weather")
        ServerAPI.Net.send(peer_id, "weather_update", { weather = curr })
    end
end
