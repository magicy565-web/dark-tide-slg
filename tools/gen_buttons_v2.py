"""
按钮贴图生成脚本 v2
全部程序化生成暗潮风格按钮贴图（200×48px）
风格：深色石板底色 + 彩色发光边框 + 铆钉装饰 + 顶部高光线
"""
from PIL import Image, ImageDraw, ImageFilter
import os, math

OUT_DIR = "assets/ui/buttons"
os.makedirs(OUT_DIR, exist_ok=True)

W, H = 200, 48
RADIUS = 5


def make_dark_tide_button(out_w: int, out_h: int, style: str) -> Image.Image:
    """
    生成暗潮SLG风格按钮。
    style: 'normal' | 'hover' | 'pressed' | 'danger' | 'confirm'
    """
    # ── 颜色方案 ──────────────────────────────────────────────
    palettes = {
        "normal":  {
            "bg_top":    (28, 38, 52, 240),
            "bg_bot":    (14, 22, 32, 250),
            "border":    (55, 130, 210, 255),
            "glow":      (40, 100, 190, 160),
            "rivet":     (80, 140, 200, 220),
            "highlight": (120, 180, 255, 90),
        },
        "hover":   {
            "bg_top":    (38, 48, 28, 245),
            "bg_bot":    (22, 30, 14, 250),
            "border":    (210, 170, 40, 255),
            "glow":      (190, 150, 30, 180),
            "rivet":     (200, 170, 60, 220),
            "highlight": (255, 220, 100, 100),
        },
        "pressed": {
            "bg_top":    (10, 16, 24, 255),
            "bg_bot":    (6, 10, 16, 255),
            "border":    (40, 80, 140, 200),
            "glow":      (30, 60, 120, 100),
            "rivet":     (50, 80, 120, 180),
            "highlight": (60, 100, 160, 50),
        },
        "danger":  {
            "bg_top":    (48, 14, 14, 240),
            "bg_bot":    (28, 8, 8, 250),
            "border":    (210, 50, 50, 255),
            "glow":      (190, 30, 30, 170),
            "rivet":     (200, 60, 60, 220),
            "highlight": (255, 100, 100, 80),
        },
        "confirm": {
            "bg_top":    (14, 44, 22, 240),
            "bg_bot":    (8, 26, 12, 250),
            "border":    (50, 190, 80, 255),
            "glow":      (30, 170, 60, 170),
            "rivet":     (60, 190, 80, 220),
            "highlight": (100, 255, 130, 80),
        },
    }
    p = palettes.get(style, palettes["normal"])

    # ── 画布 ──────────────────────────────────────────────────
    img = Image.new("RGBA", (out_w, out_h), (0, 0, 0, 0))

    # ── 1. 外发光层 ───────────────────────────────────────────
    glow_img = Image.new("RGBA", (out_w, out_h), (0, 0, 0, 0))
    gd = ImageDraw.Draw(glow_img)
    gc = p["glow"]
    for i in range(5, 0, -1):
        a = int(gc[3] * (i / 5) * 0.6)
        gd.rounded_rectangle(
            [i, i, out_w - 1 - i, out_h - 1 - i],
            radius=RADIUS + i,
            outline=(*gc[:3], a),
            width=1
        )
    glow_blurred = glow_img.filter(ImageFilter.GaussianBlur(radius=2.5))
    img = Image.alpha_composite(img, glow_blurred)

    # ── 2. 主体背景（垂直渐变） ───────────────────────────────
    bg_img = Image.new("RGBA", (out_w, out_h), (0, 0, 0, 0))
    bg_draw = ImageDraw.Draw(bg_img)
    # 先填圆角矩形遮罩
    mask = Image.new("L", (out_w, out_h), 0)
    md = ImageDraw.Draw(mask)
    md.rounded_rectangle([0, 0, out_w - 1, out_h - 1], radius=RADIUS, fill=255)

    # 逐行渐变
    t_top = p["bg_top"]
    t_bot = p["bg_bot"]
    for y in range(out_h):
        t = y / (out_h - 1)
        r = int(t_top[0] + (t_bot[0] - t_top[0]) * t)
        g = int(t_top[1] + (t_bot[1] - t_top[1]) * t)
        b = int(t_top[2] + (t_bot[2] - t_top[2]) * t)
        a = int(t_top[3] + (t_bot[3] - t_top[3]) * t)
        bg_draw.line([(0, y), (out_w - 1, y)], fill=(r, g, b, a))

    # 应用圆角遮罩
    bg_img.putalpha(mask)
    img = Image.alpha_composite(img, bg_img)
    draw = ImageDraw.Draw(img)

    # ── 3. 石板纹理噪点（轻微） ───────────────────────────────
    import random
    random.seed(42)
    noise_img = Image.new("RGBA", (out_w, out_h), (0, 0, 0, 0))
    nd = ImageDraw.Draw(noise_img)
    for _ in range(out_w * out_h // 8):
        nx = random.randint(0, out_w - 1)
        ny = random.randint(0, out_h - 1)
        nv = random.randint(-12, 12)
        na = random.randint(8, 20)
        if nv > 0:
            nd.point([(nx, ny)], fill=(nv * 2, nv * 2, nv * 2, na))
        else:
            nd.point([(nx, ny)], fill=(0, 0, 0, na))
    # 应用遮罩
    noise_img.putalpha(mask)
    img = Image.alpha_composite(img, noise_img)
    draw = ImageDraw.Draw(img)

    # ── 4. 顶部高光线 ─────────────────────────────────────────
    hl = p["highlight"]
    draw.line([(RADIUS + 2, 2), (out_w - RADIUS - 3, 2)],
              fill=hl, width=1)
    # 二级高光（稍暗）
    draw.line([(RADIUS + 3, 3), (out_w - RADIUS - 4, 3)],
              fill=(*hl[:3], hl[3] // 2), width=1)

    # ── 5. 边框 ───────────────────────────────────────────────
    bc = p["border"]
    draw.rounded_rectangle([0, 0, out_w - 1, out_h - 1],
                            radius=RADIUS, outline=bc, width=2)
    # 内边框（稍暗）
    inner_bc = (*[int(c * 0.6) for c in bc[:3]], 180)
    draw.rounded_rectangle([2, 2, out_w - 3, out_h - 3],
                            radius=RADIUS - 1, outline=inner_bc, width=1)

    # ── 6. 铆钉装饰（四角） ───────────────────────────────────
    rv = p["rivet"]
    rivet_r = 3
    for rx, ry in [(9, 9), (out_w - 10, 9), (9, out_h - 10), (out_w - 10, out_h - 10)]:
        # 铆钉底色
        draw.ellipse([rx - rivet_r, ry - rivet_r, rx + rivet_r, ry + rivet_r],
                     fill=(*rv[:3], 200), outline=(20, 20, 30, 220), width=1)
        # 铆钉高光
        draw.ellipse([rx - 1, ry - 2, rx + 1, ry - 1],
                     fill=(255, 255, 255, 80))

    # ── 7. pressed 状态额外压暗 ───────────────────────────────
    if style == "pressed":
        dark = Image.new("RGBA", (out_w, out_h), (0, 0, 0, 0))
        dark_draw = ImageDraw.Draw(dark)
        dark_draw.rounded_rectangle([0, 0, out_w - 1, out_h - 1],
                                    radius=RADIUS, fill=(0, 0, 0, 50))
        img = Image.alpha_composite(img, dark)

    return img


# ── 主流程 ────────────────────────────────────────────────────
configs = [
    ("normal",  "btn_action_normal.png"),
    ("hover",   "btn_action_hover.png"),
    ("pressed", "btn_action_pressed.png"),
    ("danger",  "btn_danger_normal.png"),
    ("confirm", "btn_confirm_normal.png"),
]

for style, fname in configs:
    btn = make_dark_tide_button(W, H, style)
    out_path = os.path.join(OUT_DIR, fname)
    btn.save(out_path, "PNG")
    check = Image.open(out_path)
    print(f"[SAVED] {fname} -> {check.size}, mode={check.mode}")

print("\nAll button textures generated successfully!")
