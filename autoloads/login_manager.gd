## login_manager.gd — 模拟登录管理器 (Mock Login System)
## Autoload 单例: LoginManager
## 功能:
##   - 本地账号注册 / 登录 / 登出
##   - 账号数据持久化 (user://login_accounts.json)
##   - 会话 Token 模拟 (SHA256 哈希)
##   - 游客模式快速进入
##   - 信号通知登录状态变化
## 版本: v1.0.0  作者: Manus AI
extends Node

# ═══════════════════════════════════════════════════════════════
#  信号
# ═══════════════════════════════════════════════════════════════
signal login_success(username: String, is_guest: bool)
signal login_failed(reason: String)
signal logout_done()
signal register_success(username: String)
signal register_failed(reason: String)

# ═══════════════════════════════════════════════════════════════
#  常量
# ═══════════════════════════════════════════════════════════════
const ACCOUNTS_PATH := "user://login_accounts.json"
const SESSION_PATH  := "user://login_session.json"
const MAX_USERNAME_LEN := 20
const MIN_PASSWORD_LEN := 4
const GUEST_PREFIX     := "游客_"

# ═══════════════════════════════════════════════════════════════
#  状态
# ═══════════════════════════════════════════════════════════════
var is_logged_in: bool = false
var current_user: String = ""
var current_token: String = ""
var is_guest: bool = false

var _accounts: Dictionary = {}   # { username: { password_hash, created_at, last_login, play_time } }

# ═══════════════════════════════════════════════════════════════
#  生命周期
# ═══════════════════════════════════════════════════════════════
func _ready() -> void:
	_load_accounts()
	_try_restore_session()
	GameLogger.info("[LoginManager] 初始化完成，已注册账号数: %d" % _accounts.size())

# ═══════════════════════════════════════════════════════════════
#  公共 API
# ═══════════════════════════════════════════════════════════════

## 注册新账号
func register(username: String, password: String) -> void:
	username = username.strip_edges()
	var err := _validate_username(username)
	if err != "":
		register_failed.emit(err)
		return
	if password.length() < MIN_PASSWORD_LEN:
		register_failed.emit("密码至少需要 %d 位" % MIN_PASSWORD_LEN)
		return
	if _accounts.has(username):
		register_failed.emit("用户名 '%s' 已被注册" % username)
		return
	var now := Time.get_datetime_string_from_system()
	_accounts[username] = {
		"password_hash": _hash_password(password),
		"created_at": now,
		"last_login": "",
		"play_time": 0,
	}
	_save_accounts()
	GameLogger.info("[LoginManager] 注册成功: %s" % username)
	register_success.emit(username)

## 登录
func login(username: String, password: String) -> void:
	username = username.strip_edges()
	if not _accounts.has(username):
		login_failed.emit("账号 '%s' 不存在" % username)
		return
	var acc: Dictionary = _accounts[username]
	if acc.get("password_hash", "") != _hash_password(password):
		login_failed.emit("密码错误")
		return
	_do_login(username, false)

## 游客登录（随机生成游客名）
func login_as_guest() -> void:
	var guest_name := GUEST_PREFIX + str(randi() % 9000 + 1000)
	_do_login(guest_name, true)

## 登出
func logout() -> void:
	if not is_logged_in:
		return
	_update_play_time()
	var old_user := current_user
	is_logged_in = false
	current_user = ""
	current_token = ""
	is_guest = false
	_clear_session()
	GameLogger.info("[LoginManager] 已登出: %s" % old_user)
	logout_done.emit()

## 获取当前用户信息
func get_user_info() -> Dictionary:
	if not is_logged_in:
		return {}
	if is_guest:
		return {"username": current_user, "is_guest": true, "play_time": 0}
	var acc: Dictionary = _accounts.get(current_user, {})
	return {
		"username": current_user,
		"is_guest": false,
		"created_at": acc.get("created_at", ""),
		"last_login": acc.get("last_login", ""),
		"play_time": acc.get("play_time", 0),
	}

## 获取所有已注册账号列表（仅用户名）
func get_account_list() -> Array:
	return _accounts.keys()

## 检查账号是否存在
func has_account(username: String) -> bool:
	return _accounts.has(username.strip_edges())

# ═══════════════════════════════════════════════════════════════
#  内部实现
# ═══════════════════════════════════════════════════════════════

