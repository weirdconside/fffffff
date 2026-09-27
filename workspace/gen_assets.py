"""Store art for the release: game pass icons, ticket product icons, game icon, thumbnails.
Drawn with Pillow in the game's stud style (Fredoka One lettering, ink outlines).
Everything is rendered at 2x and downsampled for clean edges."""
import math, os, random
from PIL import Image, ImageDraw, ImageFont, ImageFilter

HERE = os.path.dirname(os.path.abspath(__file__))
FONT = os.path.join(HERE, 'FredokaOne.ttf')
OUT = os.path.join(HERE, 'release')
os.makedirs(OUT, exist_ok=True)
INK = (34, 27, 20)
PAPER = (255, 250, 241)
C = dict(blue=(52, 158, 216), cyan=(0, 190, 214), gold=(255, 204, 58), green=(64, 192, 29), purple=(147, 72, 213),
         red=(226, 35, 31), orange=(255, 140, 40), pink=(240, 80, 150), white=(255, 255, 255))
RAINBOW = [C['blue'], C['green'], C['red'], C['gold'], C['purple'], C['orange'], C['cyan'], C['pink']]
FIRE = [(236, 46, 36), (255, 112, 28), (255, 176, 32), (255, 112, 28), (236, 46, 36), (255, 140, 40)]

def font(size): return ImageFont.truetype(FONT, int(size))
def mix(a, b, t): return tuple(int(a[i] + (b[i] - a[i]) * t) for i in range(3))
def darker(c, k=.55): return tuple(int(v * k) for v in c)
def lighter(c, k=.45): return mix(c, (255, 255, 255), k)

def radial(size, inner, outer):
    w, h = size
    img = Image.new('RGB', size, outer)
    px = img.load()
    cx, cy = w / 2, h / 2; rmax = math.hypot(cx, cy)
    for y in range(h):
        for x in range(w):
            t = min(1, math.hypot(x - cx, y - cy) / rmax)
            px[x, y] = mix(inner, outer, t ** 1.3)
    return img.convert('RGBA')

def studs(img, spacing, radius, alpha=40):
    layer = Image.new('RGBA', img.size, (0, 0, 0, 0)); d = ImageDraw.Draw(layer)
    for y in range(-spacing, img.height + spacing, spacing):
        off = 0
        for x in range(-spacing, img.width + spacing, spacing):
            d.ellipse([x - radius, y - radius + 3, x + radius, y + radius + 3], fill=(0, 0, 0, alpha))
            d.ellipse([x - radius, y - radius, x + radius, y + radius], fill=(255, 255, 255, alpha))
    img.alpha_composite(layer)

def sunburst(img, center, rays, colour, alpha, spin=0):
    layer = Image.new('RGBA', img.size, (0, 0, 0, 0)); d = ImageDraw.Draw(layer)
    r = max(img.size) * 1.2
    for k in range(rays):
        a0 = spin + k * 2 * math.pi / rays; a1 = a0 + math.pi / rays
        d.polygon([center, (center[0] + math.cos(a0) * r, center[1] + math.sin(a0) * r), (center[0] + math.cos(a1) * r, center[1] + math.sin(a1) * r)],
                  fill=colour + (alpha,))
    img.alpha_composite(layer)

def glow(img, center, radius, colour, alpha=160):
    layer = Image.new('RGBA', img.size, (0, 0, 0, 0)); d = ImageDraw.Draw(layer)
    d.ellipse([center[0] - radius, center[1] - radius, center[0] + radius, center[1] + radius], fill=colour + (alpha,))
    img.alpha_composite(layer.filter(ImageFilter.GaussianBlur(radius * .45)))

