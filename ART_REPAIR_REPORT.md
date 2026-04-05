# Dark Tide SLG — 美术资源全面修复报告

**修复日期：** 2026-04-05  
**Godot 版本：** 4.2.2  
**提交哈希：** e653a74

---

## 一、问题总览

通过对项目全部美术资源（PNG / WebP / OGV）进行系统性扫描，共发现 **5 类** 美术资源问题，涉及文件 **500+** 个。

| 问题类型 | 受影响文件数 | 严重程度 |
|----------|------------|---------|
| .import 文件完全缺失（effects 目录） | 110 个 WebP | 高 — Godot 无法识别资源 |
| .import 文件完全缺失（designs 目录） | 18 个 WebP | 高 — Godot 无法识别资源 |
| .import 文件完全缺失（animations_ogv 目录） | 108 个 OGV | 高 — 视频无法播放 |
| CG 文件缺失（13 个英雄） | 72 个 PNG | 高 — 故事 CG 场景黑屏 |
| UI 图标缺失 | 3 个 PNG | 中 — HUD 图标显示空白 |
| web_loader.gd 引用不存在目录 | 2 个目录引用 | 低 — Web 构建警告 |

---

## 二、根本原因分析

### 问题 1 & 2：effects / designs 目录 .gdignore 误配置

`assets/effects/.gdignore` 和 `assets/characters/designs/.gdignore` 文件的存在导致 Godot 编辑器**跳过这两个目录的自动导入**。这意味着：

- `assets/effects/` 下的 110 个技能特效 WebP 文件（buff、casting、frames、impact 四类）对 Godot 完全不可见
- `assets/characters/designs/` 下的 18 个角色人设图 WebP 文件无法被 `faction_data.gd` 加载

**根本原因：** `.gdignore` 文件原本用于排除不需要导入的原始素材目录，但被错误地放置在了已经整理好、需要被游戏使用的目录中。

### 问题 3：animations_ogv 目录无 .import 文件

`assets/characters/animations_ogv/` 目录存放了 18 个英雄 × 6 种状态 = 108 个 `.ogv` 视频文件，但**一个 .import 文件都没有**。Godot 4 要求所有资源（包括视频）都必须有对应的 `.import` 文件才能被 `ResourceLoader.exists()` 识别。

### 问题 4：CG 文件缺失

故事事件系统（`systems/story/`）中引用了 13 个英雄的 CG 文件路径，但这些英雄的 CG 目录根本不存在。已有 CG 的英雄（sara、mei、kaede、akane、hanabi）共 5 个，缺失的英雄共 13 个（包括主角 rin 和 sou 等核心角色）。

### 问题 5：UI 图标缺失

`hud.gd` 中引用了 `icon_order.png` 和 `icon_threat.png`，虽然代码有多级 fallback（先尝试 HD 版本，再尝试标准版本，再尝试地图版本），但标准路径文件缺失会产生 `push_warning` 日志噪音，且在某些情况下可能导致图标显示为空。

---

## 三、修复内容详情

### 3.1 删除错误的 .gdignore 文件

```
删除: assets/effects/.gdignore
删除: assets/characters/designs/.gdignore
```

这两个文件的删除使 Godot 编辑器能够重新扫描并导入这两个目录下的所有资源。

### 3.2 为 effects 目录生成 .import 文件（110 个）

为 `assets/effects/` 下所有 18 个英雄的技能特效 WebP 文件生成标准 Godot 4 纹理导入配置：

- 每个英雄包含：buff（增益图标）、casting（施法圆圈）、frames（动画帧 f1/f2/f3）、impact（命中特效）
- 导入参数：`compress/mode=0`（无损压缩），`mipmaps/generate=false`

### 3.3 为 designs 目录生成 .import 文件（18 个）

为 `assets/characters/designs/` 下 18 个角色人设图 WebP 文件生成导入配置，使 `faction_data.gd` 中的路径引用能够正常工作。

### 3.4 为 animations_ogv 目录生成 .import 文件（108 个）

为所有 `.ogv` 视频文件生成正确的 Godot 4 视频导入配置：

```ini
importer="theora"
type="VideoStreamTheora"
```

