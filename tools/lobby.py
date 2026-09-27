"""Builds the new LobbyWorld: a stud-style harbour island made from the game's own assets."""
import math, random
import numpy as np
from lib import *

TILE_S = 3.0                      # hex tile scale (source MiddleTile is 14.65 x 12.69)
R_HEX = 7.326 * TILE_S            # circumradius
TOP = 5.0                         # walk surface height; water surface is y = 0
WATER = 0.0

# fleet palette (ship colour, trim)
FLEETS = [
    dict(name='Teleporter1', title='AZURE FLEET', color=(52, 142, 230), trim=(24, 76, 150)),
    dict(name='Teleporter2', title='GOLDEN FLEET', color=(255, 196, 44), trim=(170, 110, 20)),
    dict(name='Teleporter3', title='CRIMSON FLEET', color=(222, 58, 52), trim=(128, 24, 26)),
]
WOOD = (143, 94, 58); WOOD_D = (104, 64, 38); WOOD_L = (190, 136, 84)
STONE = (140, 146, 160); STONE_D = (96, 101, 116)
GOLD = (255, 204, 58); WHITE = (242, 242, 236); GRASS = (120, 170, 40)

def hex_center(q, r):
    x = R_HEX * 1.5 * q
    z = R_HEX * math.sqrt(3) * (r + q / 2.0)
    return x, z
def hex_dist(q, r):
    return max(abs(q), abs(r), abs(q + r))
NEIGH = [(1, 0), (1, -1), (0, -1), (-1, 0), (-1, 1), (0, 1)]

class Ctx:
    def __init__(self, tree):
        self.root = tree.getroot()
        self.ss = [i for i in self.root.findall('Item') if i.get('class') == 'ServerStorage'][0]
        self.env = child(self.ss, 'ArmyEnvironment')
        self.assets = child(self.ss, 'ArmyAssets')
        self.tile = child(self.env, 'MiddleTile')
        self.ocean = child(self.env, 'Ocean')
        self.sands = [c for c in self.env.findall('Item') if name_of(c) == 'Sand']
        self.rocks = [c for c in self.env.findall('Item') if name_of(c) == 'MeshPart' and c.get('class') == 'MeshPart']
        self.levels = child(self.assets, 'BuildingLevels')
        self.resources = child(self.assets, 'Resources')
        self.entities = child(self.assets, 'Entities')
        self.bridge = child(self.assets, 'NativeBridge')
    def level(self, kind, lv):
        return child(child(self.levels, kind), str(lv))

def bottom_center(src):
    lo, hi = world_bbox(src)
    return np.array([(lo[0] + hi[0]) / 2, lo[1], (lo[2] + hi[2]) / 2]), lo, hi

def place_asset(ctx, parent, src, pos, yaw=0, s=1.0, name=None, collide=False, box=True, tags=None, sink=0.0,
                box_shrink=0.85, drop=None):
    """Clone `src` so that its bottom-centre lands on `pos` (world), rotated by yaw, scaled by s."""
    origin, lo, hi = bottom_center(src)
    placement = at(pos[0], pos[1] - sink, pos[2]) * ry(yaw)
    m = clone(src, placement, origin, s=s, collide=collide, name=name, stud_scale=min(s, 1.6), drop=drop)
    if m.get('class') != 'Model':
        wrapper = model(None, name or name_of(m))
        wrapper.append(m); m = wrapper
    if tags:
        set_prop(m, 'Tags', 'BinaryString', tags_b64(*tags))
    parent.append(m)
    if box:
        size = (hi - lo) * s
        part(m, 'Collision', (size[0] * box_shrink, size[1], size[2] * box_shrink),
             placement * CF((0, size[1] / 2, 0)) if True else None, (255, 255, 255), transparency=1,
             collide=True, query=False, shadow=False)
    return m

# ----------------------------------------------------------------------------- island
def island_tiles():
    tiles = {}
    for q in range(-3, 4):
        for r in range(-3, 4):
            d = hex_dist(q, r)
            if d <= 2:
                tiles[(q, r)] = 0
    # organic extra tiles (never on the harbour side, which stays straight)
    for qr in [(-3, 1), (-3, 2), (-2, 3), (-1, 3), (-3, 0), (1, -3), (0, -3), (-1, -2 + 0), (2, -3)]:
        if hex_dist(*qr) <= 3:
            tiles[qr] = 0
    # raised cliffs at the back of the island
    for qr in [(-3, 1), (-3, 2), (-2, 3)]:
        tiles[qr] = 1
    return tiles

def build_tiles(ctx, parent, tiles):
    folder_ = folder(parent, 'Island')
    src = ctx.tile
    root = child(src, 'Root')
    rcf = read_cf(getp(root, 'CFrame')); rsz = read_v3(getp(root, 'size'))
    origin = rcf.t + np.array([0, rsz[1] / 2, 0])
    for (q, r), lift in sorted(tiles.items()):
        x, z = hex_center(q, r)
        y = TOP + lift * 6.0
        m = clone(src, at(x, y, z), origin, s=TILE_S, collide=False, name='Tile', stud_scale=1.35)
        # the rectangular Root is replaced with an exact hexagonal collider
        for it in list(m.findall('Item')):
            if name_of(it) == 'Root':
                m.remove(it)
        folder_.append(m)
        side = R_HEX; flat = R_HEX * math.sqrt(3)
        for k, ang in enumerate((0, 60, 120)):
            part(m, 'Ground', (side, 1.0, flat), at(x, y - 0.5, z) * ry(ang), (120, 170, 40), transparency=1,
                 collide=True, query=True, shadow=False)
    return folder_

def perimeter_edges(tiles):
    edges = []
    for (q, r), lift in tiles.items():
        x, z = hex_center(q, r)
        for k, (dq, dr) in enumerate(NEIGH):
            n = (q + dq, r + dr)
            if n in tiles and tiles[n] == lift:
                continue
            nx, nz = hex_center(q + dq, r + dr)
            mx, mz = (x + nx) / 2, (z + nz) / 2
            ang = math.degrees(math.atan2(nz - z, nx - x))
            edges.append(((q, r), (dq, dr), (mx, mz), ang, lift, n in tiles))
    return edges

# ----------------------------------------------------------------------------- helpers in a local frame
def lp(parent, frame, name, size, local, color, **kw):
    return part(parent, name, size, frame * local, color, **kw)