def shape(img, draw_fn, fill, ink=INK, width=10, shadow=None):
    """draw_fn(draw, fill, outline, width) — draws with an ink outline and optional drop shadow"""
    if shadow:
        layer = Image.new('RGBA', img.size, (0, 0, 0, 0)); d = ImageDraw.Draw(layer)
        draw_fn(d, (0, 0, 0, 90), None, 0, shadow)
        img.alpha_composite(layer.filter(ImageFilter.GaussianBlur(6)))
    d = ImageDraw.Draw(img)
    draw_fn(d, fill, ink, width, (0, 0))

def poly_fn(points):
    def f(d, fill, outline, width, off):
        pts = [(x + off[0], y + off[1]) for x, y in points]
        d.polygon(pts, fill=fill)
        if outline: d.line(pts + [pts[0]], fill=outline, width=width, joint='curve')
    return f

def rrect_fn(box, radius):
    def f(d, fill, outline, width, off):
        b = [box[0] + off[0], box[1] + off[1], box[2] + off[0], box[3] + off[1]]
        d.rounded_rectangle(b, radius, fill=fill, outline=outline, width=width if outline else 0)
    return f

def ellipse_fn(box):
    def f(d, fill, outline, width, off):
        b = [box[0] + off[0], box[1] + off[1], box[2] + off[0], box[3] + off[1]]
        d.ellipse(b, fill=fill, outline=outline, width=width if outline else 0)
    return f

def chunky_text(img, text, size, center, colours, stroke=None, depth=None, anchor='mm', tracking=0):
    """3D lettering: dark extruded shadow + ink outline + vertical gradient face per letter."""
    f = font(size)
    stroke = stroke or max(4, int(size * .085))
    depth = depth if depth is not None else max(3, int(size * .08))
    widths = [f.getlength(ch) for ch in text]
    total = sum(widths) + tracking * (len(text) - 1)
    x = center[0] - total / 2 if anchor[0] == 'm' else center[0]
    asc, desc = f.getmetrics()
    y = center[1] - (asc - desc * .2) / 2 - size * .08 if anchor[1] == 'm' else center[1]
    for i, ch in enumerate(text):
        col = colours[i % len(colours)] if isinstance(colours, list) else colours
        if ch != ' ':
            d = ImageDraw.Draw(img)
            for k in range(depth, 0, -1):
                d.text((x, y + k), ch, font=f, fill=darker(col), stroke_width=stroke, stroke_fill=INK)
            d.text((x, y), ch, font=f, fill=INK, stroke_width=stroke, stroke_fill=INK)
            # gradient face
            mask = Image.new('L', img.size, 0)
            ImageDraw.Draw(mask).text((x, y), ch, font=f, fill=255)
            bbox = mask.getbbox()
            if bbox:
                grad = Image.new('RGBA', img.size, col + (255,))
                gd = ImageDraw.Draw(grad)
                top, bottom = bbox[1], bbox[3]
                for yy in range(top, bottom + 1):
                    t = (yy - top) / max(1, bottom - top)
                    c = mix(lighter(col, .35), col, min(1, t * 1.6)) if t < .55 else mix(col, darker(col, .82), (t - .55) / .45)
                    gd.line([(bbox[0], yy), (bbox[2], yy)], fill=c + (255,))
                img.paste(grad, (0, 0), mask)
                # glossy highlight on the upper part of the letter
                hl = Image.new('L', img.size, 0)
                ImageDraw.Draw(hl).rectangle([bbox[0], top, bbox[2], top + (bottom - top) * .28], fill=70)
                hl = Image.composite(hl, Image.new('L', img.size, 0), mask)
                img.paste(Image.new('RGBA', img.size, (255, 255, 255, 255)), (0, 0), hl)
        x += widths[i] + tracking
    return total

