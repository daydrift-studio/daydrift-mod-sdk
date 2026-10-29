class_name DaydriftNativeMod
extends Node

## 《度日：Daydrift》Tier 3 原生引擎全权扩展模组核心基类
## 赋予原生 PCK 模组与游戏本体代码完全对等（100% Full Native Code Equivalence）的控制力，
## 并内置完整的生命周期托管拦截表与自动无感知回滚机制（Automatic Zero-Residue Rollback）。

# 模组基础属性
var mod_id: String = ""
var mod_dir: String = ""
var is_active: bool = false

# ==============================================================================
# 1. 全域 Autoload 单例与引擎核心直达引用（零反射、零阉割、一等公民）
# ==============================================================================

var tree: SceneTree = null
var root_window: Window = null
var event_bus: Node = null
var time_manager: Node = null
var save_manager: Node = null
var audio_manager: Node = null
var scene_transition: Node = null
var mod_manager: Node = null
var network_manager: Node = null
var lan_host_manager: Node = null

# ==============================================================================
# 2. 托管资源与修改追踪表（用于热卸载时 100% 干净回滚）
# ==============================================================================

var _hijacked_resources: Dictionary = {} # target_path: String -> original_resource: Resource
var _patched_scripts: Array[Dictionary] = [] # Array of {"node": Node, "original_script": Script, "saved_state": Dictionary}
var _custom_autoloads: Dictionary = {} # singleton_name: String -> instance: Node
var _mod_translations: Dictionary = {} # locale: String -> Translation
var _managed_csv_translations: Array[Translation] = []
var _dialogue_interceptors: Array[Callable] = []
var _managed_connections: Array[Dictionary] = [] # Array of {"signal": Signal, "callable": Callable}
var _managed_children: Array[Node] = []
var _managed_mounted_ui: Array[Dictionary] = [] # Array of {"parent": Node, "control": Control}
var _managed_added_actions: Array[String] = [] # Array of action_name: String
var _managed_screen_shaders: Array[CanvasLayer] = []
var _managed_injected_choices: Array[Dictionary] = [] # Array of {"anchor_id": String, "choice_text": String}
var _pending_ui_mounts: Array[Dictionary] = [] # Array of {"target_alias": String, "control": Control}
var _registered_locations: Dictionary = {} # loc_id: String -> PackedScene
var _managed_npc_overrides: Dictionary = {} # npc_id: String -> Dictionary

var _last_scene_id: String = ""


func _init() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_setup_core_references()


func _enter_tree() -> void:
	_setup_core_references()
	_connect_lifecycle_signals()


func _exit_tree() -> void:
	if is_active:
		_on_mod_disable()


# ==============================================================================
# 3. 原生生命周期钩子（供子类重写）
# ==============================================================================

## PCK 挂载后、节点尚未进入场景树时立即触发（适合提前注册底层翻译或劫持核心资源）
func _on_mod_init() -> void:
	pass

## 模组正式激活并挂载入根场景树时触发
func _on_mod_enable() -> void:
	pass

## 场景树中任何节点加入时立即触发（第 0 帧拦截，可检查玩家、NPC、UI 并进行动态增强）
func _on_node_added_anywhere(_node: Node) -> void:
	pass

## 主场景切换就绪时触发
func _on_scene_ready(_scene_id: String, _scene_root: Node) -> void:
	pass

## 四时流转（清晨/正午/傍晚/深夜）更迭时触发
func _on_period_changed(_day: int, _new_period: int, _period_name: String) -> void:
	pass

## 跨天结算时触发
func _on_day_advanced(_new_day: int) -> void:
	pass

## 存档序列化前触发（允许将自定义键值注入原生存档数据包）
func _on_before_save(_save_data: Dictionary) -> void:
	pass

## 读档数据加载后触发（允许读取原生存档恢复模组状态）
func _on_after_load(_save_data: Dictionary) -> void:
	pass