def wedge(parent, frame, name, size, local, color, **kw):
    return part(parent, name, size, frame * local, color, cls='WedgePart', **kw)
def cyl_v(parent, frame, name, radius, height, local, color, **kw):
    """Vertical cylinder (Roblox cylinders run along X, so rotate 90 degrees about Z)."""
    return part(parent, name, (height, radius * 2, radius * 2), frame * local * rz(90), color, shape='cyl', **kw)
def ball(parent, frame, name, d, local, color, **kw):
    return part(parent, name, (d, d, d), frame * local, color, shape='ball', **kw)
def surface_text(parent_part, face, text, color=(255, 255, 255), stroke=(20, 20, 30), size=(400, 200), font='Legacy',
                 bg=None, name='Label', text_scaled=True, pixels=50):
    gui = item('SurfaceGui', name, [('Face', 'token', face), ('SizingMode', 'token', 1), ('PixelsPerStud', 'float', pixels),
                                    ('LightInfluence', 'float', 0.35), ('AlwaysOnTop', 'bool', False),
                                    ('ZIndexBehavior', 'token', 1)], parent_part)
    props = [('Size', 'UDim2', (1, 0, 1, 0)), ('BackgroundTransparency', 'float', 1 if bg is None else 0),
             ('Text', 'string', text), ('TextColor3', 'Color3', color), ('TextStrokeColor3', 'Color3', stroke),
             ('TextStrokeTransparency', 'float', 0), ('TextScaled', 'bool', text_scaled),
             ('FontFace', 'Font', ('rbxasset://fonts/families/LegacyArial.json', 700, 'Normal')),
             ('TextWrapped', 'bool', True), ('BorderSizePixel', 'int', 0)]
    if bg is not None:
        props.append(('BackgroundColor3', 'Color3', bg))
    item('TextLabel', 'Text', props, gui)
    return gui
def light(parent_part, color=(255, 214, 150), rng=16, brightness=1.4, shadows=False, kind='PointLight'):
    return item(kind, 'Light', [('Color', 'Color3', color), ('Range', 'float', rng), ('Brightness', 'float', brightness),
                                ('Shadows', 'bool', shadows), ('Enabled', 'bool', True)], parent_part)
def sparkles(parent_part, color=(255, 220, 90), rate=6, size=0.6, name='Sparkles'):
    return item('ParticleEmitter', name, [
        ('Color', 'ColorSequence', '0 %s %s %s 0 1 %s %s %s 0 ' % (color[0] / 255, color[1] / 255, color[2] / 255, 1, 1, 1)),
        ('LightEmission', 'float', 1), ('Rate', 'float', rate), ('Lifetime', 'NumberRange', '1.2 2.2 '),
        ('Speed', 'NumberRange', '1 3 '), ('SpreadAngle', 'Vector2', (180, 180)),
        ('Size', 'NumberSequence', '0 0 0 0.3 %s 0 1 0 0 ' % size),
        ('Transparency', 'NumberSequence', '0 0.2 0 1 1 0 '),
        ('Texture', 'ContentId', 'rbxasset://textures/particles/sparkles_main.dds'),
        ('ZOffset', 'float', 0.5)], parent_part)