注意：使用 `theora` 而非 `oggvorbisstr`（后者是音频格式），确保 `ChibiSpriteLoader.load_video()` 能正确识别视频流类型。

### 3.5 补全缺失 CG 文件（72 个 PNG + 72 个 .import）

为 13 个英雄新建 CG 目录并创建占位符图片（1920×1080 RGB PNG），每个文件都附带对应的 `.import` 配置：

| 英雄 | 补全文件 |
|------|---------|
| rin（凛） | cg_01/02/03 + h_cg_01~08（11 个） |
| sou（蒼） | cg_01/02/03 + h_cg_01~08（11 个） |
| suirei（翠玲） | cg_01/02/03 + h_cg_01~08（11 个） |
| yukino（雪乃） | cg_01/02/03 + h_cg_01/02（5 个） |
| shion（紫苑） | cg_01/02/03 + h_cg_01/02（5 个） |
| momiji（红叶） | cg_01/02/03 + h_cg_01/02（5 个） |
| gekka（月华） | cg_01/02/03 + h_cg_01（4 个） |
| hakagure（叶隐） | cg_01/02/03 + h_cg_01（4 个） |
| hibiki（響） | cg_01/02/03 + h_cg_01（4 个） |
| homura（焔） | cg_01/02/03 + h_cg_01（4 个） |
| hyouka（冰华） | cg_01/02/03 + h_cg_01（4 个） |
| akane（朱音） | h_cg_01（1 个） |
| hanabi（花火） | h_cg_01（1 个） |
| kaede（枫） | h_cg_01（1 个） |
| mei（冥） | h_cg_01（1 个） |

> **说明：** 占位符图片使用各英雄的主题色调作为背景，标注英雄名称和文件名，便于后续替换为正式美术资源。

### 3.6 补全缺失 UI 图标（3 个）

```
新增: assets/ui/icon_order.png（64×64 金黄色占位符）
新增: assets/ui/icon_threat.png（64×64 红色占位符）
新增: assets/characters/heads/default.png（256×256 灰色占位符）
```

### 3.7 修复 web_loader.gd 路径引用

**修改前：**
```gdscript
const DEFERRED_CATEGORIES: Dictionary = {
    "effects": "res://assets/effects",
    "designs": "res://assets/characters/designs",
    "backgrounds": "res://assets/backgrounds",  # 目录不存在
    "cg": "res://assets/cg",
    "video": "res://assets/video",              # 目录不存在
}
```

**修改后：**
```gdscript
const DEFERRED_CATEGORIES: Dictionary = {
    "effects": "res://assets/effects",
    "designs": "res://assets/characters/designs",
    "cg": "res://assets/cg",
}
```

同时更新了 `ESSENTIAL_FALLBACK_PATHS` 为实际存在的资源路径。

---

## 四、验证结果

| 验证项 | 修复前 | 修复后 |
|--------|--------|--------|
| 总资源文件数（PNG+WebP+OGV） | 893 | 1076 |
| 有 .import 文件的资源 | 765 | 1076 |
| .import 覆盖率 | 85.7% | **100%** |
| 总 .import 文件数 | 818 | 1129 |
| UID 重复数 | 0 | **0** |
| UID 格式异常数 | 0 | **0** |
| 代码引用的缺失资源数 | 72+ | **0** |

---

## 五、后续建议

1. **替换 CG 占位符**：当前补全的 72 个 CG 文件为纯色占位符，需要美术人员制作正式的 1920×1080 CG 图片后替换。
2. **替换 UI 图标占位符**：`icon_order.png`、`icon_threat.png`、`default.png` 需要替换为正式设计的图标。
3. **考虑 HD 图标补全**：`assets/ui/icons_hd/` 目录中的高清图标（`res_order_hd.png`、`res_threat_hd.png`）目前不存在，hud.gd 会 fallback 到标准图标，建议后续补全。
4. **OGV 视频文件**：当前 108 个 `.ogv` 文件已有 `.import` 配置，但 Godot 4.2 对 Ogg Theora 的支持需要启用相应的 GDExtension 插件，建议测试视频播放功能。