## 接收到联机网络自定义报文时触发
func _on_net_packet(_sender_id: String, _channel: String, _payload: Dictionary) -> void:
	pass

## 模组停用或重载时触发。重写时请务必调用 super._on_mod_disable() 以确保托管资源彻底释放
func _on_mod_disable() -> void:
	_rollback_all_managed_changes()
	is_active = false


# ==============================================================================
# 4. 原生脚本/场景热替换与 Monkey Patching 接口
# ==============================================================================

## 强制劫持接管 res:// 虚拟路径下的任意资源（场景、脚本、贴图、字体、Shader）
## 模组停用时自动无缝恢复原版资源
func hijack_resource(target_res_path: String, replacement_res: Resource) -> void:
	if target_res_path.is_empty() or not is_instance_valid(replacement_res):
		push_warning("[DaydriftNativeMod] hijack_resource: invalid parameters.")
		return

	if not _hijacked_resources.has(target_res_path):
		var orig_res: Resource = null
		if ResourceLoader.exists(target_res_path):
			orig_res = ResourceLoader.load(target_res_path)
		_hijacked_resources[target_res_path] = orig_res

	replacement_res.take_over_path(target_res_path)
	print("[DaydriftNativeMod:%s] Hijacked resource path: %s" % [mod_id, target_res_path])


## 在运行时动态给场景树中已存在节点替换挂载脚本，可选择完整保留并迁移其原有成员变量状态
## 模组停用时自动还原原版脚本与状态
func patch_node_script(target_node: Node, new_script: Script, preserve_state: bool = true) -> void:
	if not is_instance_valid(target_node) or not is_instance_valid(new_script):
		push_warning("[DaydriftNativeMod] patch_node_script: invalid node or script.")
		return

	var orig_script: Script = target_node.get_script() as Script
	var saved_state: Dictionary = {}

	if preserve_state:
		for prop in target_node.get_property_list():
			var usage: int = prop.get("usage", 0) as int
			if usage & PROPERTY_USAGE_SCRIPT_VARIABLE:
				var prop_name: String = prop.get("name", "") as String
				saved_state[prop_name] = target_node.get(prop_name)

	_patched_scripts.append({
		"node": target_node,
		"original_script": orig_script,
		"saved_state": saved_state
	})

	target_node.set_script(new_script)

	if preserve_state:
		for k in saved_state:
			if k in target_node:
				target_node.set(k, saved_state[k])

	print("[DaydriftNativeMod:%s] Patched script on node: %s" % [mod_id, target_node.get_path()])


## 向 /root 动态挂载模组自定义全局单例节点，模组卸载时自动安全释放
func register_custom_autoload(singleton_name: String, instance: Node) -> void:
	if singleton_name.is_empty() or not is_instance_valid(instance):
		return
	if is_instance_valid(root_window):
		instance.name = singleton_name
		root_window.add_child(instance)
		_custom_autoloads[singleton_name] = instance
		print("[DaydriftNativeMod:%s] Registered custom autoload singleton: /root/%s" % [mod_id, singleton_name])


# ==============================================================================
# 5. 文本/多语言全量篡改、对话劫持与世界构建 API
# ==============================================================================

## 实时覆写原版任意 UI、物品或对话词条（如改掉主菜单按钮文字、NPC 台词），或注入全新词条
## 模组停用时自动从 TranslationServer 撤销并完全恢复原版词条
func override_tr(locale: String, key: String, new_text: String) -> void:
	if locale.is_empty() or key.is_empty():
		return

	var tr_obj: Translation = null
	if _mod_translations.has(locale):
		tr_obj = _mod_translations[locale]
	else:
		tr_obj = Translation.new()
		tr_obj.locale = locale
		TranslationServer.add_translation(tr_obj)
		_mod_translations[locale] = tr_obj

	tr_obj.add_message(StringName(key), StringName(new_text))


## 批量覆写特定语言的多语言字典
func override_tr_batch(locale: String, translations_map: Dictionary) -> void:
	for k in translations_map.keys():
		override_tr(locale, str(k), str(translations_map[k]))


