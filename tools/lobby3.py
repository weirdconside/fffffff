"""Lobby v3: game-asset island, original 0/6 room squares, original shop, fireflies and lanterns."""
import math, random, copy
import numpy as np
from lib import *
import lobby as L
import poses as PZ
from lobby import TOP, WATER, hex_center, tc, R_HEX, part, cyl_v, light, model, folder, place_asset

def orig_lobby(tree):
    ws = tree.getroot().find('Item')
    return [i for i in ws.findall('Item') if name_of(i) == 'LobbyWorld'][0]

def find_decor(ctx):
    """Classify the round's decoration models by shape signature (see gallery)."""
    terr = child(ctx.env, 'Territories')
    out = {}
    for m in terr.iter('Item'):
        if m.get('class') != 'Model':
            continue
        n = sum(1 for it in m.iter('Item') if it.get('class') in PARTS)
        lo, hi = world_bbox(m)
        if not np.all(np.isfinite(lo)):
            continue
        d = hi - lo
        nm = name_of(m)
        key = None
        if nm == 'GoldMine': key = 'mine'
        elif nm == 'Model' and n == 16 and d[1] > 5: key = 'tower'
        elif nm == 'Model' and n == 10: key = 'cart'
        elif nm == 'Model' and n == 5 and d[1] > 1.5: key = 'fence'
        elif nm == 'Model' and n == 20: key = 'sign'
        elif nm == 'Model' and n in (144, 169, 170): key = 'camp'
        elif nm == 'Model' and n == 7 and d[1] > 1.5: key = 'palisade'
        if key:
            out.setdefault(key, []).append(m)
    plot = child(ctx.assets, 'ArmyPlotTemplate')
    out['enemycamp'] = [m for m in plot.iter('Item') if m.get('class') == 'Model' and name_of(m) == 'EnemyCamp']
    return out

def translate_clone(src, offset, rot_deg=0.0, pivot=None, strip=frozenset()):
    """Copy a lobby model 1:1, rotated about `pivot` (Y axis) and moved by `offset`."""
    pivot = np.array(pivot if pivot is not None else (0, 0, 0), float)
    placement = at(*(pivot + np.array(offset, float))) * ry(rot_deg)
    return clone(src, placement, pivot, s=1.0, strip=set(strip), keep_gui=True)

def lantern(parent, pos, glow_src=None):
    """Stud lantern post with the original lobby's warm light and glow particles."""
    m = model(parent, 'Lantern')
    x, y, z = pos
    part(m, 'Post', (0.7, 7, 0.7), at(x, y + 3.5, z), (58, 44, 34), variant='Studs', collide=True)
    part(m, 'Base', (1.6, 0.6, 1.6), at(x, y + 0.3, z), (70, 72, 82), variant='2022 Stud', collide=False)
    part(m, 'Cap', (1.9, 0.4, 1.9), at(x, y + 8.4, z), (58, 44, 34), variant='Studs', collide=False)
    lamp = part(m, 'Lamp', (1.2, 1.3, 1.2), at(x, y + 7.55, z), (255, 214, 133), material='Neon', collide=False)
    light(lamp, (255, 214, 133), 11, 0.9)
    if glow_src is not None:
        g = copy.deepcopy(glow_src)
        for it in g.iter('Item'): it.set('referent', new_ref())
        lamp.append(g)
    return m

def path(parent, a, b, w, layer=0):
    dx, dz = b[0] - a[0], b[1] - a[1]
    length = math.hypot(dx, dz)
    yaw = -math.degrees(math.atan2(dz, dx))
    # each path sits on its own height layer so crossing paths never z-fight
    part(parent, 'Path', (length, 0.3, w), at((a[0] + b[0]) / 2, TOP + 0.15 + layer * 0.06, (a[1] + b[1]) / 2) * ry(yaw), (150, 112, 74),
         variant='2022 Weld', collide=False, query=False)
    return length

def yaw_to_face(src_dir, target_dir):
    a0 = math.atan2(-src_dir[0], src_dir[1])     # ry(t) turns (x,z) = (-sin t, cos t)... solved numerically below
    best, bt = 1e9, 0
    for t in range(0, 360):
        R = ry(t).R
        v = R @ np.array([src_dir[0], 0, src_dir[1]])
        err = np.hypot(v[0] - target_dir[0], v[2] - target_dir[1])
        if err < best: best, bt = err, t
    return bt