func _do_login(username: String, guest: bool) -> void:
	is_logged_in = true
	current_user = username
	is_guest = guest
	current_token = _generate_token(username)
	var now := Time.get_datetime_string_from_system()
	if not guest and _accounts.has(username):
		_accounts[username]["last_login"] = now
		_save_accounts()
	_save_session()
	GameLogger.info("[LoginManager] 登录成功: %s (guest=%s)" % [username, str(guest)])
	login_success.emit(username, guest)

func _validate_username(username: String) -> String:
	if username.length() < 2:
		return "用户名至少需要 2 个字符"
	if username.length() > MAX_USERNAME_LEN:
		return "用户名不能超过 %d 个字符" % MAX_USERNAME_LEN
	if username.begins_with(GUEST_PREFIX):
		return "用户名不能以 '%s' 开头（保留前缀）" % GUEST_PREFIX
	# 只允许字母、数字、中文、下划线
	for c in username:
		var code := c.unicode_at(0)
		var is_alnum := (code >= 48 and code <= 57) or (code >= 65 and code <= 90) or \
						(code >= 97 and code <= 122) or code == 95
		var is_cjk := code >= 0x4E00 and code <= 0x9FFF
		if not is_alnum and not is_cjk:
			return "用户名只能包含字母、数字、中文或下划线"
	return ""

func _hash_password(password: String) -> String:
	# 简单哈希：SHA256 模拟（Godot 内置）
	var ctx := HashingContext.new()
	ctx.start(HashingContext.HASH_SHA256)
	ctx.update(("dark_tide_salt_v1:" + password).to_utf8_buffer())
	var result := ctx.finish()
	return result.hex_encode()

func _generate_token(username: String) -> String:
	var ctx := HashingContext.new()
	ctx.start(HashingContext.HASH_SHA256)
	var raw := username + ":" + str(Time.get_unix_time_from_system()) + ":" + str(randi())
	ctx.update(raw.to_utf8_buffer())
	return ctx.finish().hex_encode()

func _update_play_time() -> void:
	if is_guest or not _accounts.has(current_user):
		return
	var session_data := _load_session_data()
	var login_time: float = session_data.get("login_unix", 0.0)
	if login_time > 0:
		var elapsed: float = Time.get_unix_time_from_system() - login_time
		_accounts[current_user]["play_time"] = \
			_accounts[current_user].get("play_time", 0) + int(elapsed)
		_save_accounts()

# ── 持久化 ──

func _load_accounts() -> void:
	if not FileAccess.file_exists(ACCOUNTS_PATH):
		_accounts = {}
		return
	var f := FileAccess.open(ACCOUNTS_PATH, FileAccess.READ)
	if f == null:
		_accounts = {}
		return
	var json := JSON.new()
	if json.parse(f.get_as_text()) == OK:
		_accounts = json.data if json.data is Dictionary else {}
	f.close()

func _save_accounts() -> void:
	var f := FileAccess.open(ACCOUNTS_PATH, FileAccess.WRITE)
	if f == null:
		push_error("[LoginManager] 无法写入账号文件")
		return
	f.store_string(JSON.stringify(_accounts, "\t"))
	f.close()

func _save_session() -> void:
	var data := {
		"username": current_user,
		"token": current_token,
		"is_guest": is_guest,
		"login_unix": Time.get_unix_time_from_system(),
	}
	var f := FileAccess.open(SESSION_PATH, FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify(data))
		f.close()

func _clear_session() -> void:
	if FileAccess.file_exists(SESSION_PATH):
		DirAccess.remove_absolute(SESSION_PATH)

func _load_session_data() -> Dictionary:
	if not FileAccess.file_exists(SESSION_PATH):
		return {}
	var f := FileAccess.open(SESSION_PATH, FileAccess.READ)
	if f == null:
		return {}
	var json := JSON.new()
	var result: Dictionary = {}
	if json.parse(f.get_as_text()) == OK and json.data is Dictionary:
		result = json.data
	f.close()
	return result

func _try_restore_session() -> void:
	var data := _load_session_data()
	if data.is_empty():
		return
	var username: String = data.get("username", "")
	var token: String    = data.get("token", "")
	var guest: bool      = data.get("is_guest", false)
	if username.is_empty() or token.is_empty():
		return
	# 非游客账号需验证账号存在
	if not guest and not _accounts.has(username):
		_clear_session()
		return
	is_logged_in = true
	current_user = username
	current_token = token
	is_guest = guest
	GameLogger.debug("[LoginManager] 会话恢复: %s (guest=%s)" % [username, str(guest)])
