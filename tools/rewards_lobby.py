"""Lobby extras: the like/favourite reward chest next to the shop and the five hidden promo-code signs."""
import math
import numpy as np
from lib import *
import lobby as L
from lobby import TOP, WATER, hex_center, R_HEX, part, cyl_v, light, model, folder, surface_text

FRED = ('rbxasset://fonts/families/FredokaOne.json', 700, 'Normal')
GOLD = (255, 204, 58)
WOOD = (126, 78, 46)
WOOD_D = (92, 56, 34)
INK = (34, 27, 20)
# SurfaceGui faces (Enum.NormalId)
TOP_FACE, FRONT_FACE = 1, 5

CODES = ['NOOB', 'METEOR', 'GIANT', 'FREEZE', 'SECRETADMIN']


def face_yaw(vx, vz):
    """ry() angle that makes a part's Front face (-Z) look along (vx, vz)."""
    return math.degrees(math.atan2(-vx, -vz))


def unit(x, z):
    n = math.hypot(x, z)
    return x / n, z / n


def text(parent_part, face, title, big, color=GOLD, pixels=60, sub_color=(255, 255, 255)):
    gui = item('SurfaceGui', 'CodeText', [('Face', 'token', face), ('SizingMode', 'token', 1), ('PixelsPerStud', 'float', pixels),
                                          ('LightInfluence', 'float', 0.2), ('ZIndexBehavior', 'token', 1)], parent_part)
    for name, txt, y, h, col in (('Title', title, 0.04, 0.3, sub_color), ('Code', big, 0.36, 0.6, color)):
        if not txt:
            continue
        item('TextLabel', name, [('Size', 'UDim2', (0.92, 0, h, 0)), ('Position', 'UDim2', (0.04, 0, y, 0)),
                                 ('BackgroundTransparency', 'float', 1), ('Text', 'string', txt), ('TextColor3', 'Color3', col),
                                 ('TextStrokeColor3', 'Color3', INK), ('TextStrokeTransparency', 'float', 0),
                                 ('TextScaled', 'bool', True), ('FontFace', 'Font', FRED), ('BorderSizePixel', 'int', 0)], gui)
    return gui


def billboard(parent_part, lines, offset_y, size=(10, 4), max_distance=90):
    gui = item('BillboardGui', 'Label', [('Size', 'UDim2', (size[0], 0, size[1], 0)), ('StudsOffset', 'Vector3', (0, offset_y, 0)),
                                         ('MaxDistance', 'float', max_distance), ('LightInfluence', 'float', 0),
                                         ('AlwaysOnTop', 'bool', False), ('ZIndexBehavior', 'token', 1)], parent_part)
    y = 0.0
    for txt, h, col in lines:
        item('TextLabel', 'Line', [('Size', 'UDim2', (1, 0, h, 0)), ('Position', 'UDim2', (0, 0, y, 0)),
                                   ('BackgroundTransparency', 'float', 1), ('Text', 'string', txt), ('TextColor3', 'Color3', col),
                                   ('TextStrokeColor3', 'Color3', INK), ('TextStrokeTransparency', 'float', 0),
                                   ('TextScaled', 'bool', True), ('FontFace', 'Font', FRED), ('BorderSizePixel', 'int', 0)], gui)
        y += h
    return gui