# ----------------------------------------------------------------------------- ship
def build_ship(ctx, parent, fleet, center, index):
    """A square-rigged stud ship moored broadside to the quay. Local +X = bow, local -Z faces the quay."""
    m = model(parent, fleet['name'], tags=['LobbyTeleporter', 'LobbyShip'])
    F = at(center[0], TOP + 1.5, center[2]) * ry(90)          # deck top at y = TOP + 1.5
    hull, dark, deck = WOOD_D, (72, 44, 28), WOOD_L
    col, trim = fleet['color'], fleet['trim']
    L0, L1, W = -20.0, 12.0, 7.0                               # hull box from stern to bow start, half width
    body = model(m, 'Hull')
    lp(body, F, 'HullBody', (L1 - L0, 8, W * 2), at((L0 + L1) / 2, -4.2, 0), hull, variant='Studs')
    lp(body, F, 'Keel', (L1 - L0 - 4, 1.2, 3), at((L0 + L1) / 2, -8.4, 0), dark)
    # bow: two horizontal wedges make the V prow, a smaller pair makes the upper bulwark prow
    for sgn in (1, -1):
        R = np.column_stack([(0, -sgn, 0), (0, 0, sgn), (-1, 0, 0)])
        wedge(body, F, 'Prow', (8, W, 10), CF((L1 + 5, -4.2, sgn * W / 2), R), hull, variant='Studs')
        wedge(body, F, 'ProwStripe', (1.2, W + 0.15, 10.2), CF((L1 + 5.05, -2.4, sgn * (W / 2 + 0.07)), R), col)
        wedge(body, F, 'ProwRail', (1.6, W, 10), CF((L1 + 5, 0.8, sgn * W / 2), R), dark)
    # hull stripes + gold trim
    for sgn in (1, -1):
        lp(body, F, 'Stripe', (L1 - L0, 1.2, 0.3), at((L0 + L1) / 2, -2.4, sgn * (W + 0.1)), col, material='SmoothPlastic')
        lp(body, F, 'Trim', (L1 - L0, 0.35, 0.3), at((L0 + L1) / 2, -0.25, sgn * (W + 0.12)), GOLD, material='SmoothPlastic')
        for k in range(5):
            lp(body, F, 'Porthole', (1.4, 1.4, 0.3), at(L0 + 5 + k * 6, -4.6, sgn * (W + 0.1)), (30, 34, 48),
               material='SmoothPlastic', collide=False)
    # deck
    lp(m, F, 'Deck', (L1 - L0 + 1, 0.6, W * 2 - 1.2), at((L0 + L1) / 2 + 0.5, -0.3, 0), deck, variant='2022 Weld')
    # bulwarks with a boarding gap on the quay side (-Z) amidships
    rail = dark
    for sgn in (1, -1):
        if sgn == -1:
            lp(m, F, 'Bulwark', (13.5, 1.6, 0.8), at(L0 + 6.75, 0.8, sgn * (W - 0.4)), rail, variant='Studs')
            lp(m, F, 'Bulwark', (L1 - (L0 + 20.5), 1.6, 0.8), at((L0 + 20.5 + L1) / 2, 0.8, sgn * (W - 0.4)), rail, variant='Studs')
        else:
            lp(m, F, 'Bulwark', (L1 - L0, 1.6, 0.8), at((L0 + L1) / 2, 0.8, sgn * (W - 0.4)), rail, variant='Studs')
    lp(m, F, 'Bulwark', (0.8, 1.6, W * 2), at(L0 + 0.4, 0.8, 0), rail, variant='Studs')
    # stern castle (captain's cabin) with windows and a lantern
    cab = model(m, 'Cabin')
    lp(cab, F, 'CabinWalls', (7, 5.2, W * 2 - 1.6), at(L0 + 4.3, 2.6, 0), (126, 78, 46), variant='Studs')
    lp(cab, F, 'CabinRoof', (8, 0.8, W * 2), at(L0 + 4.3, 5.6, 0), dark, variant='Studs')
    lp(cab, F, 'CabinTrim', (8.3, 0.35, W * 2 + 0.3), at(L0 + 4.3, 5.05, 0), GOLD, material='SmoothPlastic')
    for sgn in (1, -1):
        for k in (-1, 1):
            lp(cab, F, 'Window', (1.6, 1.8, 0.2), at(L0 + 4.3 + k * 1.8, 2.9, sgn * (W - 0.72)), (255, 214, 120),
               material='Neon', collide=False)
    lp(cab, F, 'Door', (0.2, 3.6, 2.4), at(L0 + 7.85, 1.8, 0), (60, 36, 22), collide=False)
    lp(cab, F, 'SternWindow', (0.2, 1.6, 5), at(L0 - 0.02 + 0.8, 3.0, 0), (255, 214, 120), material='Neon', collide=False)
    lant = lp(cab, F, 'Lantern', (0.9, 1.2, 0.9), at(L0 + 1.2, 7.0, 0), (255, 206, 110), material='Neon', collide=False)
    light(lant, (255, 200, 120), 18, 1.6)
    # masts, yards and sails (sails face fore/aft)
    masts = model(m, 'Rigging')
    for mx, h, sw, sh in ((0.0, 30, 17, 14), (9.0, 22, 12, 9.5)):
        cyl_v(masts, F, 'Mast', 0.75, h, at(mx, h / 2, 0), (92, 58, 34), collide=True)
        lp(masts, F, 'Yard', (0.7, 0.7, sw + 2), at(mx + 0.4, h - 3.4, 0), (92, 58, 34), collide=False)
        lp(masts, F, 'Boom', (0.6, 0.6, sw), at(mx + 0.4, h - 5 - sh, 0), (92, 58, 34), collide=False)
        # bellied sail from three slightly offset strips
        top = h - 3.8; mid = top - sh / 2
        for k, dz in enumerate((-sw / 3, 0, sw / 3)):
            belly = 1.0 if dz == 0 else 0.55
            strip = lp(masts, F, 'Sail', (0.35, sh, sw / 3 + 0.05), at(mx + 0.6 + belly, mid, dz), col if k != 1 else WHITE,
                       material='SmoothPlastic', collide=False, tags=['LobbySail'])
            if k == 1 and h == 30:
                surface_text(strip, 0, ['I', 'II', 'III'][index], color=col, stroke=(30, 30, 40), name='Emblem')
                surface_text(strip, 3, ['I', 'II', 'III'][index], color=col, stroke=(30, 30, 40), name='EmblemBack')
    lp(masts, F, 'CrowsNest', (4.2, 1.0, 4.2), at(0, 21, 0) * ry(45), dark, variant='Studs', collide=False)
    flag = wedge(masts, F, 'Flag', (0.2, 3, 5), at(-2.5, 31.2, 0) * ry(90), col, collide=False, tags=['LobbyFlag'])
    lp(masts, F, 'Bowsprit', (10, 0.6, 0.6), at(L1 + 12, 2.6, 0) * rz(14), (92, 58, 34), collide=False)
    lp(masts, F, 'Figurehead', (1.6, 1.6, 1.6), at(L1 + 9.8, 0.4, 0) * ry(45), GOLD, material='SmoothPlastic', collide=False)
    # cannons poking over the far bulwark and the quay-side bulwark
    for sgn in (1, -1):
        for cx in (-6.0, 6.5):
            if sgn == -1 and -7 < cx < 2:
                continue
            c = part(m, 'Cannon', (3.2, 1.1, 1.1), F * at(cx, 1.3, sgn * (W - 1.0)) * ry(90), (44, 46, 54), shape='cyl',
                     material='SmoothPlastic', collide=False)
            lp(m, F, 'CannonCart', (1.6, 0.8, 1.8), at(cx, 0.4, sgn * (W - 2.2)), dark, collide=False)
    # cargo on the fore deck
    for (cx, cz, kind) in ((9.5, 4.2, 'crate'), (10.5, -4.5, 'barrel'), (8.2, -4.2, 'barrel'), (11.4, 4.0, 'barrel')):
        if kind == 'crate':
            lp(m, F, 'Crate', (2.2, 2.2, 2.2), at(cx, 1.1, cz) * ry(12), (170, 120, 70), variant='Studs', collide=False)
        else:
            cyl_v(m, F, 'Barrel', 0.9, 2.0, at(cx, 1.0, cz), (126, 78, 46), collide=False)
    # --- the room contract used by RoundServer -------------------------------------------------
    pad = lp(m, F, 'BeamPart', (L1 - (L0 + 8.5) + 6, 0.2, W * 2 - 1.6), at((L0 + 8.5 + L1 + 6) / 2, 0.1, 0),
             (100, 194, 246), transparency=1, collide=False, query=False, shadow=False)
    holder = lp(m, F, 'BillboardHolder', (0.2, 0.2, 0.2), at(0, 34.5, 0), (255, 255, 255), transparency=1,
                collide=False, query=False, shadow=False)
    # gangplank from quay to the gap in the bulwark
    gx = L0 + 17.0
    wx, wz = (F * at(gx, 0, -W)).tolist()[0], (F * at(gx, 0, -W)).tolist()[2]
    quay_edge = QUAY_X1
    run = (wx - quay_edge) + 1.0
    rise = (TOP + 1.5) - TOP
    ang = math.degrees(math.atan2(rise, run + 2))
    plank_c = at((quay_edge + wx) / 2 - 0.5, TOP + rise / 2 + 0.15, wz) * rz(ang)
    part(m, 'Gangplank', (run + 3, 0.4, 5.6), plank_c, WOOD_L, variant='2022 Weld')
    for sgn in (1, -1):
        part(m, 'GangRope', (run + 3, 0.25, 0.25), plank_c * at(0, 2.2, sgn * 2.7), (220, 200, 150), collide=False)
    leave = part(m, 'LeaveHere', (0.8, 0.2, 0.8), at(quay_edge - 8, TOP + 3.5, wz) * ry(90), (255, 255, 255),
                 transparency=1, collide=False, query=False, shadow=False)
    return m