def tag(img, text, center, size, bg=INK, fg=C['gold'], rot=-6):
    f = font(size)
    w = f.getlength(text) + size * 1.0; h = size * 1.45
    layer = Image.new('RGBA', (int(w + 40), int(h + 40)), (0, 0, 0, 0)); d = ImageDraw.Draw(layer)
    d.rounded_rectangle([20, 20, 20 + w, 20 + h], radius=int(size * .35), fill=bg, outline=(255, 255, 255), width=max(3, int(size * .09)))
    d.text((20 + w / 2, 20 + h / 2 + size * .02), text, font=f, fill=fg, anchor='mm')
    layer = layer.rotate(-rot, resample=Image.BICUBIC, expand=True)
    img.alpha_composite(layer, (int(center[0] - layer.width / 2), int(center[1] - layer.height / 2)))
    return w

# ------------------------------------------------------------------ props
def crown(img, cx, cy, s):
    """gold crown centred on (cx, cy); s = width"""
    gold, gold_d = (255, 206, 60), (214, 150, 20)
    h = s * .62
    base_top = cy + h * .12; base_bot = cy + h * .5
    pts = [(cx - s * .5, base_top), (cx - s * .5, cy - h * .35), (cx - s * .28, cy - h * .02), (cx - s * .14, cy - h * .5),
           (cx, cy - h * .08), (cx + s * .14, cy - h * .5), (cx + s * .28, cy - h * .02), (cx + s * .5, cy - h * .35), (cx + s * .5, base_top)]
    shape(img, poly_fn(pts), gold, width=int(s * .045), shadow=(int(s * .03), int(s * .05)))
    # shading on the right half
    layer = Image.new('RGBA', img.size, (0, 0, 0, 0)); ImageDraw.Draw(layer).polygon(pts, fill=(0, 0, 0, 0))
    shape(img, rrect_fn([cx - s * .52, base_top - h * .04, cx + s * .52, base_bot], s * .06), gold_d, width=int(s * .045))
    d = ImageDraw.Draw(img)
    d.rounded_rectangle([cx - s * .46, base_top + h * .02, cx + s * .46, base_top + h * .11], s * .03, fill=(255, 236, 150))
    for k, col in enumerate([(255, 70, 80), (70, 160, 255), (80, 220, 110)]):
        gx = cx + (k - 1) * s * .3
        r = s * .07
        shape(img, ellipse_fn([gx - r, (base_top + base_bot) / 2 - r, gx + r, (base_top + base_bot) / 2 + r]), col, width=int(s * .025))
        d.ellipse([gx - r * .45, (base_top + base_bot) / 2 - r * .55, gx - r * .05, (base_top + base_bot) / 2 - r * .15], fill=(255, 255, 255, 200))
    for px, py in [(cx - s * .5, cy - h * .35), (cx - s * .14, cy - h * .5), (cx + s * .14, cy - h * .5), (cx + s * .5, cy - h * .35)]:
        r = s * .055
        shape(img, ellipse_fn([px - r, py - r, px + r, py + r]), (255, 250, 235), width=int(s * .025))

def gavel(img, cx, cy, s, angle=-35):
    layer = Image.new('RGBA', img.size, (0, 0, 0, 0))
    wood, wood_d, metal = (170, 104, 52), (120, 70, 34), (255, 204, 58)
    # handle
    shape(layer, rrect_fn([cx - s * .06, cy - s * .05, cx + s * .06, cy + s * .62], s * .05), wood, width=int(s * .035))
    # head
    shape(layer, rrect_fn([cx - s * .42, cy - s * .32, cx + s * .42, cy + s * .02], s * .08), wood_d, width=int(s * .04))
    for side in (-1, 1):
        shape(layer, rrect_fn([cx + side * s * .42 - s * .07, cy - s * .36, cx + side * s * .42 + s * .07, cy + s * .06], s * .04), metal, width=int(s * .035))
    ImageDraw.Draw(layer).rounded_rectangle([cx - s * .34, cy - s * .27, cx + s * .34, cy - s * .2], s * .03, fill=(255, 255, 255, 70))
    layer = layer.rotate(angle, center=(cx, cy + s * .1), resample=Image.BICUBIC)
    sh = Image.new('RGBA', img.size, (0, 0, 0, 0))
    sh.paste((0, 0, 0, 90), (0, 0), layer.split()[3])
    img.alpha_composite(sh.filter(ImageFilter.GaussianBlur(8)), (int(s * .03), int(s * .05)))
    img.alpha_composite(layer)