ROOMS = [(58.0, -44.0), (64.0, 0.0), (58.0, 44.0)]
SHOP_POS = (26.0, -46.0)
SPAWN = (-6.0, 0.0)

# ------------------------------------------------------------------ posed NPC scenes
# kind, position (x, z), look-at (x, z), pose, scale
SCENES = [
    # raid: two barbarians, an archer and a wizard take on a giant south of the spawn
    ('Giant', (-4, 44), (-4, 30), 'giant_smash', 3.0),
    ('Barbarian', (-10.5, 34.5), (-4, 44), 'windup', 3.0),
    ('Barbarian', (2.5, 35), (-4, 44), 'overhead', 3.0),
    ('Archer', (10, 24), (-4, 44), 'aim', 3.0),
    ('Wizard', (-18, 27), (-4, 44), 'cast', 3.0),
    # sparring next to the barracks
    ('Barbarian', (-23, -41), (-15, -41), 'windup', 3.0),
    ('Barbarian', (-15, -41), (-23, -41), 'block', 3.0),
    # archery practice
    ('Archer', (-24, -18), (-40, -4), 'aim', 3.0),
    # workers
    ('Lumberjack', (-21.5, 68), (-18, 71), 'chop', 3.0),
    ('Miner', (-89.5, -41.5), (-86, -45), 'mine', 3.0),
    ('Builder', (-20.5, -92), (-30, -94), 'hammer', 3.0),
    # a barbarian celebrating by the town hall
    ('Barbarian', (-50, -13), (-6, 0), 'cheer', 3.0),
]

def archery_target(parent, pos, facing, y0):
    """Straw target on an easel, facing (x, z) `facing`, with one arrow in it."""
    m = model(parent, 'ArcheryTarget')
    x, z = pos
    d = np.array([facing[0] - x, facing[1] - z], float); d /= np.linalg.norm(d)
    yaw = math.degrees(math.atan2(-d[1], d[0]))          # ry(yaw) turns +X onto d
    side = np.array([-d[1], d[0]])
    for k in (-1, 1):
        lx, lz = x + side[0] * 1.7 * k - d[0] * 0.4, z + side[1] * 1.7 * k - d[1] * 0.4
        part(m, 'Leg', (0.5, 5.2, 0.5), at(lx, y0 + 2.6, lz), (112, 78, 48), variant='Studs', collide=False)
    part(m, 'Brace', (0.4, 0.4, 3.8), at(x - d[0] * 0.4, y0 + 2.2, z - d[1] * 0.4) * ry(yaw), (112, 78, 48), variant='Studs', collide=False)
    rings = [(5.2, (236, 226, 196)), (4.0, (214, 52, 48)), (2.8, (245, 242, 232)), (1.5, (255, 204, 58))]
    for i, (dia, col) in enumerate(rings):
        off = i * 0.06
        part(m, 'Ring', (0.4, dia, dia), at(x + d[0] * off, y0 + 4.4, z + d[1] * off) * ry(yaw), col, shape='cyl', collide=False)
    # an arrow stuck just off centre, pointing back at the shooter
    ax, az = x + d[0] * 1.0 + side[0] * 0.5, z + d[1] * 1.0 + side[1] * 0.5
    part(m, 'Arrow', (2.2, 0.16, 0.16), at(ax, y0 + 4.9, az) * ry(yaw), (120, 86, 52), collide=False)
    part(m, 'Fletching', (0.5, 0.45, 0.06), at(ax + d[0] * 1.1, y0 + 4.9, az + d[1] * 1.1) * ry(yaw), (230, 60, 60), collide=False)
    part(m, 'Collision', (1.4, 5.5, 5.4), at(x, y0 + 2.75, z) * ry(yaw), (255, 255, 255), transparency=1, collide=True, query=False, shadow=False)
    return m