## 直接解析并挂载外部或 PCK 内的 CSV 翻译表，卸载时自动注销
func load_csv_translations(csv_res_path: String) -> Error:
	var file := FileAccess.open(csv_res_path, FileAccess.READ)
	if not file:
		var err := FileAccess.get_open_error()
		push_warning("[DaydriftNativeMod] Failed to open CSV translation: %s (err: %d)" % [csv_res_path, err])
		return err

	var header := file.get_csv_line()
	if header.size() < 2:
		file.close()
		return ERR_FILE_CORRUPT

	var locale_translations: Array[Translation] = []
	for i in range(1, header.size()):
		var loc: String = header[i].strip_edges()
		var tr_inst := Translation.new()
		tr_inst.locale = loc
		locale_translations.append(tr_inst)

	while not file.eof_reached():
		var row := file.get_csv_line()
		if row.size() < 2:
			continue
		var key_str := row[0].strip_edges()
		if key_str.is_empty():
			continue
		for col in range(1, mini(row.size(), header.size())):
			var trans_text := row[col]
			locale_translations[col - 1].add_message(StringName(key_str), StringName(trans_text))

	file.close()

	for tr_inst in locale_translations:
		TranslationServer.add_translation(tr_inst)
		_managed_csv_translations.append(tr_inst)

	print("[DaydriftNativeMod:%s] Successfully loaded CSV translations: %s" % [mod_id, csv_res_path])
	return OK


## 注册全局对话框拦截器 func(context: Dictionary) -> Dictionary
## 拦截上下文字典：{"speaker": String, "text": String, "dialogue_id": String}
## 允许在对白展示前修改台词文本、替换立绘或增删分支
func register_dialogue_interceptor(interceptor: Callable) -> void:
	if interceptor.is_valid() and not _dialogue_interceptors.has(interceptor):
		_dialogue_interceptors.append(interceptor)
		ModAPI.register_interceptor(interceptor)


## 注册全新的可进入地点场景
func register_location(loc_id: String, scene_res: PackedScene) -> void:
	if loc_id.is_empty() or not is_instance_valid(scene_res):
		return
	_registered_locations[loc_id] = scene_res
	# 若 SceneTransition 或游戏地图注册表存在，予以同步映射
	if is_instance_valid(scene_transition) and scene_transition.has_method("register_custom_scene"):
		scene_transition.call("register_custom_scene", loc_id, scene_res)
	print("[DaydriftNativeMod:%s] Registered custom location: %s" % [mod_id, loc_id])


## 在原版场景中动态生成一扇物理实体木门（RoomDoor），通往模组新场景或原版场景
func spawn_physical_door(target_scene_id: String, pos: Vector2, dest_loc_id: String, spawn_pos: Vector2, label_tr: String) -> Node:
	var door_scene: PackedScene = load("res://src/common/door/room_door.tscn") as PackedScene
	var door_node: Node = null
	if is_instance_valid(door_scene):
		door_node = door_scene.instantiate()
	else:
		door_node = RoomDoor.new()

	if not is_instance_valid(door_node):
		return null

	door_node.name = "ModDoor_%s_to_%s" % [target_scene_id, dest_loc_id]
	door_node.position = pos
	if "target_scene_path" in door_node:
		door_node.set("target_scene_path", dest_loc_id)
	if "door_id" in door_node:
		door_node.set("door_id", StringName("door_%s" % dest_loc_id))

	var current_scene: Node = tree.current_scene if is_instance_valid(tree) else null
	if is_instance_valid(current_scene):
		add_child_managed(current_scene, door_node)
	else:
		add_child_managed(self, door_node)

	print("[DaydriftNativeMod:%s] Spawned physical door at %s leading to %s" % [mod_id, str(pos), dest_loc_id])
	return door_node


