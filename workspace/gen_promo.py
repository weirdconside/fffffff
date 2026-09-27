"""Clickbait-style promo art: game icon, 3 thumbnails, 2 ad banners."""
import math, os, random
from PIL import Image, ImageDraw, ImageFilter
from gen_assets import (font, mix, darker, lighter, radial, studs, sunburst, glow, shape, poly_fn, rrect_fn, ellipse_fn,
                        chunky_text, tag, crown, finish, INK, C, RAINBOW, FIRE, OUT)

WHITE = (255, 255, 255)

def noob(img, cx, cy, s, shirt=(52, 120, 220), face='shock', arms='up', flip=False):
    """blocky Roblox-style character, feet at (cx, cy), s = total height"""
    u = s / 6.0
    skin, legs = (255, 214, 64), (60, 170, 70)
    lw = max(4, int(u * .12))
    # legs
    for dx in (-.55, .55):
        shape(img, rrect_fn([cx + dx * u - .5 * u, cy - 2 * u, cx + dx * u + .5 * u, cy], u * .12), legs, width=lw)
    # torso
    shape(img, rrect_fn([cx - 1.05 * u, cy - 4 * u, cx + 1.05 * u, cy - 2 * u], u * .15), shirt, width=lw, shadow=(0, int(u * .1)))
    # arms
    for side in (-1, 1):
        ax = cx + side * 1.6 * u
        if arms == 'up':
            pts = [(ax - .5 * u, cy - 3.9 * u), (ax + .5 * u, cy - 3.9 * u), (ax + .5 * u + side * .6 * u, cy - 5.9 * u), (ax - .5 * u + side * .6 * u, cy - 5.9 * u)]
            shape(img, poly_fn(pts), skin, width=lw)
        else:
            shape(img, rrect_fn([ax - .5 * u, cy - 4 * u, ax + .5 * u, cy - 2.1 * u], u * .12), skin, width=lw)
    # head
    hx, hy = cx, cy - 4.95 * u
    shape(img, rrect_fn([hx - .85 * u, hy - .85 * u, hx + .85 * u, hy + .85 * u], u * .3), skin, width=lw, shadow=(0, int(u * .1)))
    d = ImageDraw.Draw(img)
    ex = .32 * u
    for side in (-1, 1):
        r = .17 * u if face == 'shock' else .11 * u
        d.ellipse([hx + side * ex - r, hy - .28 * u - r, hx + side * ex + r, hy - .28 * u + r], fill=WHITE if face == 'shock' else INK, outline=INK, width=lw // 2 + 1)
        if face == 'shock':
            d.ellipse([hx + side * ex - r * .45, hy - .28 * u - r * .45, hx + side * ex + r * .45, hy - .28 * u + r * .45], fill=INK)
    if face == 'shock':
        d.ellipse([hx - .26 * u, hy + .1 * u, hx + .26 * u, hy + .62 * u], fill=(120, 20, 20), outline=INK, width=lw // 2 + 1)
    else:
        d.arc([hx - .4 * u, hy - .15 * u, hx + .4 * u, hy + .45 * u], 20, 160, fill=INK, width=lw)

def arrow(img, x0, y0, x1, y1, w, colour=(235, 30, 30)):
    ang = math.atan2(y1 - y0, x1 - x0); L = math.hypot(x1 - x0, y1 - y0)
    ca, sa = math.cos(ang), math.sin(ang)
    def P(a, b): return (x0 + ca * a - sa * b, y0 + sa * a + ca * b)
    head = w * 1.6
    pts = [P(0, -w / 2), P(L - head, -w / 2), P(L - head, -w * 1.15), P(L, 0), P(L - head, w * 1.15), P(L - head, w / 2), P(0, w / 2)]
    shape(img, poly_fn(pts), colour, ink=WHITE, width=int(w * .28), shadow=(0, int(w * .2)))
    d = ImageDraw.Draw(img); d.line(pts + [pts[0]], fill=INK, width=max(3, int(w * .08)), joint='curve')

def burst(img, cx, cy, r, colour, spikes=14, ink=INK, rot=0):
    pts = []
    for k in range(spikes * 2):
        a = rot + k * math.pi / spikes
        rr = r if k % 2 == 0 else r * .72
        pts.append((cx + math.cos(a) * rr, cy + math.sin(a) * rr))
    shape(img, poly_fn(pts), colour, ink=ink, width=max(4, int(r * .06)), shadow=(0, int(r * .06)))

def meteor(img, cx, cy, r, angle=35):
    a = math.radians(angle)
    layer = Image.new('RGBA', img.size, (0, 0, 0, 0)); d = ImageDraw.Draw(layer)
    for k in range(14, 0, -1):
        t = k / 14
        x = cx - math.cos(a) * r * 4.2 * t; y = cy - math.sin(a) * r * 4.2 * t
        rr = r * (1 - t * .75)
        d.ellipse([x - rr, y - rr, x + rr, y + rr], fill=mix((255, 230, 90), (255, 70, 20), t) + (int(220 * (1 - t * .6)),))
    img.alpha_composite(layer.filter(ImageFilter.GaussianBlur(r * .12)))
    shape(img, ellipse_fn([cx - r, cy - r, cx + r, cy + r]), (120, 90, 80), width=max(4, int(r * .1)))
    d = ImageDraw.Draw(img)
    for dx, dy, cr in ((-.3, -.2, .22), (.35, .1, .16), (-.05, .4, .13)):
        d.ellipse([cx + dx * r - cr * r, cy + dy * r - cr * r, cx + dx * r + cr * r, cy + dy * r + cr * r], fill=(90, 66, 58))

def boom(img, cx, cy, r):
    burst(img, cx, cy, r, (255, 150, 30), spikes=11, rot=.2)
    burst(img, cx, cy, r * .66, (255, 230, 80), spikes=9, ink=(255, 120, 20), rot=.5)

def command_box(img, x, y, w, name, text, size, name_colour=(255, 150, 60)):
    f = font(size)
    h = size * 2.0
    shape(img, rrect_fn([x, y, x + w, y + h], size * .4), (30, 26, 40), ink=C['gold'], width=max(4, int(size * .12)), shadow=(0, int(size * .2)))
    d = ImageDraw.Draw(img)
    d.text((x + size * .6, y + h / 2), name, font=f, fill=name_colour, anchor='lm', stroke_width=max(2, int(size * .08)), stroke_fill=INK)
    d.text((x + size * .6 + f.getlength(name), y + h / 2), text, font=f, fill=WHITE, anchor='lm', stroke_width=max(2, int(size * .08)), stroke_fill=INK)

def castle(img, cx, cy, s, colour=(200, 60, 60)):
    """simple enemy base block: walls + towers + flag, bottom-centre at (cx, cy)"""
    lw = max(4, int(s * .03))
    shape(img, rrect_fn([cx - s * .5, cy - s * .45, cx + s * .5, cy], s * .03), (150, 150, 160), width=lw)
    for tx in (-.5, .5):
        shape(img, rrect_fn([cx + tx * s - s * .14, cy - s * .75, cx + tx * s + s * .14, cy], s * .03), (130, 130, 140), width=lw)
    d = ImageDraw.Draw(img)
    for k in range(5):
        d.rectangle([cx - s * .45 + k * s * .21, cy - s * .52, cx - s * .36 + k * s * .21, cy - s * .44], fill=(150, 150, 160), outline=INK, width=lw // 2)
    d.line([(cx, cy - s * .45), (cx, cy - s * .95)], fill=INK, width=lw)
    shape(img, poly_fn([(cx, cy - s * .95), (cx + s * .25, cy - s * .87), (cx, cy - s * .79)]), colour, width=lw // 2 + 1)
    shape(img, rrect_fn([cx - s * .1, cy - s * .22, cx + s * .1, cy], s * .08), (90, 60, 40), width=lw)

def sky(size, top, bottom):
    img = Image.new('RGBA', size, top + (255,)); d = ImageDraw.Draw(img)
    for y in range(size[1]):
        d.line([(0, y), (size[0], y)], fill=mix(top, bottom, y / size[1]) + (255,))
    return img

def ground(img, y, colour=(90, 190, 70)):
    w, h = img.size
    shape(img, rrect_fn([-40, y, w + 40, h + 60], 30), colour, width=10)
    studs_layer = Image.new('RGBA', img.size, (0, 0, 0, 0)); d = ImageDraw.Draw(studs_layer)
    for x in range(0, w, 60):
        for yy in range(int(y) + 30, h, 60):
            d.ellipse([x - 12, yy - 12, x + 12, yy + 12], fill=(255, 255, 255, 30))
    img.alpha_composite(studs_layer)

# ---------------------------------------------------------------------------- icon
def icon():
    S = 1024
    img = radial((S, S), (255, 200, 60), (230, 60, 20))
    sunburst(img, (S * .5, S * .55), 18, WHITE, 40)
    meteor(img, S * .78, S * .3, S * .1, angle=45)
    meteor(img, S * .92, S * .55, S * .06, angle=45)
    noob(img, S * .38, S * .98, S * .62, face='shock', arms='up')
    arrow(img, S * .97, S * .8, S * .66, S * .62, S * .075)
    chunky_text(img, 'ADMIN', 250, (S * .5, S * .15), [C['gold'], WHITE, C['gold'], WHITE, C['gold']])
    burst(img, S * .82, S * .92, S * .09, C['red'], spikes=12)
    d = ImageDraw.Draw(img); d.text((S * .82, S * .92), '?!', font=font(S * .1), fill=WHITE, anchor='mm', stroke_width=6, stroke_fill=INK)
    return finish(img, os.path.join(OUT, 'Promo_Icon.png'), (512, 512))

# ---------------------------------------------------------------------------- thumbnails
def thumb1():
    W, H = 1920, 1080
    img = sky((W, H), (120, 190, 255), (200, 235, 255))
    ground(img, H * .78)
    castle(img, W * .74, H * .8, 380)
    for k, (x, y, r) in enumerate([(.6, .2, 70), (.76, .12, 85), (.9, .26, 60), (.68, .42, 50)]):
        meteor(img, W * x, H * y, r, angle=50)
    boom(img, W * .74, H * .66, 150)
    noob(img, W * .14, H * .97, 520, face='shock', arms='up')
    command_box(img, W * .04, H * .05, W * .5, 'You: ', 'meteor on the enemy base', 54)
    chunky_text(img, 'I GOT THE', 110, (W * .42, H * .3), [WHITE])
    chunky_text(img, 'ADMIN PANEL!', 140, (W * .42, H * .45), RAINBOW)
    arrow(img, W * .52, H * .62, W * .64, H * .7, 60)
    return finish(img, os.path.join(OUT, 'Promo_Thumbnail_1.png'), (1920, 1080))

def thumb2():
    W, H = 1920, 1080
    img = radial((W, H), (130, 70, 230), (40, 16, 90))
    sunburst(img, (W / 2, H * .6), 24, WHITE, 22)
    studs(img, 110, 18, 16)
    chunky_text(img, 'EXECUTE  OR', 130, (W * .5, H * .12), [C['green']] * 7 + [WHITE] * 4)
    chunky_text(img, 'EVERYONE ADDS?', 130, (W * .5, H * .27), [C['pink'], C['gold']])
    cells = [('EXECUTE', C['green']), ('EVERYONE ADDS', C['purple']), ('EXECUTE', C['green'])]
    cw, ch = 520, 190
    x0 = W / 2 - (3 * cw + 2 * 30) / 2
    for i, (label, col) in enumerate(cells):
        box = [x0 + i * (cw + 30), H * .44, x0 + i * (cw + 30) + cw, H * .44 + ch]
        shape(img, rrect_fn(box, 36), col, width=10, shadow=(0, 12))
        ImageDraw.Draw(img).text(((box[0] + box[2]) / 2, (box[1] + box[3]) / 2), label, font=font(66 if len(label) < 10 else 54), fill=WHITE, anchor='mm', stroke_width=5, stroke_fill=INK)
    d = ImageDraw.Draw(img)
    d.polygon([(W / 2 - 55, H * .44 - 80), (W / 2 + 55, H * .44 - 80), (W / 2, H * .44 - 8)], fill=C['gold'], outline=INK, width=8)
    noob(img, W * .1, H * 1.02, 380, shirt=(220, 60, 60), face='shock', arms='up')
    noob(img, W * .9, H * 1.02, 380, shirt=(60, 180, 90), face='smile', arms='down')
    command_box(img, W * .25, H * .76, W * .5, 'Bob: ', 'summon 50 giants!!', 58, name_colour=(120, 200, 255))
    return finish(img, os.path.join(OUT, 'Promo_Thumbnail_2.png'), (1920, 1080))

def thumb3():
    W, H = 1920, 1080
    img = sky((W, H), (255, 170, 90), (255, 225, 160))
    ground(img, H * .74, colour=(110, 190, 70))
    # the giant
    noob(img, W * .72, H * .96, 760, shirt=(150, 70, 200), face='shock', arms='up')
    # the army
    rnd = random.Random(4)
    for k in range(9):
        x = W * (.08 + (k % 5) * .085) + rnd.uniform(-10, 10)
        y = H * (.9 + (k // 5) * .07)
        noob(img, x, y, 230 + (k // 5) * 30, shirt=RAINBOW[k % len(RAINBOW)], face='smile', arms='up' if k % 2 else 'down')
    crown(img, W * .72, H * .1, 260)
    chunky_text(img, 'BUILD AN ARMY...', 110, (W * .3, H * .14), [WHITE])
    chunky_text(img, 'THEN TYPE', 120, (W * .27, H * .3), [C['gold']])
    chunky_text(img, 'ANYTHING!', 170, (W * .28, H * .48), FIRE)
    return finish(img, os.path.join(OUT, 'Promo_Thumbnail_3.png'), (1920, 1080))

# ---------------------------------------------------------------------------- ads
def ad_wide():
    W, H = 1456, 180          # 728x90 at 2x
    img = radial((W, H), (255, 190, 60), (220, 50, 20))
    sunburst(img, (W * .12, H * .5), 16, WHITE, 40)
    noob(img, W * .08, H * 1.02, 170, face='shock', arms='up')
    meteor(img, W * .2, H * .35, 34, angle=40)
    chunky_text(img, 'EVERY 2 MIN SOMEONE', 58, (W * .5, H * .3), [WHITE])
    chunky_text(img, 'GETS THE ADMIN PANEL!', 70, (W * .5, H * .7), RAINBOW)
    shape(img, rrect_fn([W * .82, H * .2, W * .97, H * .8], 30), C['green'], ink=WHITE, width=8, shadow=(0, 8))
    ImageDraw.Draw(img).text((W * .895, H * .5), 'PLAY!', font=font(64), fill=WHITE, anchor='mm', stroke_width=5, stroke_fill=INK)
    return finish(img, os.path.join(OUT, 'Ad_728x90.png'), (728, 90))

def ad_box():
    W, H = 600, 500           # 300x250 at 2x
    img = radial((W, H), (150, 90, 240), (50, 20, 110))
    sunburst(img, (W * .5, H * .5), 16, WHITE, 30)
    meteor(img, W * .16, H * .18, 34, angle=45)
    noob(img, W * .22, H * 1.02, 300, face='shock', arms='up')
    chunky_text(img, 'TYPE ANY', 70, (W * .6, H * .12), [WHITE])
    chunky_text(img, 'COMMAND!', 78, (W * .6, H * .28), [C['gold']])
    command_box(img, W * .3, H * .5, W * .66, 'You: ', 'nuke them', 30)
    shape(img, rrect_fn([W * .45, H * .75, W * .92, H * .93], 26), C['green'], ink=WHITE, width=7, shadow=(0, 8))
    ImageDraw.Draw(img).text((W * .685, H * .84), 'PLAY NOW', font=font(48), fill=WHITE, anchor='mm', stroke_width=4, stroke_fill=INK)
    return finish(img, os.path.join(OUT, 'Ad_300x250.png'), (300, 250))

if __name__ == '__main__':
    for fn in (icon, thumb1, thumb2, thumb3, ad_wide, ad_box):
        print(fn())