def place_scenes(ctx, scen, tiles, lift_at, taken):
    folder_ = folder(scen, 'Garrison')
    for kind, (x, z), look, pose_name, s in SCENES:
        src = child(ctx.entities, kind)
        y = TOP + lift_at(x, z) * 6.0
        m = place_asset(ctx, folder_, src, (x, y, z), yaw=PZ.face_yaw((x, z), look), s=s, name=kind, collide=False, box=True,
                        tags=['LobbyNPC'], box_shrink=0.7)
        PZ.pose(m, src, pose_name, s)
        taken.append((x, z, 6 if kind == 'Giant' else 3.5))
        if kind == 'Wizard':
            hand = PZ.hand_point(m, 'RArm')
            orb = part(m, 'SpellOrb', (1.3, 1.3, 1.3), at(*hand), (176, 96, 255), material='Neon', shape='ball', collide=False,
                       query=False, shadow=False, tags=['LobbySpell'])
            light(orb, (176, 96, 255), 12, 1.2)
            L.sparkles(orb, color=(196, 128, 255), rate=10, size=0.5)
    # props the workers are busy with
    tree_src = child(ctx.resources, 'Pine Tree')
    for kind, src, (x, z), s, yaw in (('Pine Tree', tree_src, (-18, 71), 4.6, 30),
                                      ('Crystal', child(ctx.resources, 'Crystal'), (-86, -45), 3.0, 70)):
        y = TOP + lift_at(x, z) * 6.0
        place_asset(ctx, folder_, src, (x, y, z), yaw=yaw, s=s, name=kind, collide=False, box=True, box_shrink=0.3,
                    tags=['LobbyTree'] if kind == 'Pine Tree' else None)
        taken.append((x, z, 3.5))
    archery_target(folder_, (-40, -4), (-24, -18), TOP + lift_at(-40, -4) * 6.0)
    taken.append((-40, -4, 4))
    # keep the stages clear of random props and trees
    for x, z, r in ((-4, 37, 17), (-19, -41, 9), (-32, -11, 11), (-19.5, 69.5, 6), (-88, -43, 6), (-21, -92, 5), (-50, -13, 5)):
        taken.append((x, z, r))