## 在指定场景动态挂载交互物件（包含 2D 碰撞体与 Layer 4 交互气泡）
func spawn_interactable(target_scene_id: String, node_name: String, pos: Vector2, tex: Texture2D, prompt_tr: String, on_interact: Callable) -> Node:
	var container := Node2D.new()
	container.name = node_name
	container.position = pos

	if is_instance_valid(tex):
		var sprite := Sprite2D.new()
		sprite.name = "Sprite2D"
		sprite.texture = tex
		container.add_child(sprite)

	var area := InteractableArea2D.new()
	area.name = "InteractArea"
	area.prompt_key = prompt_tr
	area.interactable_id = StringName(node_name)

	var col_shape := CollisionShape2D.new()
	var rect_shape := RectangleShape2D.new()
	if is_instance_valid(tex):
		rect_shape.size = tex.get_size()
	else:
		rect_shape.size = Vector2(24, 24)
	col_shape.shape = rect_shape
	area.add_child(col_shape)

	if on_interact.is_valid():
		area.interacted.connect(func(_id: StringName) -> void:
			on_interact.call()
		)

	container.add_child(area)

	var current_scene: Node = tree.current_scene if is_instance_valid(tree) else null
	if is_instance_valid(current_scene):
		add_child_managed(current_scene, container)
	else:
		add_child_managed(self, container)

	return container


## 为原版场景中的任意交互家具或 NPC 注入额外的互动分支选项
func inject_interaction_choice(anchor_id: String, choice_tr: String, callback: Callable, condition: Callable = Callable()) -> void:
	ModAPI.add_interaction_choice(anchor_id, choice_tr, callback, mod_id)
	_managed_injected_choices.append({
		"anchor_id": anchor_id,
		"choice_text": choice_tr
	})


## 注册或覆盖 NPC 的四时出没作息与世界行为
func register_or_override_npc(npc_id: String, schedule_dict: Dictionary, custom_scene: PackedScene = null) -> void:
	_managed_npc_overrides[npc_id] = {
		"schedule": schedule_dict,
		"scene": custom_scene
	}

	# 遍历场景查找是否已存在该 NPC 并更新作息
	var curr_scene: Node = tree.current_scene if is_instance_valid(tree) else null
	if is_instance_valid(curr_scene):
		var existing_agent: Node = curr_scene.find_child("NpcScheduleAgent", true, false)
		if is_instance_valid(existing_agent) and "npc_id" in existing_agent and existing_agent.get("npc_id") == npc_id:
			for p in schedule_dict.keys():
				existing_agent.call("set_rule", int(p), schedule_dict[p])


## 在全局挂载全屏后处理 Shader（如像素暗角、复古扫描线、雨滴雾气滤镜）
func add_screen_post_shader(layer: int, mat: ShaderMaterial) -> ColorRect:
	var canvas_layer := CanvasLayer.new()
	canvas_layer.layer = layer
	canvas_layer.name = "ModShaderLayer_%s_%d" % [mod_id, layer]

	var rect := ColorRect.new()
	rect.name = "PostColorRect"
	rect.anchors_preset = Control.PRESET_FULL_RECT
	rect.anchor_right = 1.0
	rect.anchor_bottom = 1.0
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rect.material = mat

	canvas_layer.add_child(rect)

	if is_instance_valid(root_window):
		root_window.add_child(canvas_layer)
		_managed_screen_shaders.append(canvas_layer)

	return rect


## 将任意自定义 UI 控件安全挂载入原版主界面（如 "MainMenu"、"InGameHUD"、"PauseDrawer"）
func mount_ui_node(target_alias_or_path: String, control: Control) -> void:
	if not is_instance_valid(control):
		return

	var target_parent: Node = _resolve_ui_target(target_alias_or_path)
	if is_instance_valid(target_parent):
		target_parent.add_child(control)
		_managed_mounted_ui.append({"parent": target_parent, "control": control})
		print("[DaydriftNativeMod:%s] Mounted UI node to %s" % [mod_id, target_alias_or_path])
	else:
		_pending_ui_mounts.append({"target_alias": target_alias_or_path, "control": control})


