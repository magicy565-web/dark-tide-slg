## panel_manager.gd — Central panel visibility manager.
## Enforces mutual exclusivity for modal panels (layers 5-11).
## Provides open/close API and centralized ESC handling.
## Autoload: PanelManager
extends Node

# ═══════════════════════════════════════════════════════════════
#                       SIGNALS
# ═══════════════════════════════════════════════════════════════

signal panel_opened(panel_name: String)
signal panel_closed(panel_name: String)

# ═══════════════════════════════════════════════════════════════
#                        STATE
# ═══════════════════════════════════════════════════════════════

## All registered panels: { name -> node_ref }
var _panels: Dictionary = {}

## Which panel names are "modal" (only one visible at a time)
var _modal_panels: Array[String] = []

## Currently open modal panel name (or "" if none)
var _current_modal: String = ""

# ═══════════════════════════════════════════════════════════════
#                    REGISTRATION API
# ═══════════════════════════════════════════════════════════════

## Register a panel. If is_modal=true, it participates in mutual exclusion.
func register_panel(panel_name: String, node: Node, is_modal: bool = false) -> void:
	_panels[panel_name] = node
	if is_modal and panel_name not in _modal_panels:
		_modal_panels.append(panel_name)


## Unregister a panel (e.g., when freed).
func unregister_panel(panel_name: String) -> void:
	_panels.erase(panel_name)
	_modal_panels.erase(panel_name)
	if _current_modal == panel_name:
		_current_modal = ""

# ═══════════════════════════════════════════════════════════════
#                     OPEN / CLOSE API
# ═══════════════════════════════════════════════════════════════

## Open a panel by name. For modal panels, auto-closes the current modal first.
## Extra args are forwarded to show_panel() if it accepts parameters.
func open_panel(panel_name: String, args: Array = []) -> void:
	if panel_name not in _panels:
		push_warning("PanelManager: unknown panel '%s'" % panel_name)
		return

	var node = _panels[panel_name]
	if not is_instance_valid(node):
		push_warning("PanelManager: panel '%s' is no longer valid" % panel_name)
		_panels.erase(panel_name)
		return

	# Mutual exclusion for modal panels
	if panel_name in _modal_panels and _current_modal != "" and _current_modal != panel_name:
		close_panel(_current_modal)

	# Call show_panel with or without args
	if node.has_method("show_panel"):
		if args.size() > 0:
			node.callv("show_panel", args)
		else:
			node.show_panel()
	else:
		node.visible = true

	if panel_name in _modal_panels:
		_current_modal = panel_name
	panel_opened.emit(panel_name)


## Close a panel by name.
func close_panel(panel_name: String) -> void:
	if panel_name not in _panels:
		return

	var node = _panels[panel_name]
	if not is_instance_valid(node):
		_panels.erase(panel_name)
		return

	if node.has_method("hide_panel"):
		node.hide_panel()
	else:
		node.visible = false

	if _current_modal == panel_name:
		_current_modal = ""
	panel_closed.emit(panel_name)


## Toggle a panel: close if open, open if closed.
func toggle_panel(panel_name: String, args: Array = []) -> void:
	if is_panel_open(panel_name):
		close_panel(panel_name)
	else:
		open_panel(panel_name, args)

# ═══════════════════════════════════════════════════════════════
#                      QUERY API
# ═══════════════════════════════════════════════════════════════

## Check if a specific panel is currently visible.
func is_panel_open(panel_name: String) -> bool:
	if panel_name not in _panels:
		return false
	var node = _panels[panel_name]
	if not is_instance_valid(node):
		return false
	if node.has_method("is_panel_visible"):
		return node.is_panel_visible()
	return node.visible


## Check if any modal panel is open.
func is_any_modal_open() -> bool:
	for pname in _modal_panels:
		if is_panel_open(pname):
			return true
	return false


## Get the name of the currently open modal panel (or "").
func get_current_modal() -> String:
	return _current_modal


## Get all registered panel names.
func get_registered_panels() -> Array:
	return _panels.keys()