def ticket(img, cx, cy, w, rot=0, colour=(255, 204, 58)):
    h = w * .5
    layer = Image.new('RGBA', (int(w + 60), int(h + 60)), (0, 0, 0, 0))
    ox, oy = 30, 30
    d = ImageDraw.Draw(layer)
    d.rounded_rectangle([ox, oy, ox + w, oy + h], radius=int(h * .16), fill=colour, outline=INK, width=max(4, int(w * .03)))
    notch = h * .17
    lw = max(4, int(w * .03))
    for side in (0, 1):
        x = ox + side * w
        # cut the notch, then outline only the part that bites into the ticket
        cut = Image.new('L', layer.size, 0); ImageDraw.Draw(cut).ellipse([x - notch, oy + h / 2 - notch, x + notch, oy + h / 2 + notch], fill=255)
        layer.paste((0, 0, 0, 0), (0, 0), cut)
        d.arc([x - notch, oy + h / 2 - notch, x + notch, oy + h / 2 + notch], 270 if side == 0 else 90, 90 if side == 0 else 270, fill=INK, width=lw)
    # dashed inner line
    for k in range(9):
        y0 = oy + h * .18 + k * h * .075
        d.line([(ox + w * .27, y0), (ox + w * .27, y0 + h * .04)], fill=darker(colour, .7), width=max(2, int(w * .015)))
    d.rounded_rectangle([ox + w * .06, oy + h * .12, ox + w * .94, oy + h * .88], radius=int(h * .1), outline=darker(colour, .8), width=max(2, int(w * .012)))
    # star + ADMIN
    sx, sy, r = ox + w * .15, oy + h / 2, h * .2
    star = [(sx + math.cos(math.pi / 2 + k * math.pi / 5) * (r if k % 2 == 0 else r * .45) * -1, sy - math.sin(math.pi / 2 + k * math.pi / 5) * (r if k % 2 == 0 else r * .45)) for k in range(10)]
    d.polygon(star, fill=(255, 255, 255), outline=INK)
    d.text((ox + w * .62, oy + h / 2), 'ADMIN', font=font(h * .34), fill=INK, anchor='mm')
    d.rounded_rectangle([ox + w * .05, oy + h * .08, ox + w * .95, oy + h * .3], radius=int(h * .08), fill=(255, 255, 255, 60))
    layer = layer.rotate(rot, resample=Image.BICUBIC, expand=True)
    sh = Image.new('RGBA', layer.size, (0, 0, 0, 0)); sh.paste((0, 0, 0, 100), (0, 0), layer.split()[3])
    sh = sh.filter(ImageFilter.GaussianBlur(7))
    img.alpha_composite(sh, (int(cx - layer.width / 2 + 5), int(cy - layer.height / 2 + 9)))
    img.alpha_composite(layer, (int(cx - layer.width / 2), int(cy - layer.height / 2)))

def finish(img, path, size):
    img = img.resize(size, Image.LANCZOS)
    img.convert('RGB').save(path)
    return path

# ------------------------------------------------------------------ game passes (Roblox shows them in a circle)
def pass_icon(name, bg_in, bg_out, draw_icon, word, word_colours, ribbon=None):
    S = 1024
    img = radial((S, S), bg_in, bg_out)
    sunburst(img, (S / 2, S * .42), 18, (255, 255, 255), 34, spin=.1)
    studs(img, 96, 20, 26)
    glow(img, (S / 2, S * .4), S * .3, (255, 245, 200), 150)
    draw_icon(img)
    chunky_text(img, word, 230 if len(word) <= 3 else 180, (S / 2, S * .69), word_colours)
    if ribbon:
        tag(img, ribbon, (S / 2, S * .84), 46, bg=INK, fg=C['gold'], rot=-3)
    # ring so the circle crop looks finished
    d = ImageDraw.Draw(img)
    d.ellipse([22, 22, S - 22, S - 22], outline=(255, 255, 255, 170), width=14)
    d.ellipse([8, 8, S - 8, S - 8], outline=INK, width=14)
    return finish(img, os.path.join(OUT, name), (512, 512))