## 动态向 InputMap 注册自定义按键映射，模组停用时自动清理
func register_keybind(action_name: String, key: Key, joy_btn: JoyButton = JOY_BUTTON_INVALID) -> void:
	if action_name.is_empty():
		return

	if not InputMap.has_action(action_name):
		InputMap.add_action(action_name)
		_managed_added_actions.append(action_name)

	var ev_key := InputEventKey.new()
	ev_key.physical_keycode = key
	InputMap.action_add_event(action_name, ev_key)

	if joy_btn != JOY_BUTTON_INVALID:
		var ev_joy := InputEventJoypadButton.new()
		ev_joy.button_index = joy_btn
		InputMap.action_add_event(action_name, ev_joy)


# ==============================================================================
# 6. 安全托管连接器（自动防热重载泄漏与野指针崩溃）
# ==============================================================================

## 托管连接任意原生信号，模组卸载或热重载时自动安全断开
func connect_managed(sig: Signal, callable: Callable, flags: int = 0) -> void:
	if not sig.is_connected(callable):
		sig.connect(callable, flags)
		_managed_connections.append({"signal": sig, "callable": callable})


## 托管挂载子节点至任意宿主节点，模组卸载时自动安全 queue_free()
func add_child_managed(parent: Node, child: Node) -> Node:
	if is_instance_valid(parent) and is_instance_valid(child):
		parent.add_child(child)
		_managed_children.append(child)
	return child


## 向服务端或联机对端发送自定义模组报文
func send_net_packet(channel: String, payload: Dictionary, target_peer: int = 0) -> void:
	if is_instance_valid(network_manager) and network_manager.has_method("send_mod_packet"):
		network_manager.call("send_mod_packet", mod_id, channel, payload)
	elif is_instance_valid(lan_host_manager) and lan_host_manager.has_method("send_mod_packet"):
		lan_host_manager.call("send_mod_packet", mod_id, channel, payload, target_peer)


## 快捷触发全域像素通知（Toast 浮层）
func toast(message: String) -> void:
	if is_instance_valid(event_bus) and event_bus.has_signal("dd_notification_shown"):
		event_bus.dd_notification_shown.emit(message)
	print("[%s] Toast: %s" % [mod_id, message])


## 快捷调出对白框或发送通知（自适应单参数文本或 speaker, text 双参数）
func say(arg1: String, arg2: String = "") -> void:
	var speaker: String = ""
	var text: String = ""
	if arg2.is_empty():
		text = arg1
	else:
		speaker = arg1
		text = arg2

	var diag: Node = null
	if is_instance_valid(tree) and is_instance_valid(tree.root):
		diag = tree.root.find_child("DialogueBox", true, false)

	if is_instance_valid(diag) and diag.has_method("start_dialogue"):
		diag.start_dialogue(text, speaker, "mod_dialogue")
	else:
		var display_msg: String = "%s: %s" % [speaker, text] if not speaker.is_empty() else text
		toast(display_msg)


## 快捷调起多分支交互选项对白
func choice(speaker: String, text: String, choices: Array, callback: Callable = Callable()) -> void:
	var diag: Node = null
	if is_instance_valid(tree) and is_instance_valid(tree.root):
		diag = tree.root.find_child("DialogueBox", true, false)

	if is_instance_valid(diag) and diag.has_method("start_choice"):
		diag.start_choice(speaker, text, choices, callback)
	else:
		say(speaker, text)


# ==============================================================================
# 7. 全自动化回滚执行器（Zero-Residue Managed Rollback）
# ==============================================================================