QUAY_X0, QUAY_X1, QUAY_Z = 76.0, 96.0, 100.0
SHIP_Z = (-68.0, 0.0, 68.0)
SHIP_X = QUAY_X1 + 2.2 + 7.0

def build_quay(ctx, parent):
    q = model(parent, 'Harbour')
    part(q, 'QuayDeck', (QUAY_X1 - QUAY_X0, 1.0, QUAY_Z * 2), at((QUAY_X0 + QUAY_X1) / 2, TOP - 0.5, 0), WOOD_L,
         variant='2022 Weld')
    part(q, 'QuayEdge', (1.2, 1.2, QUAY_Z * 2), at(QUAY_X1 - 0.6, TOP - 0.4, 0), WOOD_D, variant='Studs')
    part(q, 'QuayUnder', (QUAY_X1 - QUAY_X0 - 2, 8, QUAY_Z * 2 - 2), at((QUAY_X0 + QUAY_X1) / 2, TOP - 5, 0), (72, 44, 28),
         collide=False)
    # pilings and bollards
    z = -QUAY_Z + 4
    while z < QUAY_Z:
        cyl_v(q, CF(), 'Piling', 0.9, 9, at(QUAY_X1 - 0.2, TOP - 4.1, z), (86, 54, 32), collide=False)
        z += 12
    for zc in SHIP_Z:
        for dz in (-17, 17):
            cyl_v(q, CF(), 'Bollard', 0.7, 1.6, at(QUAY_X1 - 1.8, TOP + 0.8, zc + dz), (50, 52, 60), material='SmoothPlastic')
            cyl_v(q, CF(), 'BollardCap', 0.9, 0.4, at(QUAY_X1 - 1.8, TOP + 1.7, zc + dz), (50, 52, 60), material='SmoothPlastic')
    # sea-side railings where no ship is moored, plus both ends
    gaps = []
    edges = [-QUAY_Z] + sum([[zc - 21, zc + 21] for zc in SHIP_Z], []) + [QUAY_Z]
    for a, b in zip(edges[0::2], edges[1::2]):
        gaps.append((a, b))
    for a, b in gaps:
        length = b - a
        if length < 1: continue
        part(q, 'Rail', (0.5, 0.5, length), at(QUAY_X1 - 0.5, TOP + 2.6, (a + b) / 2), WOOD_D, collide=False)
        part(q, 'RailLow', (0.4, 0.4, length), at(QUAY_X1 - 0.5, TOP + 1.4, (a + b) / 2), WOOD_D, collide=False)
        n = max(2, int(length / 5) + 1)
        for k in range(n):
            zz = a + k * length / (n - 1)
            part(q, 'RailPost', (0.6, 3.0, 0.6), at(QUAY_X1 - 0.5, TOP + 1.5, zz), WOOD_D, collide=False)
        part(q, 'RailBarrier', (1, 12, length), at(QUAY_X1 - 0.5, TOP + 6, (a + b) / 2), (255, 255, 255), transparency=1,
             collide=True, query=False, shadow=False)
    for zend in (-QUAY_Z, QUAY_Z):
        part(q, 'EndRail', (QUAY_X1 - QUAY_X0, 0.5, 0.5), at((QUAY_X0 + QUAY_X1) / 2, TOP + 2.6, zend), WOOD_D, collide=False)
        part(q, 'EndBarrier', (QUAY_X1 - QUAY_X0, 12, 1), at((QUAY_X0 + QUAY_X1) / 2, TOP + 6, zend), (255, 255, 255),
             transparency=1, collide=True, query=False, shadow=False)
    # fleet flag poles beside each gangplank
    for k, fl in enumerate(FLEETS):
        px, pz = QUAY_X0 + 4.0, SHIP_Z[k] - 10.0
        cyl_v(q, CF(), 'FlagPole', 0.35, 18, at(px, TOP + 9, pz), (220, 220, 220), material='SmoothPlastic', collide=False)
        ball(q, CF(), 'FlagTop', 0.9, at(px, TOP + 18.2, pz), GOLD, material='SmoothPlastic', collide=False)
        part(q, 'Flag', (0.2, 3.6, 6), at(px, TOP + 16, pz) * ry(90) * at(0, 0, -3), fl['color'],
             material='SmoothPlastic', collide=False, tags=['LobbyFlag'])
        cyl_v(q, CF(), 'FlagBase', 1.1, 0.8, at(px, TOP + 0.4, pz), (60, 62, 72), material='SmoothPlastic')
    # west-side railings where the quay runs out over open water
    for (a, b) in ((57.0, QUAY_Z), (-QUAY_Z, -95.0)):
        length = b - a
        part(q, 'Rail', (0.5, 0.5, length), at(QUAY_X0 + 0.5, TOP + 2.6, (a + b) / 2), WOOD_D, collide=False)
        n = max(2, int(length / 5) + 1)
        for k in range(n):
            part(q, 'RailPost', (0.6, 3.0, 0.6), at(QUAY_X0 + 0.5, TOP + 1.5, a + k * length / (n - 1)), WOOD_D, collide=False)
        part(q, 'RailBarrier', (1, 12, length), at(QUAY_X0 + 0.5, TOP + 6, (a + b) / 2), (255, 255, 255), transparency=1,
             collide=True, query=False, shadow=False)
    # harbour lamps
    for zz in (-90, -34, 34, 90):
        post = part(q, 'LampPost', (0.7, 9, 0.7), at(QUAY_X0 + 2.5, TOP + 4.5, zz), (48, 50, 58), material='SmoothPlastic')
        part(q, 'LampArm', (2.2, 0.4, 0.4), at(QUAY_X0 + 3.4, TOP + 8.8, zz), (48, 50, 58), material='SmoothPlastic', collide=False)
        lamp = part(q, 'Lamp', (1.1, 1.3, 1.1), at(QUAY_X0 + 4.3, TOP + 8.1, zz), (255, 214, 130), material='Neon', collide=False)
        light(lamp, (255, 205, 130), 22, 1.2)
    # cargo stacks
    rnd = random.Random(3)
    for zz in (-46, 44, 92, -92):
        for k in range(3):
            s = 2.4
            part(q, 'Crate', (s, s, s), at(QUAY_X0 + 5 + (k % 2) * 2.6, TOP + s / 2 + (k // 2) * s, zz + (k % 2) * 0.3) * ry(rnd.uniform(-8, 8)),
                 (170, 120, 70) if k != 1 else (140, 96, 58), variant='Studs')
        cyl_v(q, CF(), 'Barrel', 0.95, 2.2, at(QUAY_X0 + 11, TOP + 1.1, zz - 2), (126, 78, 46))
    return q

# ----------------------------------------------------------------------------- lighthouse
def build_lighthouse(ctx, parent, pos):
    m = model(parent, 'Lighthouse')
    x, y, z = pos
    F = at(x, y, z)
    cyl_v(m, F, 'Base', 7.5, 3, at(0, 1.5, 0), STONE_D, variant='2022 Stud')
    cyl_v(m, F, 'BaseTop', 6.5, 1, at(0, 3.5, 0), STONE, variant='2022 Stud')
    h = 4.0; yy = 4.0
    for k in range(6):
        r = 5.0 - k * 0.35
        cyl_v(m, F, 'Tower', r, h, at(0, yy + h / 2, 0), (228, 52, 46) if k % 2 == 0 else WHITE, variant='Studs')
        yy += h
    cyl_v(m, F, 'Gallery', 4.6, 0.8, at(0, yy + 0.4, 0), (60, 62, 72), material='SmoothPlastic')
    for k in range(12):
        a = k * 30
        part(m, 'GalleryPost', (0.3, 2, 0.3), F * ry(a) * at(4.3, yy + 1.8, 0), (60, 62, 72), material='SmoothPlastic', collide=False)
    cyl_v(m, F, 'GalleryRail', 4.45, 0.3, at(0, yy + 2.8, 0), (60, 62, 72), material='SmoothPlastic', collide=False)
    lamp = cyl_v(m, F, 'LampRoom', 2.6, 4, at(0, yy + 2.8, 0), (255, 232, 150), material='Neon', collide=False)
    light(lamp, (255, 226, 150), 60, 2.2)
    cyl_v(m, F, 'LampCap', 3.2, 0.8, at(0, yy + 5.2, 0), (228, 52, 46), variant='Studs', collide=False)
    cyl_v(m, F, 'LampCap2', 2.2, 1.2, at(0, yy + 6.2, 0), (228, 52, 46), variant='Studs', collide=False)
    ball(m, F, 'LampTop', 1.4, at(0, yy + 7.2, 0), GOLD, material='SmoothPlastic', collide=False)
    beam = model(m, 'Beacon', tags=['LobbySpin'])
    for sgn in (1, -1):
        part(beam, 'Beam', (22, 1.2, 1.2), F * at(sgn * 12.5, yy + 2.8, 0), (255, 240, 170), material='Neon',
             transparency=0.72, collide=False, query=False, shadow=False)
    part(beam, 'Hub', (1, 1, 1), F * at(0, yy + 2.8, 0), (255, 240, 170), transparency=1, collide=False, query=False, shadow=False)
    part(m, 'Door', (0.3, 4.4, 2.8), F * ry(200) * at(4.95, 6.2, 0), (86, 54, 32), collide=False)
    part(m, 'Collision', (11, 30, 11), F * at(0, 15, 0), (255, 255, 255), transparency=1, query=False, shadow=False)
    return m

# ----------------------------------------------------------------------------- admin vault (Robux shop)
def build_vault(ctx, parent, pos, yaw):
    """Open-front treasure hall. Local -Z is the front that faces the plaza."""
    m = model(parent, 'AdminVault', tags=['LobbyShop'])
    F = at(pos[0], pos[1], pos[2]) * ry(yaw)
    wall = (74, 58, 110); wall2 = (96, 76, 142); dark = (46, 36, 72)
    part(m, 'Plinth', (28, 1.4, 22), F * at(0, 0.7, 1), STONE_D, variant='2022 Stud')
    part(m, 'Step', (12, 0.7, 3), F * at(0, 0.35, -11.2), STONE, variant='2022 Stud')
    part(m, 'BackWall', (24, 14, 1.6), F * at(0, 8.4, 10.2), wall, variant='2022 Inlet')
    for sgn in (1, -1):
        part(m, 'SideWall', (1.6, 14, 18), F * at(sgn * 11.2, 8.4, 2.0), wall, variant='2022 Inlet')
        part(m, 'Column', (2.6, 14.6, 2.6), F * at(sgn * 11.2, 8.7, -7.6), GOLD, material='SmoothPlastic')
        part(m, 'ColumnBase', (3.4, 1, 3.4), F * at(sgn * 11.2, 1.9, -7.6), dark, variant='Studs')
        part(m, 'ColumnCap', (3.4, 1, 3.4), F * at(sgn * 11.2, 15.6, -7.6), dark, variant='Studs')
        # banners
        ban = part(m, 'Banner', (0.2, 7, 3.4), F * at(sgn * 12.1, 9.5, -2) , (222, 58, 52) if sgn > 0 else (52, 142, 230),
                   material='SmoothPlastic', collide=False)
    part(m, 'Floor', (21, 0.4, 17), F * at(0, 1.6, 1.8), (60, 48, 92), variant='2022 Diamond Stud')
    part(m, 'Carpet', (6, 0.1, 15), F * at(0, 1.85, 0.5), (190, 40, 50), material='Fabric', collide=False)
    part(m, 'Roof', (27, 1.6, 22), F * at(0, 16.2, 1), dark, variant='Studs')
    part(m, 'RoofTrim', (27.4, 0.6, 22.4), F * at(0, 15.2, 1), GOLD, material='SmoothPlastic')
    part(m, 'RoofTop', (20, 1.2, 15), F * at(0, 17.6, 1), wall2, variant='Studs')
    # sign over the entrance
    sign = part(m, 'Sign', (18, 3.6, 0.6), F * at(0, 13.2, -8.6), (40, 30, 60), variant='Studs', collide=False)
    surface_text(sign, 5, 'ADMIN VAULT', color=GOLD, stroke=(40, 20, 0), name='SignText')
    part(m, 'SignTrim', (18.6, 4.2, 0.4), F * at(0, 13.2, -8.4), GOLD, material='SmoothPlastic', collide=False)
    # counter + shopkeeper
    counter = part(m, 'Counter', (14, 3.4, 2.4), F * at(0, 3.5, -3.4), (126, 78, 46), variant='Studs')
    part(m, 'CounterTop', (14.6, 0.5, 3.0), F * at(0, 5.4, -3.4), GOLD, material='SmoothPlastic')
    item('ProximityPrompt', 'DonationShopPrompt', [
        ('ActionText', 'string', 'Open Vault'), ('ObjectText', 'string', 'Admin Vault'),
        ('HoldDuration', 'float', 0.15), ('MaxActivationDistance', 'float', 16), ('RequiresLineOfSight', 'bool', False),
        ('KeyboardKeyCode', 'token', 101), ('Enabled', 'bool', True), ('Style', 'token', 0)], counter)
    wiz = child(ctx.entities, 'Wizard')
    if wiz is not None:
        place_asset(ctx, m, wiz, (F * at(0, 1.8, 0.8)).tolist(), yaw=yaw + 180 + 90, s=3.0, name='Keeper',
                    collide=False, box=False, tags=['LobbyNPC'])
    # treasure: coin stacks, chests and crystals inside
    for (cx, cz) in ((-7.5, 6), (7.5, 6), (-4, 7.8), (4.5, 8)):
        for k in range(4):
            part(m, 'Coins', (0.5, 1.6, 1.6), F * at(cx + k * 0.2, 2.1 + k * 0.5, cz) * rz(90), GOLD, shape='cyl',
                 material='SmoothPlastic', collide=False)
    for sgn in (1, -1):
        chest = part(m, 'Chest', (3.2, 2, 2.2), F * at(sgn * 7.5, 2.8, 3), (126, 78, 46), variant='Studs', collide=False)
        part(m, 'ChestLid', (3.3, 0.7, 2.3), F * at(sgn * 7.5, 4.1, 3), (104, 64, 38), variant='Studs', collide=False)
        part(m, 'ChestBand', (0.4, 2.8, 2.35), F * at(sgn * 7.5, 3.1, 3), GOLD, material='SmoothPlastic', collide=False)
    glow = part(m, 'Glow', (1, 1, 1), F * at(0, 9, 3), (255, 220, 120), transparency=1, collide=False, query=False, shadow=False)
    light(glow, (255, 214, 120), 24, 1.6)
    # giant rotating crown on the roof
    crown = model(m, 'Crown', tags=['LobbySpin'])
    C = F * at(0, 22.5, 1)
    n = 10; rad = 4.2
    for k in range(n):
        a = k * 360 / n
        part(crown, 'Band', (2.8, 3.2, 0.9), C * ry(a) * at(0, 0, rad), GOLD, material='SmoothPlastic', collide=False,
             query=False)
    for k in range(5):
        a = k * 72
        part(crown, 'Spike', (1.6, 3.0, 1.6), C * ry(a) * at(0, 2.9, rad) * rz(45) * rx(0), GOLD, material='SmoothPlastic',
             collide=False, query=False)
        ball(crown, C * ry(a), 'Gem', 1.3, at(0, 0.2, rad + 0.55), [(255, 60, 70), (70, 160, 255), (80, 220, 110),
             (190, 90, 255), (255, 150, 40)][k], material='Neon', collide=False, query=False)
        ball(crown, C * ry(a), 'Pearl', 0.9, at(0, 4.6, rad), WHITE, material='SmoothPlastic', collide=False, query=False)
    core = part(crown, 'Hub', (1, 1, 1), C, GOLD, transparency=1, collide=False, query=False, shadow=False)
    light(core, (255, 210, 90), 26, 2)
    sparkles(core, rate=8, size=0.8)
    part(m, 'Collision', (26, 16, 1.5), F * at(0, 9, 10.5), (255, 255, 255), transparency=1, query=False, shadow=False)
    return m

# ----------------------------------------------------------------------------- plaza, props
def build_plaza(ctx, parent):
    m = model(parent, 'Plaza')
    F = at(0, TOP, 0)
    part(m, 'Paving', (0.4, 34, 34), F * at(0, 0.2, 0) * rz(90), (160, 150, 132), shape='cyl', variant='2022 Stud')
    part(m, 'PavingRing', (0.3, 36, 36), F * at(0, 0.12, 0) * rz(90), (112, 104, 94), shape='cyl', variant='2022 Stud')
    # paths: to harbour (east), to vault (north-east), to town hall (west), south to the sawmill
    paths = [((18, 0), (QUAY_X0 + 1, 0), 9), ((12, -12), (30, -40), 7), ((-16, 0), (-52, 0), 8), ((0, 17), (0, 60), 6),
             ((40, 0), (QUAY_X0, -60), 6), ((40, 0), (QUAY_X0, 60), 6)]
    for (a, b, w) in paths:
        dx, dz = b[0] - a[0], b[1] - a[1]
        length = math.hypot(dx, dz)
        yaw = -math.degrees(math.atan2(dz, dx))
        part(m, 'Path', (length, 0.3, w), at((a[0] + b[0]) / 2, TOP + 0.15, (a[1] + b[1]) / 2) * ry(yaw), (150, 112, 74),
             variant='2022 Weld', collide=False, query=False)
    # war table: a miniature of the battlefield with tiny armies
    T = F * at(-2, 0, 11)
    cyl_v(m, T, 'TableLeg', 1.2, 3.2, at(0, 1.6, 0), (86, 54, 32))
    cyl_v(m, T, 'TableTop', 5.4, 0.6, at(0, 3.5, 0), (126, 78, 46), variant='Studs')
    cyl_v(m, T, 'TableRim', 5.8, 0.4, at(0, 3.25, 0), GOLD, material='SmoothPlastic')
    src = ctx.tile; root = child(src, 'Root')
    rcf = read_cf(getp(root, 'CFrame')); rsz = read_v3(getp(root, 'size'))
    origin = rcf.t + np.array([0, rsz[1] / 2, 0])
    mini = model(m, 'MiniMap')
    ms = 0.2; mr = 7.326 * ms
    for (q, r) in [(0, 0)] + NEIGH:
        x = mr * 1.5 * q; z = mr * math.sqrt(3) * (r + q / 2)
        tl = clone(src, T * at(x, 3.9 + (0.15 if (q, r) == (0, 0) else 0), z), origin, s=ms, collide=False, name='MiniTile',
                   stud_scale=0.3, drop=lambda it: name_of(it) == 'Root')
        mini.append(tl)
    for k, (kind, q, r) in enumerate((('Barbarian', 1, 0), ('Archer', -1, 1), ('Giant', 0, -1), ('Wizard', 1, -1))):
        e = child(ctx.entities, kind)
        if e is not None:
            x = mr * 1.5 * q; z = mr * math.sqrt(3) * (r + q / 2)
            place_asset(ctx, mini, e, (T * at(x, 3.9, z)).tolist(), yaw=k * 70, s=0.55, collide=False, box=False)
    # notice board
    B = F * at(-9, 0, -12) * ry(37)          # text side (+Z, Back face) looks at the plaza centre
    part(m, 'BoardPost', (0.8, 7, 0.8), B * at(-3.4, 3.5, 0), WOOD_D)
    part(m, 'BoardPost', (0.8, 7, 0.8), B * at(3.4, 3.5, 0), WOOD_D)
    board = part(m, 'Board', (7.6, 4.6, 0.5), B * at(0, 4.8, 0), WOOD_L, variant='Studs')
    part(m, 'BoardRoof', (8.6, 0.5, 1.6), B * at(0, 7.3, 0) , WOOD_D, variant='Studs')
    surface_text(board, 2, 'BOARD A SHIP TO SAIL INTO BATTLE\nBuild - Train - Conquer\nWin the roulette and TYPE THE COMMAND',
                 color=(40, 26, 12), stroke=(255, 236, 200), name='HowTo', font='Legacy')
    # campfire
    C = F * at(-12, 0, 6)
    for k in range(7):
        part(m, 'FireStone', (1.2, 0.8, 1.2), C * ry(k * 360 / 7) * at(2.2, 0.4, 0), STONE_D, variant='2022 Stud', collide=False)
    for k in range(3):
        part(m, 'Log', (3.4, 0.6, 0.6), C * ry(k * 60) * at(0, 0.5, 0), (104, 64, 38), shape='cyl', collide=False)
    fire = part(m, 'FireCore', (1, 1, 1), C * at(0, 1.2, 0), (255, 140, 40), transparency=1, collide=False, query=False, shadow=False)
    item('Fire', 'Fire', [('size_xml', 'float', 4), ('heat_xml', 'float', 6), ('Color', 'Color3', (255, 150, 60)),
                          ('SecondaryColor', 'Color3', (255, 60, 20)), ('Enabled', 'bool', True)], fire)
    light(fire, (255, 160, 80), 18, 2)
    return m

def build_fence_and_walls(ctx, parent, tiles):
    m = model(parent, 'Boundary')
    for (qr, d, (mx, mz), ang, lift, neighbour_exists) in perimeter_edges(tiles):
        if neighbour_exists:
            continue            # height step between two land tiles: no fence
        if mx > QUAY_X0 - 2 and abs(mz) < QUAY_Z + 8:
            continue            # harbour side is open to the quay
        # edge direction is perpendicular to the centre->neighbour direction
        yaw = -(ang + 90)
        y = TOP + lift * 6.0
        E = at(mx, y, mz) * ry(yaw)
        # pull the fence slightly inside the tile edge
        inward = np.array(hex_center(*qr)) - np.array([mx, mz]); inward /= np.linalg.norm(inward)
        E = at(mx + inward[0] * 1.2, y, mz + inward[1] * 1.2) * ry(yaw)
        L = R_HEX
        part(m, 'FenceRail', (L, 0.5, 0.4), E * at(0, 2.4, 0), WOOD, collide=False)
        part(m, 'FenceRail', (L, 0.5, 0.4), E * at(0, 1.2, 0), WOOD, collide=False)
        for k in range(4):
            part(m, 'FencePost', (0.7, 3.2, 0.7), E * at(-L / 2 + k * L / 3, 1.6, 0), WOOD_D, collide=False)
        part(m, 'Wall', (L + 1, 14, 1), E * at(0, 7, 0), (255, 255, 255), transparency=1, collide=True, query=False, shadow=False)
    return m

# ----------------------------------------------------------------------------- assembly
def tc(q, r, dx=0.0, dz=0.0, lift=0):
    x, z = hex_center(q, r)
    return (x + dx, TOP + lift * 6.0, z + dz)

BUILDINGS = [
    # kind, level, tile, offset, yaw, scale
    ('Townhall', 4, (-2, 1), (0, 0), 90, 4.2),
    ('Barracks', 4, (-1, -1), (-2, 2), 30, 4.0),
    ('Campsite', 4, (-2, 0), (0, 0), 0, 3.0),
    ('LumberHut', 4, (-1, 2), (0, 0), -30, 4.0),
    ('Sawmill', 4, (0, 2), (0, 2), 0, 3.6),
    ('Goldmine', 3, (1, 1), (4, 4), -60, 4.2),
    ('Foundry', 3, (-2, 2), (0, 0), 45, 3.6),
    ('MinerHut', 4, (-3, 0), (4, 0), 90, 4.0),
    ('CrystalMinerhut', 3, (1, -3), (-2, 0), 150, 3.6),
    ('BuilderHut', 4, (-1, -2), (0, 0), 20, 4.0),
    ('OreMinerHut', 3, (0, -3), (0, 0), 180, 3.6),
    ('TrainingCamp', 3, (0, -2), (0, 0), 0, 3.4),
]
NPCS = [
    # entity, position, yaw, scale
    ('Giant', tc(-2, 1, 14, 12), 100, 3.0),
    ('Barbarian', tc(-1, -1, 10, 12), 210, 3.0),
    ('Barbarian', tc(-1, -1, 15, 8), 225, 3.0),
    ('Archer', tc(-1, -1, 13, 16), 200, 3.0),
    ('Archer', tc(2, -2, -6, 6), 270, 3.0),
    ('Lumberjack', tc(-1, 2, 12, -6), 120, 3.0),
    ('Miner', tc(-3, 0, 14, 8), 60, 3.0),
    ('Builder', tc(-1, -2, 10, 8), 160, 3.0),
    ('Wizard', tc(0, -2, 10, 10), 200, 3.0),
    ('Barbarian', tc(2, 0, -8, 10), 270, 3.0),
]
TREES = {
    (-3, 1): 7, (-3, 2): 7, (-2, 3): 6, (-1, 3): 5, (-1, 2): 3, (0, 2): 2, (-2, 2): 3, (-3, 0): 3,
    (-2, 0): 2, (-1, -2): 3, (0, -3): 2, (-1, 1): 2, (1, 1): 2, (-2, 1): 2, (-1, -1): 1, (0, 1): 1,
}
ROCKS = [('Stone', (-3, 0), 4), ('Stone', (-1, 1), 2), ('Iron Ore', (0, -3), 4), ('Iron Ore', (-2, 2), 3),
         ('Crystal', (1, -3), 4), ('Crystal', (1, -2), 3), ('Stone', (0, 1), 2), ('Stone', (2, 0), 1)]
BLOCKERS = [(0, 0, 24)]   # plaza keeps clear

def clear_spot(x, z, r, taken):
    if math.hypot(x, z) < 24: return False
    if x > QUAY_X0 - 6: return False
    for (a, b, rr) in taken:
        if math.hypot(x - a, z - b) < r + rr: return False
    return True

def build(tree):
    ctx = Ctx(tree)
    rnd = random.Random(11)
    lobby = model(None, 'LobbyWorld')
    scen = folder(lobby, 'Scenery')
    tiles = island_tiles()
    build_tiles(ctx, scen, tiles)
    oc = clone(ctx.ocean, at(0, WATER, 0), read_cf(getp(child(ctx.ocean, 'OceanTop'), 'CFrame')).t, s=1.0,
               collide=False, name='Ocean')
    scen.append(oc)
    # an invisible sea floor catches anybody who falls in; RoundServer returns them to the spawn
    part(scen, 'SeaFloor', (2000, 2, 2000), at(0, WATER - 7, 0), (40, 120, 200), transparency=1, collide=True,
         query=False, shadow=False)
    build_quay(ctx, scen)
    build_plaza(ctx, scen)
    build_fence_and_walls(ctx, scen, tiles)
    build_lighthouse(ctx, scen, tc(2, -3, -4, -6))
    vx, vy, vz = tc(1, -2, 2, 0)
    build_vault(ctx, scen, (vx, vy, vz), 150)
    taken = [(vx, vz, 18), (62, -82, 10)]
    town = folder(scen, 'Village')
    for kind, lv, (q, r), (dx, dz), yaw, s in BUILDINGS:
        src = ctx.level(kind, lv)
        if src is None:
            continue
        pos = tc(q, r, dx, dz, tiles.get((q, r), 0))
        place_asset(ctx, town, src, pos, yaw=yaw, s=s, name=kind, collide=False, box=True, box_shrink=0.8)
        lo, hi = world_bbox(src)
        taken.append((pos[0], pos[2], max(hi[0] - lo[0], hi[2] - lo[2]) * s * 0.55))
    npcs = folder(scen, 'Garrison')
    for kind, pos, yaw, s in NPCS:
        src = child(ctx.entities, kind)
        place_asset(ctx, npcs, src, pos, yaw=yaw, s=s, name=kind, collide=False, box=True, tags=['LobbyNPC'], box_shrink=0.7)
        taken.append((pos[0], pos[2], 3))
    nature = folder(scen, 'Nature')
    tree_src = child(ctx.resources, 'Pine Tree')
    for (q, r), n in TREES.items():
        if (q, r) not in tiles: continue
        cx, cz = hex_center(q, r); lift = tiles[(q, r)]
        placed = 0; tries = 0
        while placed < n and tries < 200:
            tries += 1
            ang = rnd.uniform(0, math.tau); rad = rnd.uniform(4, 16)
            x, z = cx + math.cos(ang) * rad, cz + math.sin(ang) * rad
            if not clear_spot(x, z, 4, taken): continue
            s = rnd.uniform(5.5, 7.5)
            place_asset(ctx, nature, tree_src, (x, TOP + lift * 6.0, z), yaw=rnd.uniform(0, 360), s=s, name='Pine Tree',
                        collide=False, box=True, box_shrink=0.3, tags=['LobbyTree'])
            taken.append((x, z, 3.5)); placed += 1
    for kind, (q, r), n in ROCKS:
        src = child(ctx.resources, kind)
        cx, cz = hex_center(q, r); lift = tiles.get((q, r), 0)
        placed = 0; tries = 0
        while placed < n and tries < 200:
            tries += 1
            ang = rnd.uniform(0, math.tau); rad = rnd.uniform(5, 16)
            x, z = cx + math.cos(ang) * rad, cz + math.sin(ang) * rad
            if not clear_spot(x, z, 3, taken): continue
            s = rnd.uniform(3.2, 4.4)
            place_asset(ctx, nature, src, (x, TOP + lift * 6.0, z), yaw=rnd.uniform(0, 360), s=s, name=kind,
                        collide=False, box=True, box_shrink=0.6)
            taken.append((x, z, 3)); placed += 1
    # sea rocks and beaches around the island (never inside the harbour lane)
    sea = folder(scen, 'Coast')
    for k, (x, z, s, yaw) in enumerate([(-150, -60, 3.2, 20), (-140, 70, 2.6, 80), (-60, 150, 3.0, 140), (40, 150, 2.4, 200),
                                        (-40, -165, 2.8, 30), (150, -150, 2.2, 70), (-175, 5, 2.0, 110), (170, 150, 2.6, 10)]):
        src = ctx.rocks[k % len(ctx.rocks)]
        place_asset(ctx, sea, src, (x, WATER - 3, z), yaw=yaw, s=s, name='SeaRock', collide=False, box=False)
    for k, (x, z, yaw) in enumerate([(-128, -40, 90), (-125, 45, 80), (-92, 102, 45), (-50, 128, 10), (18, 128, -20),
                                     (-72, -100, 130), (-20, -140, 170), (40, -128, 200)]):
        src = ctx.sands[k % len(ctx.sands)]
        place_asset(ctx, sea, src, (x, WATER - 0.9, z), yaw=yaw, s=1.25, name='Beach', collide=False, box=False)
    # ships (the three rooms)
    harbour = folder(lobby, 'NativeTeleporters')
    for i, fl in enumerate(FLEETS):
        build_ship(ctx, harbour, fl, (SHIP_X, 0, SHIP_Z[i]), i)
    spawn_cf = at(-8, TOP + 0.1, 0) * ry(-90)
    return lobby, ctx, tiles, spawn_cf
