-- ==============================================================================
-- 《度日：Daydrift》Tier 2 客户端脚本入口 (scripts/main.lua)
-- ==============================================================================

local current_weather = "晴朗"

-- 监听四时更迭事件
ModAPI.on_event("period_changed", function(prev_period, new_period)
    local p_name = ModAPI.get_period_name()
    ModAPI.toast(string.format("气象站监测到时段更迭至：%s（当前天气：%s）", p_name, current_weather))
end)

-- 监听跨天结算事件
ModAPI.on_event("day_advanced", function(new_day)
    local day = ModAPI.get_day()
    ModAPI.set_data("recorded_days", day)
end)

-- 向窗户家具注入天气观测选项
ModAPI.add_interaction_choice("window", "通过气象站观测窗外天气", function()
    ModAPI.say(string.format("窗外的天空正是一片%s，远处的电线杆在微风中静静伫立。", current_weather), "气象仪")
end)

-- 监听服务端发送的天气同步网络报文
ModAPI.on_net_packet("weather_update", function(sender_id, payload)
    if payload and payload.weather then
        current_weather = payload.weather
        ModAPI.toast(string.format("【联机气象广播】天气更新为：%s", current_weather))
    end
end)