def ticket_icon(count, badge=None):
    S = 1024
    img = radial((S, S), (160, 100, 235), (70, 36, 128))
    sunburst(img, (S / 2, S * .44), 16, (255, 255, 255), 26)
    studs(img, 96, 20, 24)
    glow(img, (S / 2, S * .42), S * .3, (255, 214, 120), 140)
    n = {1: 1, 3: 3, 7: 4, 10: 5, 20: 6}[count]
    spread = 16
    for k in range(n):
        a = (k - (n - 1) / 2) * spread
        cx = S / 2 + math.sin(math.radians(a)) * S * .2
        cy = S * .44 - math.cos(math.radians(a)) * S * .08 + abs(a) * 1.5
        ticket(img, cx, cy, S * .5, rot=-a)
    chunky_text(img, 'x%d' % count, 230, (S / 2, S * .8), [C['gold']])
    if badge:
        tag(img, badge, (S * .76, S * .12), 56, bg=C['red'] if badge != 'POPULAR' else C['blue'], fg=(255, 255, 255), rot=8)
    return finish(img, os.path.join(OUT, 'Ticket_x%d.png' % count), (512, 512))

# ------------------------------------------------------------------ logo art (icon + thumbnails)
def paper_with_bars(size, bars=True, seed=3):
    w, h = size
    img = Image.new('RGBA', size, PAPER + (255,))
    grad = Image.new('RGBA', size, (0, 0, 0, 0)); gd = ImageDraw.Draw(grad)
    for y in range(h):
        gd.line([(0, y), (w, y)], fill=(255, 226, 196, int(90 * y / h)))
    img.alpha_composite(grad)
    studs(img, int(w / 17), int(w / 90), 14)
    if bars:
        rnd = random.Random(seed)
        layer = Image.new('RGBA', (int(w * 2.2), int(w * 2.2)), (0, 0, 0, 0)); d = ImageDraw.Draw(layer)
        L = layer.width
        cols = [C['gold'], C['cyan'], C['purple'], C['blue'], C['pink'], C['red'], C['orange'], C['green']]
        defs = [(-.98, -.5, 1.1, .09), (-.86, -.2, .95, .075), (-.76, -.6, .8, .1), (-.64, -.15, .7, .06), (-.52, -.8, .5, .075),
                (.44, .7, .45, .06), (.54, .3, .75, .085), (.65, .8, .6, .07), (.74, .1, .95, .11), (.87, .6, .85, .08), (.97, .05, 1.1, .095)]
        for i, (lane, rest, ln, th) in enumerate(defs):
            col = cols[i % len(cols)]
            cx = L / 2 + rest * .5 * w; cy = L / 2 + lane * .5 * w * 1.05
            bw, bh = ln * w * .55, max(18, th * w * .5)
            box = [cx - bw / 2, cy - bh / 2, cx + bw / 2, cy + bh / 2]
            d.rounded_rectangle(box, radius=int(bh / 2), fill=col, outline=INK, width=max(4, int(w / 300)))
            d.rounded_rectangle([box[0] + bh * .5, box[1] + bh * .15, box[2] - bh * .5, box[1] + bh * .32], radius=int(bh * .1), fill=(255, 255, 255, 110))
        layer = layer.rotate(57, resample=Image.BICUBIC)
        img.alpha_composite(layer, (int(w / 2 - L / 2), int(h / 2 - L / 2)))
    return img

