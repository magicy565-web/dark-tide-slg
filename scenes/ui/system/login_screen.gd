## login_screen.gd — 模拟登录界面
## 提供账号登录、注册、游客进入三种入口
## 登录成功后发出 login_completed 信号，由 main.gd 接收并切换到主菜单
## 版本: v1.0.0  作者: Manus AI
extends CanvasLayer

# ═══════════════════════════════════════════════════════════════
#  信号
# ═══════════════════════════════════════════════════════════════
signal login_completed(username: String, is_guest: bool)

# ═══════════════════════════════════════════════════════════════
#  UI 节点引用
# ═══════════════════════════════════════════════════════════════
var root: Control
var _tab_bar: HBoxContainer
var _login_panel: VBoxContainer
var _register_panel: VBoxContainer

# 登录面板控件
var _login_user_edit: LineEdit
var _login_pass_edit: LineEdit
var _login_btn: Button
var _guest_btn: Button
var _login_msg: Label

# 注册面板控件
var _reg_user_edit: LineEdit
var _reg_pass_edit: LineEdit
var _reg_pass2_edit: LineEdit
var _reg_btn: Button
var _reg_msg: Label

# 已登录状态面板
var _logged_panel: VBoxContainer
var _logged_label: Label
var _enter_btn: Button
var _logout_btn: Button

# 当前 Tab
var _current_tab: int = 0  # 0=登录, 1=注册

# ═══════════════════════════════════════════════════════════════
#  生命周期
# ═══════════════════════════════════════════════════════════════
func _ready() -> void:
	layer = 100  # 最顶层
	_build_ui()
	_connect_login_manager()
	_refresh_state()

func _connect_login_manager() -> void:
	LoginManager.login_success.connect(_on_login_success)
	LoginManager.login_failed.connect(_on_login_failed)
	LoginManager.register_success.connect(_on_register_success)
	LoginManager.register_failed.connect(_on_register_failed)
	LoginManager.logout_done.connect(_on_logout_done)

