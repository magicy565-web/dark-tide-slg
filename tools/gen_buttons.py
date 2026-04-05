"""
按钮贴图生成脚本
从现有的 1376×768 全屏截图中裁剪出按钮主体区域，
并生成 normal/hover/pressed/danger/confirm 五套按钮贴图。

目标尺寸：200×48px（可被 9-slice 拉伸，边距各 12px）
"""
from PIL import Image, ImageDraw, ImageFilter, ImageEnhance
import os

OUT_DIR = "assets/ui/buttons"
os.makedirs(OUT_DIR, exist_ok=True)

# ── 工具函数 ──────────────────────────────────────────────────
def crop_center_button(src_path: str, out_w: int = 200, out_h: int = 48) -> Image.Image:
    """从全屏截图中裁剪按钮主体，并缩放到目标尺寸。"""
    img = Image.open(src_path).convert("RGBA")
    w, h = img.size
    # 按钮主体大约在图像中央 60% 宽、40% 高的区域
    cx, cy = w // 2, h // 2
    crop_w = int(w * 0.60)
    crop_h = int(h * 0.40)
    box = (cx - crop_w // 2, cy - crop_h // 2,
           cx + crop_w // 2, cy + crop_h // 2)
    cropped = img.crop(box)
    # 高质量缩放
    resized = cropped.resize((out_w, out_h), Image.LANCZOS)
    return resized

def make_button_programmatic(out_w: int, out_h: int, style: str) -> Image.Image:
    """
    程序化生成暗潮风格按钮（当裁剪效果不理想时的备选方案）。
    style: 'normal' | 'hover' | 'pressed' | 'danger' | 'confirm'
    """
    img = Image.new("RGBA", (out_w, out_h), (0, 0, 0, 0))
    draw = ImageDraw.Draw(img)

    # 颜色方案
    palettes = {
        "normal":  {"bg": (18, 28, 38, 230),  "border": (60, 120, 200, 255),  "glow": (40, 100, 180, 180)},
        "hover":   {"bg": (22, 35, 48, 240),  "border": (200, 160, 40, 255),  "glow": (180, 140, 30, 200)},
        "pressed": {"bg": (10, 18, 26, 255),  "border": (80, 80, 120, 255),   "glow": (50, 50, 100, 150)},
        "danger":  {"bg": (38, 12, 12, 230),  "border": (200, 50, 50, 255),   "glow": (180, 30, 30, 180)},
        "confirm": {"bg": (12, 32, 18, 230),  "border": (40, 180, 80, 255),   "glow": (30, 160, 60, 180)},
    }
    p = palettes.get(style, palettes["normal"])
    r = 6  # corner radius

    # 外发光层
    glow_img = Image.new("RGBA", (out_w, out_h), (0, 0, 0, 0))
    gd = ImageDraw.Draw(glow_img)
    gc = p["glow"]
    for i in range(4, 0, -1):
        alpha = int(gc[3] * (i / 4) * 0.5)
        gd.rounded_rectangle(
            [i, i, out_w - 1 - i, out_h - 1 - i],
            radius=r + i, outline=(*gc[:3], alpha), width=2
        )
    glow_blurred = glow_img.filter(ImageFilter.GaussianBlur(radius=3))
    img = Image.alpha_composite(img, glow_blurred)
    draw = ImageDraw.Draw(img)

    # 主体背景（渐变模拟：上半部分稍亮）
    bg = p["bg"]
    for y in range(out_h):
        t = y / out_h
        r_c = int(bg[0] * (1 + 0.15 * (1 - t)))
        g_c = int(bg[1] * (1 + 0.12 * (1 - t)))
        b_c = int(bg[2] * (1 + 0.10 * (1 - t)))
        draw.line([(r, y), (out_w - r - 1, y)],
                  fill=(min(r_c, 255), min(g_c, 255), min(b_c, 255), bg[3]))

    # 圆角矩形背景
    draw.rounded_rectangle([0, 0, out_w - 1, out_h - 1],
                            radius=r, fill=(*bg[:3], bg[3]))

    # 内部高光线（顶部）
    hl_alpha = 80 if style == "pressed" else 120
    draw.line([(r + 2, 2), (out_w - r - 3, 2)],
              fill=(255, 255, 255, hl_alpha), width=1)

    # 边框
    bc = p["border"]
    draw.rounded_rectangle([0, 0, out_w - 1, out_h - 1],
                            radius=r, outline=bc, width=2)

    # 铆钉装饰（四角）
    rivet_r = 3
    rivet_color = (int(bc[0] * 0.8), int(bc[1] * 0.8), int(bc[2] * 0.8), 220)
    for rx, ry in [(8, 8), (out_w - 9, 8), (8, out_h - 9), (out_w - 9, out_h - 9)]:
        draw.ellipse([rx - rivet_r, ry - rivet_r, rx + rivet_r, ry + rivet_r],
                     fill=rivet_color, outline=(40, 40, 60, 200), width=1)

    # pressed 状态：整体压暗
    if style == "pressed":
        dark = Image.new("RGBA", (out_w, out_h), (0, 0, 0, 60))
        img = Image.alpha_composite(img, dark)

    return img


# ── 主流程 ────────────────────────────────────────────────────
W, H = 200, 48

# 尝试从现有截图裁剪，若效果不好则用程序化生成
src_map = {
    "normal":  "assets/ui/buttons/btn_action_normal.png",
    "hover":   "assets/ui/buttons/btn_action_hover.png",
    "pressed": "assets/ui/buttons/btn_action_pressed.png",
}

results = {}
for style, src in src_map.items():
    try:
        cropped = crop_center_button(src, W, H)
        results[style] = cropped
        print(f"[OK] Cropped {style}: {cropped.size}")
    except Exception as e:
        print(f"[WARN] Crop failed for {style}: {e}, using programmatic")
        results[style] = make_button_programmatic(W, H, style)

# danger / confirm 用程序化生成（原图没有对应截图）
results["danger"]  = make_button_programmatic(W, H, "danger")
results["confirm"] = make_button_programmatic(W, H, "confirm")

# 保存
out_names = {
    "normal":  "btn_action_normal.png",
    "hover":   "btn_action_hover.png",
    "pressed": "btn_action_pressed.png",
    "danger":  "btn_danger_normal.png",
    "confirm": "btn_confirm_normal.png",
}
for style, fname in out_names.items():
    out_path = os.path.join(OUT_DIR, fname)
    results[style].save(out_path)
    img_check = Image.open(out_path)
    print(f"[SAVED] {out_path} -> {img_check.size}")

print("\nDone! All button textures generated.")
