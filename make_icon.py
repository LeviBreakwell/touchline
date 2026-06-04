from PIL import Image, ImageDraw
import math

SIZE = 512
cx, cy = SIZE // 2, SIZE // 2

img = Image.new("RGBA", (SIZE, SIZE), (0, 0, 0, 0))
draw = ImageDraw.Draw(img)

# Dark rounded background
bg_pad = 30
draw.ellipse([bg_pad, bg_pad, SIZE - bg_pad, SIZE - bg_pad], fill="#161b22")

# Ball body (green oval, rotated 35 degrees)
def rotated_ellipse(draw, cx, cy, rx, ry, angle_deg, fill, outline=None, width=1):
    angle = math.radians(angle_deg)
    steps = 120
    pts = []
    for i in range(steps):
        t = 2 * math.pi * i / steps
        x = rx * math.cos(t)
        y = ry * math.sin(t)
        rx2 = x * math.cos(angle) - y * math.sin(angle) + cx
        ry2 = x * math.sin(angle) + y * math.cos(angle) + cy
        pts.append((rx2, ry2))
    draw.polygon(pts, fill=fill)
    if outline:
        draw.line(pts + [pts[0]], fill=outline, width=width)

# Main ball
rotated_ellipse(draw, cx, cy, 175, 108, 35, fill="#22c55e")

# Darker shading on bottom half of ball for depth
shade_img = Image.new("RGBA", (SIZE, SIZE), (0, 0, 0, 0))
shade_draw = ImageDraw.Draw(shade_img)
rotated_ellipse(shade_draw, cx + 12, cy + 12, 175, 108, 35, fill=(0, 0, 0, 60))
img = Image.alpha_composite(img, shade_img)
draw = ImageDraw.Draw(img)

# Ball outline
rotated_ellipse(draw, cx, cy, 175, 108, 35, fill=None, outline="#16a34a", width=6)

# Seam line — curved line across the ball's long axis
def draw_seam(draw, cx, cy, angle_deg):
    angle = math.radians(angle_deg)
    steps = 60
    pts = []
    for i in range(steps + 1):
        t = (i / steps - 0.5) * math.pi * 0.9
        x = 168 * math.sin(t)
        y = 28 * math.sin(t * 2) * 0.5
        rx2 = x * math.cos(angle) - y * math.sin(angle) + cx
        ry2 = x * math.sin(angle) + y * math.cos(angle) + cy
        pts.append((rx2, ry2))
    for i in range(len(pts) - 1):
        draw.line([pts[i], pts[i+1]], fill="#16a34a", width=5)

draw_seam(draw, cx, cy, 35)

# Laces — 4 short perpendicular bars across the seam centre
def draw_laces(draw, cx, cy, angle_deg):
    angle = math.radians(angle_deg)
    perp = math.radians(angle_deg + 90)
    lace_len = 22
    spacing = 18
    offsets = [-1.5, -0.5, 0.5, 1.5]
    for off in offsets:
        # position along seam axis
        along = off * spacing
        ax = cx + along * math.cos(angle)
        ay = cy + along * math.sin(angle)
        # endpoints perpendicular to seam
        x1 = ax - lace_len * math.cos(perp) / 2
        y1 = ay - lace_len * math.sin(perp) / 2
        x2 = ax + lace_len * math.cos(perp) / 2
        y2 = ay + lace_len * math.sin(perp) / 2
        draw.line([(x1, y1), (x2, y2)], fill="white", width=5)
    # vertical connector
    start_off, end_off = offsets[0], offsets[-1]
    sx = cx + start_off * spacing * math.cos(angle)
    sy = cy + start_off * spacing * math.sin(angle)
    ex = cx + end_off   * spacing * math.cos(angle)
    ey = cy + end_off   * spacing * math.sin(angle)
    draw.line([(sx, sy), (ex, ey)], fill="white", width=3)

draw_laces(draw, cx, cy, 35)

# Save 512x512
img.save("public/icon.png")

# Save 192x192
img.resize((192, 192), Image.LANCZOS).save("public/icon-192.png")

# SVG favicon (simple, for browser tab)
svg = """<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 64 64">
  <rect width="64" height="64" rx="14" fill="#161b22"/>
  <ellipse cx="32" cy="32" rx="22" ry="14" transform="rotate(35 32 32)" fill="#22c55e" stroke="#16a34a" stroke-width="1.5"/>
  <path d="M12 38 Q32 28 52 22" stroke="#16a34a" stroke-width="1.5" fill="none"/>
  <line x1="28" y1="32" x2="26" y2="27" stroke="white" stroke-width="1.8" stroke-linecap="round"/>
  <line x1="31" y1="30" x2="29" y2="25" stroke="white" stroke-width="1.8" stroke-linecap="round"/>
  <line x1="34" y1="29" x2="32" y2="24" stroke="white" stroke-width="1.8" stroke-linecap="round"/>
  <line x1="37" y1="27" x2="35" y2="22" stroke="white" stroke-width="1.8" stroke-linecap="round"/>
</svg>"""

with open("public/icon.svg", "w") as f:
    f.write(svg)

print("Icons generated: public/icon.png (512), public/icon-192.png (192), public/icon.svg")
