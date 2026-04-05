## test_runner_login.gd — 测试运行器入口
## 在图形模式下作为独立场景运行，加载 test_login_and_run.gd 并执行
## 用法: godot422 --path /path/to/project --scene res://tests/test_runner_login.tscn
extends Node

func _ready() -> void:
	print("[TestRunner] 启动登录+运行测试套件...")
	var test_script = load("res://tests/test_login_and_run.gd")
	if test_script == null:
		push_error("[TestRunner] 无法加载测试脚本")
		get_tree().quit(1)
		return
	var test_node := Node.new()
	test_node.set_script(test_script)
	test_node.name = "TestLoginAndRun"
	add_child(test_node)
	# 等待测试完成后退出
	await get_tree().create_timer(30.0).timeout
	print("[TestRunner] 测试超时，强制退出")
	get_tree().quit(0)
