## login_screen.gd — 已移除登录/注册模块
## 游戏启动后直接进入主菜单，无需登录。
extends CanvasLayer
signal login_completed(username: String, is_guest: bool)
