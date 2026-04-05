## game_logger.gd - 暗潮 SLG 统一日志系统
## 替代全项目散落的 print() 调用，提供分级日志输出。
## 在发布版本中可通过设置 LOG_LEVEL 关闭调试日志。
extends Node

enum Level { DEBUG = 0, INFO = 1, WARN = 2, ERROR = 3, NONE = 4 }

## 当前日志级别，发布时设为 WARN 或 NONE 以关闭调试输出
var LOG_LEVEL: int = Level.DEBUG

## 是否同时通过 EventBus.debug_log 广播（供 UI 调试面板接收）
var broadcast_to_event_bus: bool = true


func debug(msg: String) -> void:
	if LOG_LEVEL <= Level.DEBUG:
		print("[DEBUG] %s" % msg)
		_broadcast("DEBUG", msg)


func info(msg: String) -> void:
	if LOG_LEVEL <= Level.INFO:
		print("[INFO] %s" % msg)
		_broadcast("INFO", msg)


func warn(msg: String) -> void:
	if LOG_LEVEL <= Level.WARN:
		push_warning("[WARN] %s" % msg)
		print("[WARN] %s" % msg)
		_broadcast("WARN", msg)


func error(msg: String) -> void:
	if LOG_LEVEL <= Level.ERROR:
		push_error("[ERROR] %s" % msg)
		print("[ERROR] %s" % msg)
		_broadcast("ERROR", msg)


func _broadcast(level: String, msg: String) -> void:
	if broadcast_to_event_bus and is_instance_valid(EventBus):
		EventBus.debug_log.emit(level, msg)
