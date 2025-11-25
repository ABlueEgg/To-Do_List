extends Control

# --- node refs
@onready var title_edit = $TitleEdit
@onready var add_task_button = $"add task button"
@onready var menu_button = $MenuButton
@onready var task_scroll = $ScrollContainer
@onready var tasks_container = $ScrollContainer/TaskContainer
@onready var notifications_popup = $PopupPanel
@onready var reminder_dialog = $AcceptDialog
@onready var notification_timer = $Timer

# default minutes for notification
var notification_delay_minutes: int = 10

func _ready():
	# --- Add Task button setup ---
	add_task_button.text = "Add Task"
	add_task_button.pressed.connect(_on_add_task_pressed)

	# --- MenuButton + PopupMenu setup ---
	var popup = menu_button.get_popup()
	# make items bigger
	popup.add_theme_font_size_override("font_size", 30)
	popup.add_item("Settings", 0)
	popup.add_item("Notifications", 1)
	popup.add_item("Share", 2)
	popup.id_pressed.connect(_on_menu_option_selected)

	# --- Build notifications popup controls ---
	#notifications_popup.connect("gui_input", Callable(self, "_handle_enter_on_notifications_popup"))
	_build_notifications_popup()

	# --- Timer setup ---
	notification_timer.one_shot = true
	notification_timer.timeout.connect(_on_notification_timeout)

	# --- Reminder dialog hidden at start ---
	reminder_dialog.hide()
	# make the reminder dialog font larger
	apply_large_font(notifications_popup, 30)
	apply_large_font(reminder_dialog, 30)

# ------------------------
# Add-task behavior
# ------------------------
func _on_add_task_pressed():
	var new_task_line_edit = _add_task("")
	print("button pressed")
	
	if new_task_line_edit:
		new_task_line_edit.grab_focus()
		new_task_line_edit.select_all()

# ------------------------
# When check toggled: move row to bottom and lock editing
# ------------------------
func _on_task_toggled(pressed: bool, row: Node) -> void:
	if not is_instance_valid(row) or row.get_parent() != tasks_container:
		return

	# Assuming LineEdit is the second child (index 1) of the HBoxContainer (row)
	var line_edit = row.get_child(1) if row.get_child_count() > 1 else null

	if pressed:
		# Move to the bottom of the list
		var last_index = tasks_container.get_child_count() - 1
		tasks_container.move_child(row, last_index)

		if line_edit:
			line_edit.editable = false
			line_edit.focus_mode = Control.FOCUS_NONE # Prevents cursor from appearing
	else:
		tasks_container.move_child(row, 1) 

		if line_edit:
			line_edit.editable = true
			line_edit.focus_mode = Control.FOCUS_ALL # Allows editing again

func _add_task(task_text: String) -> LineEdit:
	var row = HBoxContainer.new()
	row.name = "task_row_%d" % tasks_container.get_child_count()
	
	const FONT_SIZE = 35
	
	# --- CheckBox Setup (for size increase) ---
	var cb = CheckBox.new()
	cb.toggled.connect(Callable(self, "_on_task_toggled").bind(row))
	cb.custom_minimum_size = Vector2(FONT_SIZE + 10, FONT_SIZE + 10) 
	cb.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	cb.add_theme_font_size_override("font_size", FONT_SIZE)
	
	# --- LineEdit Setup ---
	var line = LineEdit.new()
	line.text = task_text
	line.editable = true
	# Remove SIZE_FILL flag to allow auto-scaling to control the width
	line.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN 
	line.add_theme_font_size_override("font_size", FONT_SIZE) 
	line.custom_minimum_size.y = FONT_SIZE + 10
	line.text_submitted.connect(Callable(self, "_on_task_edit_finished").bind(line))

	# Get the font used in the LineEdit
	# This is a bit safer as it gets the default LineEdit font
	var font: Font = line.get_theme_font("font", "LineEdit") 

	# Connect text_changed signal to the helper function and bind the LineEdit and Font
	line.text_changed.connect(Callable(self, "_scale_line_edit_to_text").bind(line, font))
	
	# Initial scale call for placeholder/default text
	_scale_line_edit_to_text(task_text, line, font)

	row.add_child(cb)
	row.add_child(line)

	# Insert at the top
	tasks_container.add_child(row)        # Add the new row
	tasks_container.move_child(row, 0)    # Move it to index 0 (top)

	return line # Return the LineEdit for focus

# ------------------------
# Menu handling
# ------------------------
func _on_menu_option_selected(id: int) -> void:
	match id:
		0: _open_settings()
		1: notifications_popup.popup_centered()
		2: _share_list()

func _open_settings():
	print("Open settings (not implemented)")


