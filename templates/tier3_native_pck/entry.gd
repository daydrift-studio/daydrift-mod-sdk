extends DaydriftNativeMod

## 《度日：Daydrift》Tier 3 原生 PCK 模组主入口示例脚本
## 继承 DaydriftNativeMod，拥有与游戏本体源码 100% 对等的全权引擎控制力。

func _on_mod_init() -> void:
	print("[%s] Native mod initializing..." % mod_id)
	# 覆写原版多语言文本（卸载时自动恢复）
	override_tr("zh_CN", "UI_NEW_GAME", "开启温馨新旅途")
	override_tr("en", "UI_NEW_GAME", "Begin Warm Journey")


func _on_mod_enable() -> void:
	print("[%s] Native mod enabled!" % mod_id)

	# 1. 注册快捷键 (F6)
	register_keybind("mod_test_action", KEY_F6)

	# 2. 注入家具交互选项
	inject_interaction_choice("kettle", "用模组茶壶沏一壶茉莉香茗", func() -> void:
		ModAPI.say("淡淡的茉莉清香弥漫在空气中，带来片刻的舒缓与惬意。", "温馨茶壶")
	)

	# 3. 动态挂载原生自定义 UI 控件到 HUD
	var badge := Label.new()
	badge.name = "ModStatusBadge"
	badge.text = "[Tier 3 Native Active]"
	badge.set("theme_override_colors/font_color", Color(0.9, 0.75, 0.4, 1.0))
	badge.position = Vector2(8, 8)
	mount_ui_node("InGameHUD", badge)


func _on_scene_ready(scene_id: String, _scene_root: Node) -> void:
	if scene_id.to_lower().contains("bedroom"):
		# 在卧室中动态生成一扇物理木门
		spawn_physical_door(
			scene_id,
			Vector2(120, 80),
			"res://src/locations/street/street.tscn",
			Vector2(100, 100),
			"推门通往喧嚣街区"
		)


func _on_node_added_anywhere(node: Node) -> void:
	# 第 0 帧拦截监听任意加入场景树的节点
	if node.is_in_group("player"):
		print("[%s] Detected player node entering tree!" % mod_id)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("mod_test_action"):
		ModAPI.toast("已按下 Tier 3 模组自定义快捷键 (F6)")


func _on_mod_disable() -> void:
	super._on_mod_disable()
	print("[%s] Native mod disabled and all changes rolled back." % mod_id)