# ------------------------------------------------------------------ positions
def spots(tiles, shop_pos, spawn):
    """Decided before anything else is placed, so props, trees and houses keep clear of them."""
    sx, sz = shop_pos
    tsx, tsz = unit(spawn[0] - sx, spawn[1] - sz)          # shop -> spawn
    left = (-tsz, tsx)                                      # player's left while facing the shop from the spawn side
    chest = (sx + left[0] * 17 + tsx * 2, sz + left[1] * 17 + tsz * 2)
    zone = (chest[0] + tsx * 4.2, chest[1] + tsz * 4.2)
    out = {'chest': chest, 'zone': zone, 'chest_face': (tsx, tsz)}
    # 1: behind the middle 0/6 room square, readable only from behind it
    out['code1'] = (64.0 + 13, 0.0 + 3)
    out['code1_face'] = (1.0, 0.0)
    # 2: on the back wall of the shop
    out['code2'] = (sx - tsx * 12.5, sz - tsz * 12.5)
    out['code2_face'] = (-tsx, -tsz)
    far = sorted(tiles, key=lambda qr: -math.hypot(hex_center(*qr)[0] - spawn[0], hex_center(*qr)[1] - spawn[1]))
    # 3: flat stone in the grass on the farthest lifted (forest) tile
    lifted = [qr for qr in far if tiles[qr] > 0] or far
    q3 = lifted[0]
    cx, cz = hex_center(*q3)
    out['code3'] = (cx + 3, cz - 2, tiles[q3])
    # 4: top of a crate tower on a mid-distance plain tile, away from the rooms and the shop
    mids = [qr for qr in tiles if tiles[qr] == 0 and 45 < math.hypot(hex_center(*qr)[0] - spawn[0], hex_center(*qr)[1] - spawn[1]) < 75
            and hex_center(*qr)[0] < 20]
    mids.sort(key=lambda qr: (hex_center(*qr)[1], hex_center(*qr)[0]))
    q4 = mids[-1] if mids else far[3]
    cx, cz = hex_center(*q4)
    out['code4'] = (cx, cz)
    # 5: on the water just outside the fence, at the corner farthest from the spawn
    beaches = [(-128, -40), (-125, 45), (-92, 102), (-50, 128), (18, 128), (-72, -100), (-20, -140), (40, -128), (128, 60), (125, -60)]
    rocks = [(-150, -60), (-140, 70), (-60, 160), (60, 165), (-40, -170), (170, -90), (-180, 5), (175, 110)]
    def clear_water(e):
        mx, mz = e[2]
        return all(math.hypot(mx - bx, mz - bz) > 34 for bx, bz in beaches + rocks)
    edges = [e for e in L.perimeter_edges(tiles) if not e[5] and clear_water(e)]
    best = max(edges, key=lambda e: math.hypot(e[2][0] - spawn[0], e[2][1] - spawn[1]) + (5 if e[0] != q3 else 0))
    (q, r), _, (mx, mz), ang, lift, _n = best
    ox, oz = unit(mx - hex_center(q, r)[0], mz - hex_center(q, r)[1])
    out['code5'] = (mx + ox * 5.5, mz + oz * 5.5, ox, oz)
    return out


def reserve(spots_, taken):
    taken.append((spots_['chest'][0], spots_['chest'][1], 7))
    taken.append((spots_['zone'][0], spots_['zone'][1], 6))
    taken.append((spots_['code1'][0], spots_['code1'][1], 4))
    taken.append((spots_['code2'][0], spots_['code2'][1], 3))
    taken.append((spots_['code3'][0], spots_['code3'][1], 5))
    taken.append((spots_['code4'][0], spots_['code4'][1], 9))