# ------------------------
# Notification popup building
# ------------------------
func _build_notifications_popup() -> void:
	# remove old children
	for child in notifications_popup.get_children():
		child.queue_free()

	var v = VBoxContainer.new()
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	v.size_flags_vertical = Control.SIZE_EXPAND_FILL
	notifications_popup.add_child(v)

	var lbl = Label.new()
	lbl.text = "Notify me in (minutes):"
	v.add_child(lbl)

	var minutes_input = LineEdit.new()
	minutes_input.text = str(notification_delay_minutes)
	v.add_child(minutes_input)

	# --- Connect Enter on the LineEdit ---
	minutes_input.text_submitted.connect(_on_set_notification_pressed_from_lineedit)

	var set_btn = Button.new()
	set_btn.text = "Set Notification"
	set_btn.pressed.connect(_on_set_notification_pressed_from_lineedit)
	v.add_child(set_btn)

	apply_large_font(notifications_popup, 24)



func _on_set_notification_pressed():
	notifications_popup.hide()
	notification_timer.start(notification_delay_minutes * 60.0)
	print("Notification set for %d minutes" % notification_delay_minutes)


# ------------------------
# Timer timeout — show reminder popup & request attention
# ------------------------
func _on_notification_timeout():
	DisplayServer.window_request_attention()
	call_deferred("_ensure_window_visible_and_popup")

func _ensure_window_visible_and_popup():
	get_tree().root.visible = true
	reminder_dialog.dialog_text = "Reminder: your to-do list notification"
	reminder_dialog.popup_centered()
	reminder_dialog.move_to_foreground()
	print("Notification triggered and popup shown.")


# ------------------------
# Share list
# ------------------------
func _share_list():
	var arr : Array = []
	for row in tasks_container.get_children():
		if row.get_child_count() < 2:
			continue
		var t = row.get_child(1).text
		var done = row.get_child(0).button_pressed
		var status = "Done" if done else "Pending"
		arr.append("%s [%s]" % [t, status])
	print("Sharing List:\n" + "\n".join(arr))

func scale_up_tasks_container(size: int = 24):
	for row in tasks_container.get_children():
		if row is HBoxContainer:
			for child in row.get_children():
				if child is CheckBox:
					child.add_theme_font_size_override("font_size", size)
					child.custom_minimum_size = Vector2(0, size + 10)
				elif child is LineEdit:
					child.add_theme_font_size_override("font_size", size)
					child.custom_minimum_size = Vector2(0, size + 10)

# Recursively apply larger fonts to Controls under a node 
func apply_large_font(node: Node, size: int = 24) -> void:
	if node is Control: 
		node.add_theme_font_size_override("font_size", size)

	# Also handle sub-controls like the LineEdit inside SpinBox
	if node is SpinBox:
		var line_edit = node.get_line_edit()
		if line_edit:
			line_edit.add_theme_font_size_override("font_size", size)

	for child in node.get_children():
		apply_large_font(child, size)
		
# ------------------------
# LineEdit Auto-Scaling Logic
# ------------------------
func _scale_line_edit_to_text(new_text: String, line_edit: LineEdit, font: Font) -> void:
	if not is_instance_valid(font):
		return
		
	var font_size: int = line_edit.get_theme_font_size("font_size")
	var stylebox: StyleBox = line_edit.get_theme_stylebox("normal")
	var padding_x = stylebox.get_margin(SIDE_LEFT) + stylebox.get_margin(SIDE_RIGHT)
	
	var text_width = font.get_string_size(new_text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x

	var final_width = text_width + padding_x + 10.0 # 10 is a small buffer

	final_width = max(final_width, 150.0) 

	var current_height = line_edit.custom_minimum_size.y if line_edit.custom_minimum_size.y > 0 else line_edit.size.y
	line_edit.custom_minimum_size = Vector2(final_width, current_height)

func _on_task_edit_finished(_text, line_edit: LineEdit):
	line_edit.release_focus()
	if line_edit.text.strip_edges() == "":
		var row = line_edit.get_parent()
		if is_instance_valid(row) and row.get_parent() == tasks_container:
			row.queue_free()
			
					
func _on_set_notification_pressed_from_lineedit(line_edit: LineEdit = null):
	var v_container = notifications_popup.get_child(0)
	var minutes_input = v_container.get_child(1) if v_container.get_child_count() >= 2 else null
	if minutes_input and minutes_input is LineEdit:
		var val = int(minutes_input.text.strip_edges())
		val = clamp(val, 1, 1440)
		notification_delay_minutes = val
		notification_timer.start(notification_delay_minutes * 60.0)
		print("Notification set for %d minutes" % notification_delay_minutes)
		notifications_popup.hide()
