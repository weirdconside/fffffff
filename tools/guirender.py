"""Render GUIDUMP output from the Luau mock into PNGs and flag text layout problems.

usage: python3 guirender.py layout.out WxH outprefix
Reports:
  OVERFLOW  text wider/taller than its box (spills over neighbours)
  SHRUNK    TextScaled text that had to shrink a lot to fit
  OVERLAP   two visible texts drawn on top of each other
  COVERED   text partly hidden under a later-drawn opaque frame/button
"""
import sys, math
from PIL import Image, ImageDraw, ImageFont

FONT_FILES = {
    'arial': '/usr/share/fonts/truetype/liberation/LiberationSans-Bold.ttf',
    'default': '/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf',
    'fredoka': __import__('os').path.join(__import__('os').path.dirname(__import__('os').path.abspath(__file__)), 'FredokaOne.ttf'),
}
_font_cache = {}
def font_for(family, size):
    fam = (family or '').lower()
    path = FONT_FILES['arial'] if ('arial' in fam or 'legacy' in fam) else FONT_FILES['fredoka'] if 'fredoka' in fam else FONT_FILES['default']
    if not __import__('os').path.exists(path):
        path = FONT_FILES['default']   # FredokaOne.ttf (Google Fonts, OFL) is optional
    size = max(1, int(round(size)))
    key = (path, size)
    if key not in _font_cache:
        _font_cache[key] = ImageFont.truetype(path, size)
    return _font_cache[key]

def text_w(font, s):
    if not s: return 0
    return font.getlength(s)

GUIOBJ = {'Frame', 'TextLabel', 'TextButton', 'TextBox', 'ImageLabel', 'ImageButton', 'ScrollingFrame', 'ViewportFrame', 'CanvasGroup'}
TEXT = {'TextLabel', 'TextButton', 'TextBox'}

def parse_val(v):
    if v.startswith('u2:'): return tuple(float(x) for x in v[3:].split(','))
    if v.startswith('u:'): return tuple(float(x) for x in v[2:].split(','))
    if v.startswith('v2:'): return tuple(float(x) for x in v[3:].split(','))
    if v.startswith('c3:'): return tuple(int(x) for x in v[3:].split(','))
    if v.startswith('font:'): return v[5:]
    if v.startswith('enum:'): return v[5:]
    if v == 'true': return True
    if v == 'false': return False
    try: return float(v)
    except ValueError: return v.replace('\\n', '\n')

def load(path):
    dumps = {}; cur = None
    for line in open(path, encoding='utf-8', errors='replace'):
        line = line.rstrip('\n')
        if line.startswith('GUIDUMP_BEGIN'):
            cur = line.split('\t', 1)[1]; dumps[cur] = []
        elif line.startswith('GUIDUMP_END'):
            cur = None
        elif line.startswith('GUIDUMP\t') and cur:
            d = {}
            for f in line.split('\t')[1:]:
                k, _, v = f.partition('=')
                d[k] = parse_val(v) if k not in ('name', 'class', 'Text') else v.replace('\\n', '\n')
            d['id'] = int(d['id']); d['pid'] = int(d['pid'])
            dumps[cur].append(d)
    return dumps

def g(n, k, default=None):
    v = n.get(k)
    return default if v is None else v

class Obj:
    pass

def rot_about(cx, cy, deg):
    a = math.radians(deg); c, s = math.cos(a), math.sin(a)
    # screen y points down, Roblox Rotation is clockwise on screen
    return [[c, -s, cx - c * cx + s * cy], [s, c, cy - s * cx - c * cy], [0, 0, 1]]
def mat_mul(A, B):
    return [[sum(A[i][k] * B[k][j] for k in range(3)) for j in range(3)] for i in range(3)]
IDENT = [[1, 0, 0], [0, 1, 0], [0, 0, 1]]
def apply(M, x, y):
    return (M[0][0] * x + M[0][1] * y + M[0][2], M[1][0] * x + M[1][1] * y + M[1][2])

def wrap_lines(font, text, width, wrapped):
    out = []
    for para in text.split('\n'):
        if not wrapped:
            out.append(para); continue
        words = para.split(' ')
        line = ''
        for w in words:
            cand = w if not line else line + ' ' + w
            if text_w(font, cand) <= width + 0.5 or not line:
                line = cand
            else:
                out.append(line); line = w
        out.append(line)
    return out