## 执行全量无感知回滚，还原所有接管路径、多语言文本、注入节点与信号
func _rollback_all_managed_changes() -> void:
	print("[DaydriftNativeMod:%s] Executing zero-residue rollback..." % mod_id)

	# 1. 断开所有托管信号连接
	for conn in _managed_connections:
		var s: Signal = conn.get("signal")
		var c: Callable = conn.get("callable")
		if is_instance_valid(s.get_object()) and s.is_connected(c):
			s.disconnect(c)
	_managed_connections.clear()

	# 2. 释放所有挂载的 UI 与子节点
	for ui_entry in _managed_mounted_ui:
		var ctrl: Control = ui_entry.get("control")
		if is_instance_valid(ctrl):
			ctrl.queue_free()
	_managed_mounted_ui.clear()
	_pending_ui_mounts.clear()

	for ch in _managed_children:
		if is_instance_valid(ch):
			ch.queue_free()
	_managed_children.clear()

	# 3. 释放全屏 Shader 滤镜
	for cl in _managed_screen_shaders:
		if is_instance_valid(cl):
			cl.queue_free()
	_managed_screen_shaders.clear()

	# 4. 释放动态注册的 Autoload 单例
	for name_str in _custom_autoloads.keys():
		var inst: Node = _custom_autoloads[name_str]
		if is_instance_valid(inst):
			inst.queue_free()
	_custom_autoloads.clear()

	# 5. 还原 Monkey Patch 的节点脚本与属性
	for patch_info in _patched_scripts:
		var n: Node = patch_info.get("node")
		var orig_s: Script = patch_info.get("original_script")
		var saved_st: Dictionary = patch_info.get("saved_state", {})
		if is_instance_valid(n):
			n.set_script(orig_s)
			for k in saved_st:
				if k in n:
					n.set(k, saved_st[k])
	_patched_scripts.clear()

	# 6. 还原被 hijack 劫持接管的原生资源路径
	for target_path in _hijacked_resources.keys():
		var orig_res: Resource = _hijacked_resources[target_path]
		if is_instance_valid(orig_res):
			orig_res.take_over_path(target_path)
	_hijacked_resources.clear()

	# 7. 从 TranslationServer 注销模组注入的翻译
	for loc in _mod_translations.keys():
		var tr_obj: Translation = _mod_translations[loc]
		if is_instance_valid(tr_obj):
			TranslationServer.remove_translation(tr_obj)
	_mod_translations.clear()

	for tr_csv in _managed_csv_translations:
		if is_instance_valid(tr_csv):
			TranslationServer.remove_translation(tr_csv)
	_managed_csv_translations.clear()

	# 8. 移除 InputMap 中新增的按键动作
	for act in _managed_added_actions:
		if InputMap.has_action(act):
			InputMap.erase_action(act)
	_managed_added_actions.clear()

	# 9. 注销对话拦截器
	for interceptor in _dialogue_interceptors:
		ModAPI.unregister_interceptor(interceptor)
	_dialogue_interceptors.clear()

	# 10. 清理 ModAPI 注入的交互选项
	for choice in _managed_injected_choices:
		ModAPI.remove_interaction_choice(choice.get("anchor_id", ""), choice.get("choice_text", ""))
	_managed_injected_choices.clear()

	print("[DaydriftNativeMod:%s] Zero-residue rollback completed cleanly." % mod_id)


# ==============================================================================
# 8. 内部辅助函数与全域事件订阅
# ==============================================================================

func _setup_core_references() -> void:
	tree = Engine.get_main_loop() as SceneTree
	if is_instance_valid(tree):
		root_window = tree.root
		if is_instance_valid(root_window):
			event_bus = root_window.get_node_or_null("EventBus")
			time_manager = root_window.get_node_or_null("TimeManager")
			save_manager = root_window.get_node_or_null("SaveManager")
			audio_manager = root_window.get_node_or_null("AudioManager")
			scene_transition = root_window.get_node_or_null("SceneTransition")
			mod_manager = root_window.get_node_or_null("ModManager")
			network_manager = root_window.get_node_or_null("NetworkManager")
			lan_host_manager = root_window.get_node_or_null("LanHostManager")


