# 12_MOD管理文档 —— 《暗潮 Dark Tide》

### 一、MOD系统设计理念
- 支持玩家自定义兵种、英雄、事件、地图
- 基于Godot资源包(.pck)和JSON数据文件
- MOD不修改核心代码，通过数据覆盖实现
- MOD加载顺序：核心数据 → MOD数据（后加载覆盖先加载）

### 二、可MOD化的模块
| 模块 | 文件格式 | 说明 |
|------|---------|------|
| 兵种数据 | troops.json | 新增/修改兵种属性 |
| 英雄数据 | heroes.json | 新增/修改英雄属性和技能 |
| 事件数据 | events.json | 新增随机事件 |
| 道具数据 | items.json | 新增装备和消耗品 |
| 建筑数据 | buildings.json | 新增/修改建筑 |
| 地图预设 | maps/ | 自定义地图布局 |
| 立绘资源 | portraits/ | 替换/新增角色立绘 |
| 音乐音效 | audio/ | 替换BGM/SE |
| 本地化 | locale/ | 多语言翻译文件 |

### 三、MOD目录结构
```
user://mods/
  my_mod/
    mod.json          # MOD元数据
    data/
      troops.json     # 兵种覆盖/新增
      heroes.json     # 英雄覆盖/新增
      events.json     # 事件覆盖/新增
      items.json      # 道具
      buildings.json  # 建筑
    assets/
      portraits/      # 立绘PNG
      icons/          # 图标
      audio/          # 音频
    maps/
      custom_map.json # 自定义地图
```

### 四、mod.json格式
```json
{
  "id": "my_custom_mod",
  "name": "自定义MOD名称",
  "version": "1.0.0",
  "author": "作者名",
  "description": "MOD描述",
  "game_version_min": "1.0.0",
  "game_version_max": "1.99.0",
  "priority": 100,
  "dependencies": [],
  "conflicts": []
}
```

### 五、数据覆盖规则
1. 核心数据加载（game_data.gd中的字典）
2. 扫描user://mods/下所有mod.json
3. 按priority升序排列
4. 依次加载每个MOD的JSON文件
5. 同ID数据：MOD覆盖核心 | 后加载覆盖先加载
6. 新ID数据：追加到数据字典
7. 资源引用：MOD中的portrait路径自动映射到MOD的assets目录

### 六、JSON数据格式示例

#### troops.json
```json
{
  "troops": {
    "custom_warrior": {
      "name": "自定义战士",
      "faction": "orc",
      "type": "samurai",
      "atk": 10,
      "def": 8,
      "soldiers": 7,
      "row": "front",
      "passive": "regen_1",
      "cost_gold": 30,
      "portrait": "portraits/custom_warrior.png"
    }
  }
}
```

#### heroes.json
```json
{
  "heroes": {
    "custom_hero": {
      "name": "自定义英雄",
      "faction": null,
      "troop": "samurai",
      "atk": 7, "def": 6, "int": 5, "spd": 6,
      "active": "custom_slash",
      "passive": "custom_aura",
      "portrait": "portraits/custom_hero.png",
      "capture_condition": "defeat_100"
    }
  },
  "skills": {
    "custom_slash": {"name": "自定义斩", "type": "active", "target": "single", "mult": 1.8, "cost_mana": 0},
    "custom_aura": {"name": "自定义光环", "type": "passive", "effect": "all_atk_1"}
  }
}
```

### 七、MOD管理UI
- 设置→MOD管理
- 列表显示所有已安装MOD（名称/版本/作者/启用状态）
- 拖拽排序调整优先级
- 启用/禁用切换
- 冲突检测提示
- 重启生效

### 八、GDScript接口
```gdscript
# ModManager autoload
func scan_mods() -> Array[Dictionary]  # 扫描所有mod.json
func enable_mod(mod_id: String) -> bool
func disable_mod(mod_id: String) -> bool
func load_all_mods() -> void  # 启动时调用，覆盖GameData
func get_mod_info(mod_id: String) -> Dictionary
func check_conflicts() -> Array[String]  # 返回冲突列表
```

### 九、模块接口
- 依赖: 所有数据模块的JSON格式定义
- 被引用: 09_UI.md(MOD管理界面)
- 数据导出: mod_schema, ModManager API