def fit_scaled(family, text, w, h, maxsize, minsize=1):
    best = minsize
    for s in range(int(max(1, maxsize)), int(minsize) - 1, -1):
        f = font_for(family, s)
        lines = wrap_lines(f, text, w, True)
        if max((text_w(f, l) for l in lines), default=0) <= w + 0.5 and len(lines) * s <= h + 0.5:
            return s, lines
    f = font_for(family, minsize)
    return minsize, wrap_lines(f, text, w, True)

def build(nodes, W, H):
    by = {n['id']: n for n in nodes}
    kids = {}
    for n in nodes:
        kids.setdefault(n['pid'], []).append(n)
    objs = []
    order = [0]
    def children_of(n):
        return kids.get(n['id'], [])
    def modifier(n, cls):
        for c in children_of(n):
            if c['class'] == cls: return c
        return None
    def layout(n, prect, k, M, alpha, gui, depth_path, clip):
        cls = n['class']
        if cls not in GUIOBJ:
            return
        if not g(n, 'Visible', True):
            return
        px, py, pw, ph = prect
        sx, so, sy, syo = g(n, 'Size', (0, 0, 0, 0))
        w = sx * pw + so * k; h = sy * ph + syo * k
        if n.get('_forced') is not None:
            x, y = n['_forced']
        else:
            qx, qo, qy, qyo = g(n, 'Position', (0, 0, 0, 0))
            ax, ay = g(n, 'AnchorPoint', (0, 0))
            x = px + qx * pw + qo * k - ax * w
            y = py + qy * ph + qyo * k - ay * h
        sc = modifier(n, 'UIScale')
        kk = k
        if sc is not None:
            s = g(sc, 'Scale', 1)
            ax, ay = g(n, 'AnchorPoint', (0, 0))
            cx, cy = x + ax * w, y + ay * h
            w, h = w * s, h * s
            x, y = cx - ax * w, cy - ay * h
            kk = k * s
        rot = g(n, 'Rotation', 0) or 0
        MM = M if not rot else mat_mul(M, rot_about(x + w / 2, y + h / 2, rot))
        a = alpha * (1 - g(n, 'GroupTransparency', 0)) if cls == 'CanvasGroup' else alpha
        o = Obj()
        o.n = n; o.cls = cls; o.rect = (x, y, w, h); o.M = MM; o.k = kk; o.alpha = a; o.gui = gui; o.path = depth_path + [n['id']]
        o.rot = abs(rot) > 0.01 or MM is not IDENT and any(abs(MM[i][j] - IDENT[i][j]) > 1e-6 for i in range(2) for j in range(2))
        o.clip = clip
        o.stroke = None; o.corner = modifier(n, 'UICorner') is not None
        for c in children_of(n):
            if c['class'] == 'UIStroke' and g(c, 'Enabled', True):
                o.stroke = c
        o.tsc = modifier(n, 'UITextSizeConstraint')
        objs.append(o)
        # content rect for children
        cx, cy, cw, ch = x, y, w, h
        pad = modifier(n, 'UIPadding')
        if pad is not None:
            pl = g(pad, 'PaddingLeft', (0, 0)); pr = g(pad, 'PaddingRight', (0, 0))
            pt = g(pad, 'PaddingTop', (0, 0)); pb = g(pad, 'PaddingBottom', (0, 0))
            l = pl[0] * w + pl[1] * kk; r = pr[0] * w + pr[1] * kk; t = pt[0] * h + pt[1] * kk; b = pb[0] * h + pb[1] * kk
            cx, cy, cw, ch = x + l, y + t, w - l - r, h - t - b
        if cls == 'ScrollingFrame':
            cp = g(n, 'CanvasPosition', (0, 0))
            cx -= cp[0]; cy -= cp[1]
        newclip = clip
        if g(n, 'ClipsDescendants', False) or cls == 'ScrollingFrame':
            r0 = (x, y, x + w, y + h)
            newclip = r0 if clip is None else (max(clip[0], r0[0]), max(clip[1], r0[1]), min(clip[2], r0[2]), min(clip[3], r0[3]))
        ch_list = [c for c in children_of(n) if c['class'] in GUIOBJ]
        ll = modifier(n, 'UIListLayout'); gl = modifier(n, 'UIGridLayout')
        if ll is not None:
            vertical = g(ll, 'FillDirection', 'Vertical') == 'Vertical'
            padd = g(ll, 'Padding', (0, 0))
            gap = padd[0] * (ch if vertical else cw) + padd[1] * kk
            sort_name = g(ll, 'SortOrder', 'LayoutOrder') == 'Name'
            vis = [c for c in ch_list if g(c, 'Visible', True)]
            vis.sort(key=lambda c: (c['name'] if sort_name else g(c, 'LayoutOrder', 0), c['id']))
            sizes = []
            for c in vis:
                s_ = g(c, 'Size', (0, 0, 0, 0))
                sizes.append((s_[0] * cw + s_[1] * kk, s_[2] * ch + s_[3] * kk))
            total = sum(s_[1] if vertical else s_[0] for s_ in sizes) + gap * max(0, len(vis) - 1)
            ha = g(ll, 'HorizontalAlignment', 'Left'); va = g(ll, 'VerticalAlignment', 'Top')
            if vertical:
                pos = cy + (0 if va == 'Top' else (ch - total) / 2 if va == 'Center' else ch - total)
            else:
                pos = cx + (0 if ha == 'Left' else (cw - total) / 2 if ha == 'Center' else cw - total)
            for c, (sw, sh) in zip(vis, sizes):
                if vertical:
                    xx = cx + (0 if ha == 'Left' else (cw - sw) / 2 if ha == 'Center' else cw - sw)
                    c['_forced'] = (xx, pos); pos += sh + gap
                else:
                    yy = cy + (0 if va == 'Top' else (ch - sh) / 2 if va == 'Center' else ch - sh)
                    c['_forced'] = (pos, yy); pos += sw + gap
        elif gl is not None:
            cs = g(gl, 'CellSize', (0, 100, 0, 100)); cpd = g(gl, 'CellPadding', (0, 5, 0, 5))
            cwid = cs[0] * cw + cs[1] * kk; chei = cs[2] * ch + cs[3] * kk
            gx = cpd[0] * cw + cpd[1] * kk; gy = cpd[2] * ch + cpd[3] * kk
            per_row = max(1, int((cw + gx) // (cwid + gx)))
            vis = [c for c in ch_list if g(c, 'Visible', True)]
            vis.sort(key=lambda c: (g(c, 'LayoutOrder', 0), c['id']))
            for i, c in enumerate(vis):
                c['_forced'] = (cx + (i % per_row) * (cwid + gx), cy + (i // per_row) * (chei + gy))
                c['Size'] = (0, cwid / kk if kk else cwid, 0, chei / kk if kk else chei)
        for c in ch_list:
            layout(c, (cx, cy, cw, ch), kk, MM, a, gui, o.path, newclip)
    guis = [n for n in nodes if n['class'] == 'ScreenGui']
    guis.sort(key=lambda n: g(n, 'DisplayOrder', 0))
    ordered = []
    for gi, gnode in enumerate(guis):
        if not g(gnode, 'Enabled', True):
            continue
        inset = 0 if g(gnode, 'IgnoreGuiInset', False) else 58
        start = len(objs)
        for c in kids.get(gnode['id'], []):
            layout(c, (0, inset, W, H - inset), 1, IDENT, 1, gi, [gnode['id']], None)
        mine = objs[start:]
        if g(gnode, 'ZIndexBehavior', 'Sibling') == 'Global':
            idx = {id(o): i for i, o in enumerate(mine)}
            mine.sort(key=lambda o: (g(o.n, 'ZIndex', 1), idx[id(o)]))
        else:
            # sibling: depth-first, siblings sorted by ZIndex
            tree = {}
            for o in mine: tree.setdefault(o.n['pid'], []).append(o)
            res = []
            def dfs(pid):
                lst = tree.get(pid, [])
                lst = sorted(lst, key=lambda o: (g(o.n, 'ZIndex', 1), mine.index(o)))
                for o in lst:
                    res.append(o); dfs(o.n['id'])
            dfs(gnode['id'])
            mine = res
        ordered.extend(mine)
    return ordered

def is_ancestor(a, b):
    """a is an ancestor of b (or the same)"""
    return a.n['id'] in b.path

def text_info(o):
    n = o.n
    text = n.get('Text', '')
    if o.cls not in TEXT or not text.strip():
        return None
    tt = g(n, 'TextTransparency', 0)
    if tt >= 0.99 or o.alpha <= 0.01:
        return None
    x, y, w, h = o.rect
    fam = g(n, 'FontFace', 'arial')
    scaled = g(n, 'TextScaled', False)
    wrapped = g(n, 'TextWrapped', False)
    if scaled:
        mx = 100
        if o.tsc is not None: mx = g(o.tsc, 'MaxTextSize', 100)
        mn = g(o.tsc, 'MinTextSize', 1) if o.tsc is not None else 1
        size, lines = fit_scaled(fam, text, w, h, mx * o.k, 1)
        want = mx * o.k if o.tsc is not None else None
    else:
        size = g(n, 'TextSize', 14) * o.k
        f = font_for(fam, size)
        lines = wrap_lines(f, text, w, wrapped)
        want = None
    f = font_for(fam, size)
    tw = max((text_w(f, l) for l in lines), default=0)
    th = len(lines) * size
    xa = g(n, 'TextXAlignment', 'Center'); ya = g(n, 'TextYAlignment', 'Center')
    ix = x if xa == 'Left' else (x + (w - tw) / 2 if xa == 'Center' else x + w - tw)
    iy = y if ya == 'Top' else (y + (h - th) / 2 if ya == 'Center' else y + h - th)
    return dict(text=text, size=size, lines=lines, font=f, tw=tw, th=th, ink=(ix, iy, ix + tw, iy + th), want=want,
                color=g(n, 'TextColor3', (27, 42, 53)), alpha=(1 - tt) * o.alpha, xa=xa, scaled=scaled)

def inter(a, b):
    x0, y0 = max(a[0], b[0]), max(a[1], b[1]); x1, y1 = min(a[2], b[2]), min(a[3], b[3])
    return max(0, x1 - x0) * max(0, y1 - y0)

def name_path(o, by):
    return o.n['name']

def analyse(ordered, label):
    issues = []
    texts = []
    for i, o in enumerate(ordered):
        ti = text_info(o)
        if ti is None: continue
        o.ti = ti
        x, y, w, h = o.rect
        if o.rot: continue
        if not ti['scaled']:
            if ti['tw'] > w + 1.5 and not g(o.n, 'TextWrapped', False):
                issues.append(('OVERFLOW', o, 'text %.0fpx wide in a %.0fpx box' % (ti['tw'], w)))
            elif ti['th'] > h + 2 and len(ti['lines']) > 1:
                issues.append(('OVERFLOW', o, '%d lines (%.0fpx) in a %.0fpx tall box' % (len(ti['lines']), ti['th'], h)))
            elif ti['tw'] > w + 1.5:
                issues.append(('OVERFLOW', o, 'a word is wider than the box (%.0f > %.0f)' % (ti['tw'], w)))
        elif ti['want'] and ti['size'] < ti['want'] * 0.72:
            issues.append(('SHRUNK', o, 'text shrinks to %.0fpx (design %.0fpx)' % (ti['size'], ti['want'])))
        texts.append((i, o))
    for a_i in range(len(texts)):
        ia, a = texts[a_i]
        for b_i in range(a_i + 1, len(texts)):
            ib, b = texts[b_i]
            if a.rot or b.rot or a.gui != b.gui: continue
            if is_ancestor(a, b) or is_ancestor(b, a): continue
            if a.n['pid'] == b.n['pid'] and 'Shadow' in (a.n['name'], b.n['name']): continue   # drop shadows sit under their face on purpose
            A, B = a.ti['ink'], b.ti['ink']
            ov = inter(A, B)
            small = min((A[2] - A[0]) * (A[3] - A[1]), (B[2] - B[0]) * (B[3] - B[1]))
            if small > 0 and ov > 0.12 * small:
                issues.append(('OVERLAP', b, 'draws over "%s"' % a.ti['text'][:30]))
    for i, o in texts:
        A = o.ti['ink']
        for j in range(i + 1, len(ordered)):
            c = ordered[j]
            if c.rot or c.gui != o.gui or is_ancestor(c, o) or is_ancestor(o, c): continue
            if c.cls not in GUIOBJ: continue
            if g(c.n, 'BackgroundTransparency', 0) > 0.5 or c.alpha < 0.5: continue
            cx, cy, cw, ch = c.rect
            ov = inter(A, (cx, cy, cx + cw, cy + ch))
            area = (A[2] - A[0]) * (A[3] - A[1])
            if area > 0 and ov > 0.08 * area:
                issues.append(('COVERED', o, 'under "%s" (%d%%)' % (c.n['name'], 100 * ov / area)))
                break
    return issues

def draw(ordered, W, H, out):
    img = Image.new('RGBA', (W, H), (70, 110, 80, 255))
    for o in ordered:
        n = o.n
        x, y, w, h = o.rect
        layer = Image.new('RGBA', (W, H), (0, 0, 0, 0))
        d = ImageDraw.Draw(layer)
        poly = [apply(o.M, *p) for p in ((x, y), (x + w, y), (x + w, y + h), (x, y + h))]
        bt = g(n, 'BackgroundTransparency', 0)
        if bt < 0.99 and o.cls not in ('ImageLabel', 'ImageButton') or (o.cls in ('ImageLabel', 'ImageButton') and bt < 0.99):
            c = g(n, 'BackgroundColor3', (255, 255, 255))
            d.polygon(poly, fill=c + (int(255 * (1 - bt) * o.alpha),))
        if o.cls in ('ImageLabel', 'ImageButton') and n.get('Image'):
            it = g(n, 'ImageTransparency', 0)
            if it < 0.99:
                c = g(n, 'ImageColor3', (255, 255, 255))
                aa = int(255 * (1 - it) * o.alpha * 0.35)
                # hatch to show a texture
                for t in range(-int(h), int(w), 9):
                    p0 = apply(o.M, x + max(0, t), y + max(0, -t)); p1 = apply(o.M, x + min(w, t + h), y + min(h, h - (t + h - min(w, t + h))))
                    d.line([p0, p1], fill=c + (aa,), width=1)
        if o.stroke is not None and (o.cls not in TEXT or g(o.stroke, 'ApplyStrokeMode', 'Contextual') == 'Border'):
            st = o.stroke
            sc = g(st, 'Color', (0, 0, 0)); th = max(1, int(round(g(st, 'Thickness', 1))))
            d.polygon(poly, outline=sc + (int(255 * (1 - g(st, 'Transparency', 0)) * o.alpha),), width=th)
        ti = getattr(o, 'ti', None)
        if ti is not None:
            tile = Image.new('RGBA', (max(1, int(math.ceil(w)) + 400), max(1, int(math.ceil(h)) + 200)), (0, 0, 0, 0))
            td = ImageDraw.Draw(tile)
            ox, oy = 200, 100
            ya = g(n, 'TextYAlignment', 'Center')
            top = 0 if ya == 'Top' else ((h - ti['th']) / 2 if ya == 'Center' else h - ti['th'])
            sw = 0; sf = None
            if o.stroke is not None and g(o.stroke, 'ApplyStrokeMode', 'Contextual') != 'Border':
                sw = max(1, int(round(g(o.stroke, 'Thickness', 1)))); sf = g(o.stroke, 'Color', (0, 0, 0)) + (int(255 * ti['alpha']),)
            for li, line in enumerate(ti['lines']):
                lw = text_w(ti['font'], line)
                lx = 0 if ti['xa'] == 'Left' else ((w - lw) / 2 if ti['xa'] == 'Center' else w - lw)
                td.text((ox + lx, oy + top + li * ti['size']), line, font=ti['font'], fill=tuple(ti['color']) + (int(255 * ti['alpha']),),
                        stroke_width=sw, stroke_fill=sf)
            if o.rot:
                cxx, cyy = x + w / 2, y + h / 2
                ang = math.degrees(math.atan2(o.M[1][0], o.M[0][0]))
                tile = tile.rotate(-ang, center=(ox + w / 2, oy + h / 2), resample=Image.BICUBIC)
                pc = apply(o.M, cxx, cyy)
                layer.alpha_composite(tile, (int(pc[0] - ox - w / 2), int(pc[1] - oy - h / 2))) if 0 <= int(pc[0] - ox - w / 2) < W and 0 <= int(pc[1] - oy - h / 2) < H else None
            else:
                dx, dy = int(round(x - ox)), int(round(y - oy))
                crop_l, crop_t = max(0, -dx), max(0, -dy)
                if crop_l >= tile.width or crop_t >= tile.height:
                    tile = None
                elif crop_l or crop_t:
                    tile = tile.crop((crop_l, crop_t, tile.width, tile.height)); dx += crop_l; dy += crop_t
                if tile is not None and dx < W and dy < H:
                    layer.alpha_composite(tile, (dx, dy))
        if o.clip is not None:
            mask = Image.new('L', (W, H), 0)
            ImageDraw.Draw(mask).rectangle(o.clip, fill=255)
            empty = Image.new('RGBA', (W, H), (0, 0, 0, 0))
            layer = Image.composite(layer, empty, mask)
        img.alpha_composite(layer)
    img.convert('RGB').save(out)

def main():
    path, size, prefix = sys.argv[1], sys.argv[2], sys.argv[3]
    W, H = (int(v) for v in size.split('x'))
    dumps = load(path)
    total = 0
    for label, nodes in dumps.items():
        ordered = build(nodes, W, H)
        issues = analyse(ordered, label)
        draw(ordered, W, H, '%s_%s.png' % (prefix, label))
        for kind, o, msg in issues:
            print('%-8s %-20s %-28s %s  | %r' % (kind, label, o.n['name'][:28], msg, o.ti['text'][:40] if hasattr(o, 'ti') else ''))
        total += len(issues)
    print('issues:', total)

if __name__ == '__main__':
    main()