# ═══════════════════════════════════════════════════════════════
#  构建 UI
# ═══════════════════════════════════════════════════════════════
func _build_ui() -> void:
	root = Control.new()
	root.name = "LoginRoot"
	root.anchor_right = 1.0
	root.anchor_bottom = 1.0
	root.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(root)

	# 全屏深色背景
	var bg := ColorRect.new()
	bg.anchor_right = 1.0
	bg.anchor_bottom = 1.0
	bg.color = Color(0.04, 0.04, 0.08, 1.0)
	root.add_child(bg)

	# 标题
	var title := Label.new()
	title.text = "⚓ 暗潮 Dark Tide"
	title.add_theme_font_size_override("font_size", 32)
	title.add_theme_color_override("font_color", Color(0.9, 0.75, 0.3))
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.anchor_left = 0.3
	title.anchor_right = 0.7
	title.anchor_top = 0.08
	title.anchor_bottom = 0.16
	root.add_child(title)

	var subtitle := Label.new()
	subtitle.text = "请登录或以游客身份进入"
	subtitle.add_theme_font_size_override("font_size", 14)
	subtitle.add_theme_color_override("font_color", Color(0.5, 0.5, 0.6))
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subtitle.anchor_left = 0.3
	subtitle.anchor_right = 0.7
	subtitle.anchor_top = 0.16
	subtitle.anchor_bottom = 0.21
	root.add_child(subtitle)

	# 中央卡片容器
	var card := PanelContainer.new()
	card.anchor_left = 0.35
	card.anchor_right = 0.65
	card.anchor_top = 0.22
	card.anchor_bottom = 0.82
	var card_style := StyleBoxFlat.new()
	card_style.bg_color = Color(0.09, 0.09, 0.14, 0.98)
	card_style.border_color = Color(0.4, 0.3, 0.15, 0.9)
	card_style.set_border_width_all(2)
	card_style.set_corner_radius_all(10)
	card_style.set_content_margin_all(20)
	card.add_theme_stylebox_override("panel", card_style)
	root.add_child(card)

	var card_vbox := VBoxContainer.new()
	card_vbox.add_theme_constant_override("separation", 12)
	card.add_child(card_vbox)

	# Tab 切换按钮行
	_tab_bar = HBoxContainer.new()
	_tab_bar.add_theme_constant_override("separation", 4)
	card_vbox.add_child(_tab_bar)

	var tab_login := _make_tab_btn("登  录", 0)
	var tab_reg   := _make_tab_btn("注  册", 1)
	_tab_bar.add_child(tab_login)
	_tab_bar.add_child(tab_reg)

	# 分隔线
	card_vbox.add_child(HSeparator.new())

	# ── 登录面板 ──
	_login_panel = VBoxContainer.new()
	_login_panel.add_theme_constant_override("separation", 10)
	card_vbox.add_child(_login_panel)

	_login_panel.add_child(_make_field_label("用户名"))
	_login_user_edit = _make_line_edit("请输入用户名", false)
	_login_panel.add_child(_login_user_edit)

	_login_panel.add_child(_make_field_label("密  码"))
	_login_pass_edit = _make_line_edit("请输入密码", true)
	_login_panel.add_child(_login_pass_edit)

	_login_panel.add_child(_make_spacer(6))

	_login_btn = _make_primary_btn("登  录")
	_login_btn.pressed.connect(_on_login_pressed)
	_login_panel.add_child(_login_btn)

	var or_label := Label.new()
	or_label.text = "── 或 ──"
	or_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	or_label.add_theme_color_override("font_color", Color(0.4, 0.4, 0.5))
	or_label.add_theme_font_size_override("font_size", 12)
	_login_panel.add_child(or_label)

	_guest_btn = _make_secondary_btn("🚢  游客快速进入")
	_guest_btn.pressed.connect(_on_guest_pressed)
	_login_panel.add_child(_guest_btn)

	_login_msg = _make_msg_label()
	_login_panel.add_child(_login_msg)

	# ── 注册面板 ──
	_register_panel = VBoxContainer.new()
	_register_panel.add_theme_constant_override("separation", 10)
	_register_panel.visible = false
	card_vbox.add_child(_register_panel)

	_register_panel.add_child(_make_field_label("用户名"))
	_reg_user_edit = _make_line_edit("2-20 字符，支持中文/字母/数字", false)
	_register_panel.add_child(_reg_user_edit)

	_register_panel.add_child(_make_field_label("密  码"))
	_reg_pass_edit = _make_line_edit("至少 4 位", true)
	_register_panel.add_child(_reg_pass_edit)

	_register_panel.add_child(_make_field_label("确认密码"))
	_reg_pass2_edit = _make_line_edit("再次输入密码", true)
	_register_panel.add_child(_reg_pass2_edit)

	_register_panel.add_child(_make_spacer(6))

	_reg_btn = _make_primary_btn("注  册")
	_reg_btn.pressed.connect(_on_register_pressed)
	_register_panel.add_child(_reg_btn)

	_reg_msg = _make_msg_label()
	_register_panel.add_child(_reg_msg)

	# ── 已登录面板 ──
	_logged_panel = VBoxContainer.new()
	_logged_panel.add_theme_constant_override("separation", 14)
	_logged_panel.visible = false
	card_vbox.add_child(_logged_panel)

	_logged_label = Label.new()
	_logged_label.text = "欢迎回来！"
	_logged_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_logged_label.add_theme_font_size_override("font_size", 18)
	_logged_label.add_theme_color_override("font_color", Color(0.8, 0.9, 0.6))
	_logged_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_logged_panel.add_child(_logged_label)

	_logged_panel.add_child(_make_spacer(10))

	_enter_btn = _make_primary_btn("▶  进入游戏")
	_enter_btn.pressed.connect(_on_enter_game_pressed)
	_logged_panel.add_child(_enter_btn)

	_logout_btn = _make_secondary_btn("切换账号 / 登出")
	_logout_btn.pressed.connect(_on_logout_pressed)
	_logged_panel.add_child(_logout_btn)

# ═══════════════════════════════════════════════════════════════
#  UI 辅助
# ═══════════════════════════════════════════════════════════════
func _make_tab_btn(text: String, tab_id: int) -> Button:
	var btn := Button.new()
	btn.text = text
	btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	btn.custom_minimum_size = Vector2(0, 36)
	btn.pressed.connect(func(): _switch_tab(tab_id))
	return btn

func _make_field_label(text: String) -> Label:
	var lbl := Label.new()
	lbl.text = text
	lbl.add_theme_font_size_override("font_size", 13)
	lbl.add_theme_color_override("font_color", Color(0.65, 0.65, 0.75))
	return lbl

func _make_line_edit(placeholder: String, secret: bool) -> LineEdit:
	var le := LineEdit.new()
	le.placeholder_text = placeholder
	le.secret = secret
	le.custom_minimum_size = Vector2(0, 36)
	le.add_theme_font_size_override("font_size", 14)
	return le

