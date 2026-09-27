extends CanvasLayer
## Always-processing UI; the entire gameplay tree and its audio pause underneath it.
var mission
var panel: Control
var retry: Button
var status: Label
var confirmation: ConfirmationDialog
var was_captured := false
var is_open := false

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 20
	var root := Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)
	panel = PanelContainer.new()
	panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var theme := Theme.new()
	theme.default_font = preload("res://assets/fonts/NotoSansCJKsc-Regular.otf")
	theme.default_font_size = 18
	# Dim the frozen game so HUD subtitles never read through the menu.
	theme.set_stylebox("panel","PanelContainer",_box(Color(.015,.03,.035,.84),0))
	for state in [["normal",Color("17323a")],["hover",Color("22505a")],["pressed",Color("2f6f73")],["focus",Color("22505a")],["disabled",Color("141d20")]]:
		theme.set_stylebox(state[0],"Button",_box(state[1],6))
	theme.set_color("font_disabled_color","Button",Color("5d6d70"))
	theme.set_constant("h_separation","CheckBox",10)
	panel.theme = theme
	root.add_child(panel)
	var center := CenterContainer.new()
	panel.add_child(center)
	var card := PanelContainer.new()
	var card_style := _box(Color("0c1a1e"),8)
	card_style.border_width_left = 4
	card_style.border_color = Color("5fd3bc")
	card_style.content_margin_left = 34
	card_style.content_margin_right = 34
	card_style.content_margin_top = 22
	card_style.content_margin_bottom = 22
	card.add_theme_stylebox_override("panel",card_style)
	center.add_child(card)
	var column := VBoxContainer.new()
	column.custom_minimum_size.x = 560
	column.add_theme_constant_override("separation",7)
	card.add_child(column)
	_label(column,"行动已暂停",28)
	_label(column,"战斗、过场、换弹和配音均已暂停。",17)
	_button(column,"继续行动（Esc）",close_menu)
	retry = _button(column,"从最近检查点重试",_retry)
	_button(column,"从本章开头重新开始",func(): confirmation.popup_centered(Vector2i(460,180)))
	_slider(column,"鼠标灵敏度",.0005,.01,.0001,"sensitivity")
	_slider(column,"总音量",0,1,.05,"master")
	_slider(column,"配音音量",0,1,.05,"voice")
	_slider(column,"字幕字号",14,24,1,"subtitle_size")
	var toggles := GridContainer.new()
	toggles.columns = 2
	toggles.add_theme_constant_override("h_separation",28)
	column.add_child(toggles)
	for item in [["显示对白字幕","subtitles"],["开启配音","voice_enabled"],["太阳阴影（低配可关闭）","shadows"],["全屏显示","fullscreen"]]:
		var box := CheckBox.new()
		box.text = item[0]
		box.button_pressed = mission.store.preferences[item[1]]
		box.toggled.connect(_set_preference.bind(item[1]))
		toggles.add_child(box)
	status = _label(column,"",15)
	status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	confirmation = ConfirmationDialog.new()
	confirmation.title = "重新开始本章？"
	confirmation.dialog_text = "当前阶段进度将丢失，新的行动会覆盖检查点。"
	confirmation.ok_button_text = "重新开始"
	confirmation.cancel_button_text = "取消"
	confirmation.theme = theme
	confirmation.confirmed.connect(_restart)
	root.add_child(confirmation)
	panel.hide()

func _box(color: Color, radius: int) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = color
	box.set_corner_radius_all(radius)
	box.content_margin_top = 6
	box.content_margin_bottom = 6
	box.content_margin_left = 10
	box.content_margin_right = 10
	return box

func _label(parent: Node, text: String, size: int) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size",size)
	parent.add_child(label)
	return label

func _button(parent: Node, text: String, action: Callable) -> Button:
	var button := Button.new()
	button.text = text
	button.pressed.connect(action)
	parent.add_child(button)
	return button

func _slider(parent: Node, title: String, minimum: float, maximum: float, step: float, key: String) -> void:
	var row := HBoxContainer.new()
	parent.add_child(row)
	var label := _label(row,title,18)
	label.custom_minimum_size.x = 150
	var slider := HSlider.new()
	slider.custom_minimum_size = Vector2(330,25)
	slider.min_value = minimum
	slider.max_value = maximum
	slider.step = step
	slider.value = mission.store.preferences[key]
	slider.value_changed.connect(_set_preference.bind(key))
	row.add_child(slider)
	var readout := _label(row,_format(key,slider.value),16)
	readout.custom_minimum_size.x = 60
	readout.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	slider.value_changed.connect(func(value: float): readout.text = _format(key,value))

func _format(key: String, value: float) -> String:
	if key == "subtitle_size":
		return "%d" % int(value)
	if key == "sensitivity":
		return "%.1f" % (value*1000.0)
	return "%d%%" % roundi(value*100.0)

func _set_preference(value: Variant, key: String) -> void:
	mission.store.preferences[key] = value
	mission.apply_preferences()

func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.physical_keycode == KEY_ESCAPE:
		if confirmation.visible:
			confirmation.hide()
		elif is_open:
			close_menu()
		else:
			open_menu()
		get_viewport().set_input_as_handled()

func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_WINDOW_FOCUS_OUT and is_instance_valid(panel) and mission.state in ["active","cinematic"]:
		open_menu()

func open_menu() -> void:
	if is_open:
		return
	is_open = true
	was_captured = Input.mouse_mode == Input.MOUSE_MODE_CAPTURED
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	mission.sound.pause_audio(true)
	get_tree().paused = true
	retry.disabled = mission.store.checkpoint.is_empty()
	status.text = "设置保存在本机。" if mission.store.last_error.is_empty() else mission.store.last_error
	panel.show()

func close_menu() -> void:
	if not is_open:
		return
	confirmation.hide()
	mission.store.save_preferences()
	is_open = false
	panel.hide()
	get_tree().paused = false
	mission.sound.pause_audio(false)
	mission.player._await_action_release = true
	if was_captured and mission.state == "active":
		mission.player._set_look(true)
	if not mission.store.last_error.is_empty():
		mission.hud.notice = mission.store.last_error
		mission.hud.notice_time = 6

func _retry() -> void:
	close_menu()
	mission.restore_checkpoint()

func _restart() -> void:
	close_menu()
	mission.new_chapter()

func _exit_tree() -> void:
	if is_open:
		get_tree().paused = false