def app_tile(img, cx, cy, s):
    shape(img, rrect_fn([cx - s / 2, cy - s / 2 + s * .06, cx + s / 2, cy + s / 2 + s * .06], s * .22), (80, 34, 120), width=int(s * .035))
    shape(img, rrect_fn([cx - s / 2, cy - s / 2, cx + s / 2, cy + s / 2], s * .22), C['purple'], width=int(s * .035), shadow=(0, int(s * .05)))
    d = ImageDraw.Draw(img)
    for gy in range(3):
        for gx in range(3):
            x = cx - s * .3 + gx * s * .3; y = cy - s * .3 + gy * s * .3
            d.ellipse([x - s * .07, y - s * .07, x + s * .07, y + s * .07], fill=(255, 255, 255, 40))
    crown(img, cx, cy + s * .05, s * .72)

def logo(img, cx, top, width, stacked=False):
    """draw BATTLE [BUT][WITH] / ADMIN PANEL, fitting `width`"""
    if stacked:
        k = width / 900
        chunky_text(img, 'BATTLE', 150 * k, (cx, top + 85 * k), FIRE)
        tag(img, 'BUT', (cx - 95 * k, top + 205 * k), 62 * k, rot=-7)
        tag(img, 'WITH', (cx + 95 * k, top + 212 * k), 62 * k, fg=(255, 255, 255), rot=5)
        chunky_text(img, 'ADMIN', 190 * k, (cx, top + 350 * k), RAINBOW[:5])
        chunky_text(img, 'PANEL', 190 * k, (cx, top + 530 * k), RAINBOW[5:] + RAINBOW[:2])
        return top + 640 * k
    k = width / 1500
    w1 = font(150 * k).getlength('BATTLE')
    chunky_text(img, 'BATTLE', 150 * k, (cx - 160 * k, top + 80 * k), FIRE)
    tag(img, 'BUT', (cx - 160 * k + w1 / 2 + 105 * k, top + 70 * k), 58 * k, rot=-7)
    tag(img, 'WITH', (cx - 160 * k + w1 / 2 + 275 * k, top + 80 * k), 58 * k, fg=(255, 255, 255), rot=5)
    chunky_text(img, 'ADMIN PANEL', 190 * k, (cx, top + 250 * k), RAINBOW)
    return top + 350 * k

def game_icon():
    S = 1024
    img = paper_with_bars((S, S))
    glow(img, (S / 2, S * .52), S * .36, (255, 255, 255), 200)
    app_tile(img, S / 2, S * .17, S * .2)
    logo(img, S / 2, S * .27, S * .92, stacked=True)
    return finish(img, os.path.join(OUT, 'GameIcon.png'), (512, 512))

def thumbnail_title():
    W, H = 3840 // 2, 2160 // 2
    img = paper_with_bars((W, H), seed=5)
    glow(img, (W / 2, H * .45), H * .45, (255, 255, 255), 210)
    app_tile(img, W * .19, H * .4, H * .3)
    logo(img, W * .56, H * .2, W * .62)
    d = ImageDraw.Draw(img)
    plate = [W * .14, H * .76, W * .86, H * .88]
    shape(img, rrect_fn(plate, 40), INK, ink=(255, 255, 255), width=8, shadow=(0, 10))
    d.text(((plate[0] + plate[2]) / 2, (plate[1] + plate[3]) / 2), 'TYPE ANY COMMAND - THE ROULETTE DECIDES!', font=font(50), fill=C['gold'], anchor='mm')
    return finish(img, os.path.join(OUT, 'Thumbnail_1_Title.png'), (1920, 1080))