func _make_primary_btn(text: String) -> Button:
	var btn := Button.new()
	btn.text = text
	btn.custom_minimum_size = Vector2(0, 42)
	btn.add_theme_font_size_override("font_size", 15)
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.6, 0.45, 0.1)
	style.set_corner_radius_all(6)
	style.set_content_margin_all(8)
	btn.add_theme_stylebox_override("normal", style)
	var hover_style := style.duplicate()
	hover_style.bg_color = Color(0.75, 0.58, 0.15)
	btn.add_theme_stylebox_override("hover", hover_style)
	return btn

func _make_secondary_btn(text: String) -> Button:
	var btn := Button.new()
	btn.text = text
	btn.custom_minimum_size = Vector2(0, 36)
	btn.add_theme_font_size_override("font_size", 13)
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.18, 0.18, 0.25)
	style.border_color = Color(0.4, 0.4, 0.5)
	style.set_border_width_all(1)
	style.set_corner_radius_all(6)
	style.set_content_margin_all(6)
	btn.add_theme_stylebox_override("normal", style)
	return btn

func _make_msg_label() -> Label:
	var lbl := Label.new()
	lbl.text = ""
	lbl.add_theme_font_size_override("font_size", 12)
	lbl.add_theme_color_override("font_color", Color(0.9, 0.4, 0.4))
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return lbl

func _make_spacer(height: int) -> Control:
	var sp := Control.new()
	sp.custom_minimum_size = Vector2(0, height)
	return sp

# ═══════════════════════════════════════════════════════════════
#  Tab 切换
# ═══════════════════════════════════════════════════════════════
func _switch_tab(tab_id: int) -> void:
	_current_tab = tab_id
	_login_panel.visible = (tab_id == 0)
	_register_panel.visible = (tab_id == 1)
	_login_msg.text = ""
	_reg_msg.text = ""

# ═══════════════════════════════════════════════════════════════
#  状态刷新
# ═══════════════════════════════════════════════════════════════
func _refresh_state() -> void:
	if LoginManager.is_logged_in:
		_tab_bar.visible = false
		_login_panel.visible = false
		_register_panel.visible = false
		_logged_panel.visible = true
		var info := LoginManager.get_user_info()
		var uname: String = info.get("username", "")
		var guest: bool = info.get("is_guest", false)
		if guest:
			_logged_label.text = "游客模式\n%s\n\n点击进入游戏" % uname
		else:
			var play_sec: int = info.get("play_time", 0)
			var play_min: int = play_sec / 60
			_logged_label.text = "欢迎回来！\n%s\n\n累计游戏时间: %d 分钟" % [uname, play_min]
	else:
		_tab_bar.visible = true
		_logged_panel.visible = false
		_switch_tab(0)

# ═══════════════════════════════════════════════════════════════
#  按钮回调
# ═══════════════════════════════════════════════════════════════
func _on_login_pressed() -> void:
	_login_msg.text = ""
	_login_msg.add_theme_color_override("font_color", Color(0.9, 0.4, 0.4))
	var user := _login_user_edit.text.strip_edges()
	var pwd := _login_pass_edit.text
	if user.is_empty():
		_login_msg.text = "请输入用户名"
		return
	LoginManager.login(user, pwd)

func _on_guest_pressed() -> void:
	LoginManager.login_as_guest()

func _on_register_pressed() -> void:
	_reg_msg.text = ""
	_reg_msg.add_theme_color_override("font_color", Color(0.9, 0.4, 0.4))
	var user  := _reg_user_edit.text.strip_edges()
	var pwd  := _reg_pass_edit.text
	var pass2 := _reg_pass2_edit.text
	if pwd != pass2:
		_reg_msg.text = "两次输入的密码不一致"
		return
	LoginManager.register(user, pwd)

func _on_enter_game_pressed() -> void:
	root.visible = false
	login_completed.emit(LoginManager.current_user, LoginManager.is_guest)

func _on_logout_pressed() -> void:
	LoginManager.logout()

# ═══════════════════════════════════════════════════════════════
#  LoginManager 信号回调
# ═══════════════════════════════════════════════════════════════
func _on_login_success(username: String, guest: bool) -> void:
	_refresh_state()
	# 登录成功后稍作延迟自动进入游戏
	await get_tree().create_timer(0.5).timeout
	_on_enter_game_pressed()

func _on_login_failed(reason: String) -> void:
	_login_msg.text = "❌ " + reason

func _on_register_success(username: String) -> void:
	_reg_msg.add_theme_color_override("font_color", Color(0.4, 0.9, 0.4))
	_reg_msg.text = "✅ 注册成功！正在自动登录..."
	# 注册后自动登录
	LoginManager.login(username, _reg_pass_edit.text)  # auto-login after register

func _on_register_failed(reason: String) -> void:
	_reg_msg.text = "❌ " + reason

func _on_logout_done() -> void:
	_refresh_state()