# ------------------------------------------------------------------ geometry
def build(scen, spots_, lift_at):
    root = folder(scen, 'Rewards')
    # ---------------------------------------------------------- reward chest + zone
    cx, cz = spots_['chest']
    fx, fz = spots_['chest_face']
    y0 = TOP + lift_at(cx, cz) * 6.0
    m = model(root, 'RewardChest')
    F = at(cx, y0, cz) * ry(face_yaw(fx, fz))
    part(m, 'Pedestal', (7.2, 0.8, 5.6), F * at(0, 0.4, 0), (120, 124, 136), variant='2022 Stud')
    part(m, 'Body', (6, 3.4, 4.2), F * at(0, 2.5, 0), WOOD, variant='Studs')
    part(m, 'Lid', (6.2, 1.2, 4.4), F * at(0, 4.8, 0), WOOD_D, variant='Studs')
    part(m, 'LidTop', (5.6, 0.6, 3.6), F * at(0, 5.7, 0), WOOD_D, variant='Studs')
    for sgn in (-1, 1):
        part(m, 'Band', (0.55, 4.9, 4.5), F * at(sgn * 1.9, 3.35, 0), GOLD, material='SmoothPlastic')
        part(m, 'Corner', (0.5, 3.5, 0.5), F * at(sgn * 3.0, 2.5, -2.1), GOLD, material='SmoothPlastic')
        part(m, 'Corner', (0.5, 3.5, 0.5), F * at(sgn * 3.0, 2.5, 2.1), GOLD, material='SmoothPlastic')
    part(m, 'LidRim', (6.4, 0.35, 4.6), F * at(0, 4.2, 0), GOLD, material='SmoothPlastic')
    part(m, 'Lock', (1.3, 1.6, 0.35), F * at(0, 3.9, -2.28), GOLD, material='SmoothPlastic')
    part(m, 'Keyhole', (0.3, 0.6, 0.1), F * at(0, 3.7, -2.48), INK, collide=False)
    glow = part(m, 'Glow', (4.8, 0.3, 3.4), F * at(0, 4.3, 0), (255, 226, 120), material='Neon', collide=False, query=False, shadow=False)
    light(glow, (255, 214, 120), 14, 1.2)
    L.sparkles(glow, color=(255, 220, 90), rate=8, size=0.5)
    sign = part(m, 'LabelAnchor', (1, 1, 1), F * at(0, 6.2, 0), (255, 255, 255), transparency=1, collide=False, query=False, shadow=False)
    billboard(sign, [('FREE ADMIN TICKET', 0.5, GOLD), ('LIKE + FAVORITE THE GAME', 0.3, (255, 255, 255)), ('STAND ON THE CIRCLE', 0.2, (120, 230, 140))],
              3.4, size=(14, 5))
    zx, zz = spots_['zone']
    zy = TOP + lift_at(zx, zz) * 6.0
    zone = cyl_v(m, at(zx, zy, zz), 'RewardZone', 4.2, 0.12, at(0, 0.08, 0), (255, 220, 90), material='Neon', transparency=0.55,
                 collide=False, query=False, shadow=False, tags=['RewardZone'])
    cyl_v(m, at(zx, zy, zz), 'ZoneRing', 4.6, 0.1, at(0, 0.05, 0), (255, 170, 40), material='Neon', transparency=0.1,
          collide=False, query=False, shadow=False)
    cyl_v(m, at(zx, zy, zz), 'ZoneInner', 3.6, 0.14, at(0, 0.1, 0), (255, 240, 170), material='SmoothPlastic', transparency=0.35,
          collide=False, query=False, shadow=False)
    # ---------------------------------------------------------- hidden codes
    codes = folder(root, 'SecretCodes')
    # 1: signpost right at the spawn
    x, z = spots_['code1']
    y = TOP + lift_at(x, z) * 6.0
    vx, vz = spots_['code1_face']
    S = at(x, y, z) * ry(face_yaw(vx, vz))
    s1 = model(codes, 'Code1')
    part(s1, 'Post', (0.6, 4.2, 0.6), S * at(0, 2.1, 0.2), WOOD_D, variant='Studs')
    board = part(s1, 'Board', (5, 2.8, 0.4), S * at(0, 4.4, 0), WOOD, variant='Studs')
    text(board, FRONT_FACE, 'PROMO CODE', CODES[0])
    # 2: small plaque on the back wall of the shop
    x, z = spots_['code2']
    y = TOP + lift_at(x, z) * 6.0
    vx, vz = spots_['code2_face']
    s2 = model(codes, 'Code2')
    part(s2, 'Post', (0.5, 2.2, 0.5), at(x, y + 1.1, z) * ry(face_yaw(vx, vz)) * at(0, 0, 0.3), WOOD_D, variant='Studs', collide=False)
    plaque = part(s2, 'Plaque', (3.2, 1.8, 0.3), at(x, y + 2.9, z) * ry(face_yaw(vx, vz)), (60, 48, 92), variant='Studs', collide=False)
    text(plaque, FRONT_FACE, 'SECRET CODE', CODES[1])
    # 3: flat stone hidden in the forest grass
    x, z, lift = spots_['code3']
    y = TOP + lift * 6.0
    s3 = model(codes, 'Code3')
    stone = part(s3, 'Stone', (3.4, 0.35, 2.4), at(x, y + 0.18, z) * ry(23), (122, 122, 128), variant='2022 Stud', collide=False)
    text(stone, TOP_FACE, 'CODE', CODES[2], color=(255, 236, 140), pixels=70)
    # 4: crate tower, the code sits on the top platform
    x, z = spots_['code4']
    y = TOP + lift_at(x, z) * 6.0
    s4 = model(codes, 'Code4')
    steps = [(0, 0, 3.2), (3.6, 0.8, 6.2), (3.8, 4.4, 9.2), (0.2, 5.0, 12.2), (-2.8, 2.2, 15.2)]
    for i, (dx, dz, top) in enumerate(steps):
        h = 3.0
        part(s4, 'Crate', (3.2, h, 3.2), at(x + dx, y + top - h / 2, z + dz) * ry(i * 17), WOOD if i % 2 else WOOD_D, variant='Studs')
        part(s4, 'CrateBand', (3.3, 0.35, 3.3), at(x + dx, y + top - 0.2, z + dz) * ry(i * 17), GOLD, material='SmoothPlastic', collide=False)
    # pillars under the floating crates so it reads as a tower, not magic
    for (dx, dz, top) in steps[1:]:
        part(s4, 'Pillar', (0.8, top - 3.0, 0.8), at(x + dx, y + (top - 3.0) / 2, z + dz), (90, 92, 104), variant='2022 Stud')
    px, pz, ptop = steps[-1]
    plate = part(s4, 'Plate', (2.6, 0.25, 2.0), at(x + px, y + ptop + 0.13, z + pz) * ry(60), (40, 40, 52), collide=False)
    text(plate, TOP_FACE, 'CODE', CODES[3], color=(150, 220, 255), pixels=80)
    # 5: plate floating on the water outside the fence, far corner
    x, z, ox, oz = spots_['code5']
    s5 = model(codes, 'Code5')
    raft = part(s5, 'Raft', (5, 0.4, 3.4), at(x, WATER + 0.25, z) * ry(face_yaw(-ox, -oz)), (150, 104, 60), variant='Studs', collide=False)
    text(raft, TOP_FACE, 'LAST CODE', CODES[4], color=(255, 120, 120), pixels=70)
    return root