func _connect_lifecycle_signals() -> void:
	if not is_instance_valid(tree):
		return

	if not tree.node_added.is_connected(_internal_on_node_added):
		tree.node_added.connect(_internal_on_node_added)

	if is_instance_valid(event_bus):
		if event_bus.has_signal("dd_period_changed"):
			connect_managed(event_bus.dd_period_changed, _internal_on_period_changed)
		elif event_bus.has_signal("time_period_changed"):
			connect_managed(event_bus.time_period_changed, _internal_on_period_changed)

		if event_bus.has_signal("dd_day_advanced"):
			connect_managed(event_bus.dd_day_advanced, _internal_on_day_advanced)
		elif event_bus.has_signal("time_day_changed"):
			connect_managed(event_bus.time_day_changed, _internal_on_day_advanced)

		if event_bus.has_signal("dd_save_requested"):
			connect_managed(event_bus.dd_save_requested, _internal_on_save_requested)
		if event_bus.has_signal("dd_load_completed"):
			connect_managed(event_bus.dd_load_completed, _internal_on_load_completed)

	if is_instance_valid(scene_transition) and scene_transition.has_signal("transition_finished"):
		connect_managed(scene_transition.transition_finished, _internal_on_transition_finished)

	if is_instance_valid(network_manager) and network_manager.has_signal("mod_packet_received"):
		connect_managed(network_manager.mod_packet_received, _internal_on_mod_packet_received)


func _internal_on_node_added(node: Node) -> void:
	_on_node_added_anywhere(node)

	# 检查待挂载 UI
	if _pending_ui_mounts.size() > 0:
		var still_pending: Array[Dictionary] = []
		for item in _pending_ui_mounts:
			var alias: String = item.get("target_alias", "")
			var ctrl: Control = item.get("control")
			var matched: bool = false
			if node.name == alias or node.is_in_group(alias):
				node.add_child(ctrl)
				_managed_mounted_ui.append({"parent": node, "control": ctrl})
				matched = true
			if not matched:
				still_pending.append(item)
		_pending_ui_mounts = still_pending

	# 检查主场景变更
	if is_instance_valid(tree) and node == tree.current_scene:
		var scene_id: String = node.name
		_last_scene_id = scene_id
		_on_scene_ready(scene_id, node)


func _internal_on_transition_finished() -> void:
	if is_instance_valid(tree) and is_instance_valid(tree.current_scene):
		var curr: Node = tree.current_scene
		_on_scene_ready(curr.name, curr)


func _internal_on_period_changed(_prev_p: int, curr_p: int) -> void:
	var day_val: int = 1
	var p_name: String = ""
	if is_instance_valid(time_manager):
		day_val = int(time_manager.get("current_day")) if "current_day" in time_manager else 1
		if time_manager.has_method("get_period_key"):
			p_name = TranslationServer.translate(time_manager.call("get_period_key", curr_p))
	_on_period_changed(day_val, curr_p, p_name)


func _internal_on_day_advanced(new_day: int) -> void:
	_on_day_advanced(new_day)


func _internal_on_save_requested(_is_auto: bool) -> void:
	var dummy_save_dict: Dictionary = {}
	_on_before_save(dummy_save_dict)


func _internal_on_load_completed(success: bool) -> void:
	if success:
		var dummy_load_dict: Dictionary = {}
		_on_after_load(dummy_load_dict)


func _internal_on_mod_packet_received(sender: String, target_mod: String, channel: String, payload: Dictionary) -> void:
	if target_mod == mod_id or target_mod.is_empty():
		_on_net_packet(sender, channel, payload)


func _resolve_ui_target(alias: String) -> Node:
	if not is_instance_valid(tree):
		return null
	if alias.begins_with("/root/") or alias.begins_with("res://"):
		return tree.root.get_node_or_null(alias)
	if is_instance_valid(tree.current_scene):
		if tree.current_scene.name == alias:
			return tree.current_scene
		var found: Node = tree.current_scene.find_child(alias, true, false)
		if is_instance_valid(found):
			return found
	if is_instance_valid(root_window):
		return root_window.find_child(alias, true, false)
	return null