def thumbnail_gameplay():
    W, H = 1920, 1080
    img = radial((W, H), (96, 70, 170), (34, 22, 64))
    sunburst(img, (W / 2, H * .55), 24, (255, 255, 255), 16)
    studs(img, 110, 18, 18)
    d = ImageDraw.Draw(img)
    chunky_text(img, 'EVERY 2 MINUTES', 110, (W / 2, H * .13), [C['gold']])
    chunky_text(img, 'SOMEONE GETS THE ADMIN PANEL', 92, (W / 2, H * .27), [C['white']])
    # the caption as it appears in game: coloured name + command
    f = font(70)
    name, text = 'xX_Builder_Xx: ', 'meteor on every enemy base!'
    total = f.getlength(name + text)
    x = W / 2 - total / 2; y = H * .45
    d.text((x, y), name, font=f, fill=(255, 150, 60), stroke_width=6, stroke_fill=INK, anchor='lm')
    d.text((x + f.getlength(name), y), text, font=f, fill=(255, 255, 255), stroke_width=6, stroke_fill=INK, anchor='lm')
    # roulette strip
    cells = ['EXECUTE', 'EVERYONE ADDS', 'EXECUTE', 'EVERYONE ADDS', 'EXECUTE']
    cw, ch, gap = 420, 150, 26
    x0 = W / 2 - (len(cells) * cw + (len(cells) - 1) * gap) / 2
    for i, label in enumerate(cells):
        col = C['green'] if label == 'EXECUTE' else C['purple']
        box = [x0 + i * (cw + gap), H * .6, x0 + i * (cw + gap) + cw, H * .6 + ch]
        shape(img, rrect_fn(box, 30), col, width=8, shadow=(0, 10))
        d.rounded_rectangle([box[0] + 20, box[1] + 14, box[2] - 20, box[1] + 40], 12, fill=(255, 255, 255, 60))
        d.text(((box[0] + box[2]) / 2, (box[1] + box[3]) / 2), label, font=font(58 if len(label) < 10 else 46), fill=(255, 255, 255), stroke_width=4, stroke_fill=INK, anchor='mm')
    # pointer + fades
    px = W / 2
    d.polygon([(px - 40, H * .6 - 60), (px + 40, H * .6 - 60), (px, H * .6 - 5)], fill=C['gold'], outline=INK, width=6)
    for side in (0, 1):
        fade = Image.new('RGBA', (int(W * .22), H), (0, 0, 0, 0)); fd = ImageDraw.Draw(fade)
        for x in range(fade.width):
            t = x / fade.width if side == 1 else 1 - x / fade.width
            fd.line([(x, 0), (x, H)], fill=(34, 22, 64, int(255 * t ** 1.5)))
        img.alpha_composite(fade, (0 if side == 0 else W - fade.width, 0))
    plate = [W * .17, H * .83, W * .83, H * .94]
    shape(img, rrect_fn(plate, 36), INK, ink=(255, 255, 255), width=8, shadow=(0, 10))
    d.text(((plate[0] + plate[2]) / 2, (plate[1] + plate[3]) / 2), 'EXECUTE IT - OR EVERYONE ADDS TO IT', font=font(50), fill=C['gold'], anchor='mm')
    return finish(img, os.path.join(OUT, 'Thumbnail_2_AdminPanel.png'), (1920, 1080))

if __name__ == '__main__':
    made = []
    made.append(pass_icon('GamePass_VIP.png', (110, 230, 130), (24, 120, 60),
                          lambda im: crown(im, 512, 330, 440), 'VIP', [C['gold']], ribbon='FIRST ADMIN PANEL'))
    made.append(pass_icon('GamePass_ADMIN.png', (255, 110, 90), (150, 20, 24),
                          lambda im: gavel(im, 512, 290, 470), 'ADMIN', [C['gold'], (255, 255, 255)], ribbon='+10 TICKETS / ROUND'))
    for count, badge in ((1, None), (3, None), (7, 'POPULAR'), (10, None), (20, 'BEST VALUE')):
        made.append(ticket_icon(count, badge))
    made.append(game_icon())
    made.append(thumbnail_title())
    made.append(thumbnail_gameplay())
    for m in made: print(m)