def build(tree):
    ctx = L.Ctx(tree)
    ol = orig_lobby(tree)
    rnd = random.Random(21)
    lobby = model(None, 'LobbyWorld')
    scen = folder(lobby, 'Scenery')
    tiles = L.island_tiles()
    # a couple more land tiles on the east where the harbour used to be
    for qr in [(3, -2), (3, -1), (2, 1), (3, 0)]:
        tiles[qr] = 0
    L.build_tiles(ctx, scen, tiles)
    # only the top water sheet: the bottom sheet sat 0.001 studs below and flickered
    oc = clone(ctx.ocean, at(0, WATER, 0), read_cf(getp(child(ctx.ocean, 'OceanTop'), 'CFrame')).t, s=1.0,
               collide=False, name='Ocean', drop=lambda it: name_of(it) == 'OceanBottom')
    scen.append(oc)
    part(scen, 'SeaFloor', (2000, 2, 2000), at(0, WATER - 7, 0), (40, 120, 200), transparency=1, collide=True,
         query=False, shadow=False)
    # fences all around (no harbour any more)
    fence = model(scen, 'Boundary')
    for (qr, d, (mx, mz), ang, lift, neighbour) in L.perimeter_edges(tiles):
        if neighbour: continue
        yaw = -(ang + 90); y = TOP + lift * 6.0
        inward = np.array(hex_center(*qr)) - np.array([mx, mz]); inward /= np.linalg.norm(inward)
        E = at(mx + inward[0] * 1.2, y, mz + inward[1] * 1.2) * ry(yaw)
        Lh = R_HEX
        part(fence, 'FenceRail', (Lh, 0.5, 0.4), E * at(0, 2.4, 0), L.WOOD, collide=False)
        part(fence, 'FenceRail', (Lh, 0.5, 0.4), E * at(0, 1.2, 0), L.WOOD, collide=False)
        for k in range(4):
            part(fence, 'FencePost', (0.7, 3.2, 0.7), E * at(-Lh / 2 + k * Lh / 3, 1.6, 0), L.WOOD_D, collide=False)
        part(fence, 'Wall', (Lh + 1, 14, 1), E * at(0, 7, 0), (255, 255, 255), transparency=1, collide=True, query=False, shadow=False)

    # ------------------------------------------------------------ original room squares (0/6)
    ont = child(ol, 'NativeTeleporters')
    rooms = folder(lobby, 'NativeTeleporters')
    for i, (x, z) in enumerate(ROOMS):
        src = child(ont, 'Teleporter%d' % (i + 1))
        beam = read_cf(getp(child(src, 'BeamPart'), 'CFrame')).t
        dst = np.array([x, TOP + 0.24, z])
        m = translate_clone(src, dst - beam, 0, beam)
        for it in m.iter('Item'):
            if it.get('class') == 'PointLight':      # softer: no glowing players on the square
                set_prop(it, 'Brightness', 'float', 0.9)
        rooms.append(m)
    # ------------------------------------------------------------ original shop + shopkeeper
    osc = child(ol, 'Scenery')
    shop_group = [child(osc, 'Shop'), child(osc, 'Model'), child(osc, 'Shopper')]
    mesh = [it for it in shop_group[0].iter('Item') if it.get('class') == 'MeshPart'][0]
    mcf = read_cf(getp(mesh, 'CFrame'))
    front = -mcf.R[:, 2]
    target = np.array([SPAWN[0] - SHOP_POS[0], SPAWN[1] - SHOP_POS[1]]); target /= np.linalg.norm(target)
    yaw = yaw_to_face((front[0], front[2]), target)
    pivot = np.array([mcf.t[0], 1.0, mcf.t[2]])
    shop = model(scen, 'Shop')
    for g in shop_group:
        shop.append(translate_clone(g, np.array([SHOP_POS[0], TOP, SHOP_POS[1]]) - pivot, yaw, pivot))

    # ------------------------------------------------------------ fireflies over the island (from the original lobby)
    fx = folder(scen, 'Atmosphere')
    for nm in ('NormalDust', 'Part'):
        src = child(child(osc, 'FullDeko'), nm)
        if src is None: continue
        d = clone(src, at(0, TOP + 16, 0), read_cf(getp(src, 'CFrame')).t, s=1.0, strip=set(), collide=False,
                  name='Fireflies')
        set_prop(d, 'size', 'Vector3', (240, 30, 270))
        set_prop(d, 'CanQuery', 'bool', False)
        set_prop(d, 'Transparency', 'float', 1)
        set_prop(d, 'CastShadow', 'bool', False)
        for em in d.iter('Item'):
            if em.get('class') == 'ParticleEmitter':
                set_prop(em, 'Rate', 'float', 16)
        fx.append(d)
    # warm glow emitter used by the original lanterns
    glow = None
    la = child(child(osc, 'FullDeko'), 'La')
    if la is not None:
        for it in la.iter('Item'):
            if it.get('class') == 'ParticleEmitter':
                glow = it; break

    # ------------------------------------------------------------ paths + lanterns
    deco = folder(scen, 'Details')
    lamps = []
    # only the shop gets a path; the 0/6 squares stand on plain grass
    ends = [(SHOP_POS[0] - 4, SHOP_POS[1] + 8)]
    for layer, (ex, ez) in enumerate(ends):
        a = (SPAWN[0] + 6, SPAWN[1]); b = (ex, ez)
        length = path(deco, a, b, 7, layer)
        n = max(1, int(length // 22))
        dx, dz = (b[0] - a[0]) / length, (b[1] - a[1]) / length
        for k in range(1, n + 1):
            t = k * length / (n + 1)
            side = 1 if k % 2 else -1
            p = (a[0] + dx * t - dz * 5 * side, a[1] + dz * t + dx * 5 * side)
            if math.hypot(p[0] - SPAWN[0], p[1] - SPAWN[1]) < 20: continue
            if any(math.hypot(p[0] - q[0], p[1] - q[1]) < 10 for q in lamps): continue
            lamps.append(p)
            lantern(deco, (p[0], TOP, p[1]), glow)
    for (x, z) in ROOMS:
        for sx, sz in ((-11, -9), (-11, 9)):
            lantern(deco, (x + sx, TOP, z + sz), glow)
    taken = [(x, z, 13) for (x, z) in ROOMS] + [(SHOP_POS[0], SHOP_POS[1], 15), (SPAWN[0], SPAWN[1], 14)]
    corridor = []
    for (ex, ez) in ends + [(x - 10, z) for (x, z) in ROOMS]:   # walkways stay free of props
        a = (SPAWN[0] + 6, SPAWN[1]); length = math.hypot(ex - a[0], ez - a[1])
        for k in range(int(length // 5) + 1):
            t = k * 5 / length
            corridor.append((a[0] + (ex - a[0]) * t, a[1] + (ez - a[1]) * t, 6))

    # ------------------------------------------------------------ village buildings + garrison (game assets)
    town = folder(scen, 'Village')
    for kind, lv, (q, r), (dx, dz), yaw_b, s in L.BUILDINGS:
        if (q, r) not in tiles: continue
        src = ctx.level(kind, lv)
        if src is None: continue
        pos = tc(q, r, dx, dz, tiles.get((q, r), 0))
        if any(math.hypot(pos[0] - a, pos[2] - b) < rr + 6 for a, b, rr in taken): continue
        place_asset(ctx, town, src, pos, yaw=yaw_b, s=s, name=kind, collide=False, box=True, box_shrink=0.8)
        lo, hi = world_bbox(src)
        taken.append((pos[0], pos[2], max(hi[0] - lo[0], hi[2] - lo[2]) * s * 0.55))
    land_tiles = {qr: lift for qr, lift in tiles.items()}
    def tile_of(x, z):
        best, bd = None, 1e9
        for qr in land_tiles:
            cx, cz = hex_center(*qr); d = math.hypot(x - cx, z - cz)
            if d < bd: best, bd = qr, d
        return best, bd
    def on_land(x, z):
        qr, d = tile_of(x, z)
        return d < R_HEX * 0.72
    def lift_at(x, z):
        return land_tiles[tile_of(x, z)[0]]

    def free_spot(cx, cz, rmin, rmax, clearance, tries=300):
        for _ in range(tries):
            ang = rnd.uniform(0, math.tau); rad = rnd.uniform(rmin, rmax)
            x, z = cx + math.cos(ang) * rad, cz + math.sin(ang) * rad
            if math.hypot(x - SPAWN[0], z - SPAWN[1]) < 16: continue
            if any(math.hypot(x - a, z - b) < clearance + rr for a, b, rr in taken): continue
            if not on_land(x, z): continue
            return x, z
        return None
    place_scenes(ctx, scen, tiles, lift_at, taken)
    taken.extend(corridor)
    # ------------------------------------------------------------ game decorations: towers, carts, camps, mines, fences
    decor = find_decor(ctx)
    props = folder(scen, 'Props')
    plan = [('tower', 6, 3.0, 5), ('cart', 7, 3.0, 3), ('camp', 3, 2.4, 14), ('mine', 3, 3.2, 6), ('sign', 5, 3.0, 3),
            ('fence', 8, 3.0, 3), ('enemycamp', 2, 2.6, 12), ('palisade', 4, 3.0, 3)]
    for key, count, s, clear in plan:
        pool = decor.get(key) or []
        if not pool: continue
        placed = 0
        for qr in sorted(land_tiles, key=lambda _: rnd.random()):
            if placed >= count: break
            cx, cz = hex_center(*qr)
            spot = free_spot(cx, cz, 4, 15, clear)
            if not spot: continue
            x, z = spot
            src = pool[placed % len(pool)]
            yaw_d = math.degrees(math.atan2(SPAWN[1] - z, x - SPAWN[0])) + rnd.uniform(-20, 20)
            place_asset(ctx, props, src, (x, TOP + lift_at(x, z) * 6.0, z), yaw=yaw_d, s=s, name=key.capitalize(),
                        collide=False, box=key in ('tower', 'mine', 'camp', 'enemycamp', 'cart'), box_shrink=0.55,
                        drop=lambda it: it.get('class') == 'Part' and name_of(it) in ('Root',) )
            taken.append((x, z, clear)); placed += 1

    # ------------------------------------------------------------ lots of trees + resource rocks
    nature = folder(scen, 'Nature')
    tree_src = child(ctx.resources, 'Pine Tree')
    for qr in land_tiles:
        cx, cz = hex_center(*qr)
        d_spawn = math.hypot(cx - SPAWN[0], cz - SPAWN[1])
        n = 0 if d_spawn < 30 else (1 if d_spawn < 60 else (3 if land_tiles[qr] == 0 else 6))
        for _ in range(n):
            spot = free_spot(cx, cz, 3, 17, 5)
            if not spot: continue
            x, z = spot
            s = rnd.uniform(5.0, 8.0)
            place_asset(ctx, nature, tree_src, (x, TOP + lift_at(x, z) * 6.0, z), yaw=rnd.uniform(0, 360), s=s,
                        name='Pine Tree', collide=False, box=True, box_shrink=0.3, tags=['LobbyTree'])
            taken.append((x, z, 4.5))
    for kind, n in (('Stone', 16), ('Iron Ore', 8), ('Crystal', 10)):
        src = child(ctx.resources, kind)
        for _ in range(n):
            qr = rnd.choice(list(land_tiles))
            cx, cz = hex_center(*qr)
            spot = free_spot(cx, cz, 3, 17, 4)
            if not spot: continue
            x, z = spot
            place_asset(ctx, nature, src, (x, TOP + lift_at(x, z) * 6.0, z), yaw=rnd.uniform(0, 360), s=rnd.uniform(2.6, 4.0),
                        name=kind, collide=False, box=True, box_shrink=0.6)
            taken.append((x, z, 2.5))
    # coast
    sea = folder(scen, 'Coast')
    for k, (x, z, s, yaw_r) in enumerate([(-150, -60, 3.2, 20), (-140, 70, 2.6, 80), (-60, 160, 3.0, 140), (60, 165, 2.4, 200),
                                          (-40, -170, 2.8, 30), (170, -90, 2.2, 70), (-180, 5, 2.0, 110), (175, 110, 2.6, 10)]):
        place_asset(ctx, sea, ctx.rocks[k % len(ctx.rocks)], (x, WATER - 3, z), yaw=yaw_r, s=s, name='SeaRock', collide=False, box=False)
    for k, (x, z, yaw_s) in enumerate([(-128, -40, 90), (-125, 45, 80), (-92, 102, 45), (-50, 128, 10), (18, 128, -20),
                                       (-72, -100, 130), (-20, -140, 170), (40, -128, 200), (128, 60, -60), (125, -60, 250)]):
        place_asset(ctx, sea, ctx.sands[k % len(ctx.sands)], (x, WATER - 0.9 + k * 0.05, z), yaw=yaw_s, s=1.25, name='Beach', collide=False, box=False)
    removed = remove_overlaps(lobby)
    print('overlap pass removed', removed, 'models')
    spawn_cf = at(SPAWN[0], TOP + 0.1, SPAWN[1]) * ry(-90)
    return lobby, ctx, tiles, spawn_cf

PRIORITY = ['NativeTeleporters', 'Shop', 'Village', 'Garrison', 'Props', 'Details', 'Nature']
def remove_overlaps(lobby):
    """Drop lower-priority models whose footprint intersects a kept model (no props growing into each other)."""
    groups = {}
    for f in lobby.iter('Item'):
        if f.get('class') in ('Folder', 'Model') and name_of(f) in PRIORITY and f.getparent() is not None:
            groups[name_of(f)] = f
    kept = []   # (lo, hi)
    removed = 0
    for g in PRIORITY:
        f = groups.get(g)
        if f is None: continue
        members = [m for m in f.findall('Item') if m.get('class') == 'Model'] if g not in ('Shop',) else [f]
        for m in members:
            lo, hi = world_bbox(m)
            if not np.all(np.isfinite(lo)): continue
            shrink = (hi - lo) * 0.12
            lo2, hi2 = lo + shrink, hi - shrink
            clash = False
            for (a, b) in kept:
                ox = min(hi2[0], b[0]) - max(lo2[0], a[0]); oz = min(hi2[2], b[2]) - max(lo2[2], a[2])
                oy = min(hi2[1], b[1]) - max(lo2[1], a[1])
                if ox > 0 and oz > 0 and oy > 0:
                    clash = True; break
            if clash and g not in ('NativeTeleporters', 'Shop', 'Garrison'):
                m.getparent().remove(m); removed += 1
            else:
                kept.append((lo2, hi2))
    return removed
