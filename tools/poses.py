"""Static poses for the lobby's game-entity NPCs (Root -> Torso -> limbs Motor6D rigs).

Lobby clones are anchored parts without joints, so a pose is baked straight
into the part CFrames (joint pivots come from the source rig).
Angles are degrees in the character frame: +X raises a limb forward, +Z swings
it to the character's right, +Y twists it to the left.
"""
import math
import numpy as np
from lib import CF, rx, ry, rz, PARTS, getp, name_of, read_cf, write_cf, set_prop

RIG = ('Root', 'Torso', 'Head', 'RArm', 'LArm', 'RLeg', 'LLeg')

POSES = {
    # club cocked behind the head, other hand reaching for the target
    'windup': {'Torso': (6, 14, 0), 'RArm': (172, 0, 16), 'LArm': (72, -10, -22), 'RLeg': (-20, 0, 6), 'LLeg': (28, 0, -6),
               'Head': (-4, -10, 0)},
    # leaning into the swing, club coming over the top
    'overhead': {'Torso': (-12, -10, 0), 'RArm': (128, 0, 8), 'LArm': (-35, 0, -18), 'RLeg': (30, 0, 4), 'LLeg': (-24, 0, -4),
                 'Head': (8, 0, 0)},
    # arms crossed in front to take a hit
    'block': {'Torso': (8, 0, 0), 'RArm': (98, -28, 0), 'LArm': (92, 30, 0), 'RLeg': (-14, 0, 8), 'LLeg': (16, 0, -8),
              'Head': (-6, 0, 0)},
    # bow arm straight out, drawing hand at the chin
    'aim': {'Torso': (0, 12, 0), 'RArm': (90, -10, 0), 'LArm': (86, -48, 0), 'RLeg': (-12, 0, 8), 'LLeg': (14, 0, -8),
            'Head': (0, -8, 0)},
    # both fists up for a ground smash
    'giant_smash': {'Torso': (12, 0, 0), 'RArm': (168, 0, -12), 'LArm': (168, 0, 12), 'RLeg': (-6, 0, 10), 'LLeg': (6, 0, -10),
                    'Head': (14, 0, 0)},
    # one hand up with a spell, the other pushing forward
    'cast': {'Torso': (-6, -8, 0), 'RArm': (150, 0, 16), 'LArm': (84, 10, -12), 'RLeg': (18, 0, 4), 'LLeg': (-16, 0, -4),
             'Head': (6, 0, 0)},
    'chop': {'Torso': (8, 18, 0), 'RArm': (150, 0, -8), 'LArm': (140, 0, 18), 'RLeg': (-14, 0, 8), 'LLeg': (16, 0, -8),
             'Head': (-10, 0, 0)},
    'mine': {'Torso': (-14, 0, 0), 'RArm': (160, 0, 6), 'LArm': (110, 0, -12), 'RLeg': (22, 0, 5), 'LLeg': (-14, 0, -5),
             'Head': (-12, 0, 0)},
    'hammer': {'Torso': (-10, -6, 0), 'RArm': (140, 0, 10), 'LArm': (62, 0, -14), 'RLeg': (16, 0, 5), 'LLeg': (-12, 0, -5),
               'Head': (-10, 0, 0)},
    'cheer': {'Torso': (6, 0, 0), 'RArm': (168, 0, 26), 'LArm': (168, 0, -26), 'RLeg': (0, 0, 8), 'LLeg': (0, 0, -8),
              'Head': (16, 0, 0)},
}

def euler(x, y, z):
    """Rotation applied X first, then Z, then Y (all in the character frame)."""
    return (ry(y) * rz(z) * rx(x)).R

def _refmap(model):
    return {it.get('referent'): it for it in model.iter('Item')}

def _cf(p):
    return read_cf(getp(p, 'CFrame'))

def _set_cf(p, cf):
    write_cf(getp(p, 'CFrame'), cf)

def _corners(p, cf=None):
    cf = cf or _cf(p)
    s = np.array([float(getp(p, 'size').find(k).text) for k in 'XYZ']) / 2
    out = []
    for sx in (-1, 1):
        for sy in (-1, 1):
            for sz in (-1, 1):
                out.append(cf * (s * np.array([sx, sy, sz])))
    return np.array(out)

def pose(model, src, pose_name, s):
    """Pose one placed entity model cloned from `src` with scale `s`.
    Clones carry no joints, so the rig (Motor6D) and the weld groups are read
    from the source model and matched to the clone part by part."""
    spec = POSES[pose_name]
    src_parts = [it for it in src.iter('Item') if it.get('class') in PARTS]
    dst_parts = [it for it in model.iter('Item') if it.get('class') in PARTS and name_of(it) != 'Collision']
    if len(src_parts) != len(dst_parts) or any(name_of(a) != name_of(b) for a, b in zip(src_parts, dst_parts)):
        raise ValueError('clone does not match its source: %s' % name_of(src))
    to_dst = {a.get('referent'): b for a, b in zip(src_parts, dst_parts)}
    rig = {}
    for c in model.findall('Item'):
        if c.get('class') in PARTS and name_of(c) in RIG:
            rig[name_of(c)] = c
    if 'Root' not in rig or 'Torso' not in rig:
        return False
    motors = {}      # limb name -> (parent name, C1 in the unscaled source)
    welds = []
    for it in src.iter('Item'):
        cls = it.get('class')
        if cls == 'Motor6D':
            a, b = getp(it, 'Part0'), getp(it, 'Part1')
            p0, p1 = to_dst.get(a.text if a is not None else None), to_dst.get(b.text if b is not None else None)
            if p0 is not None and p1 is not None and name_of(p1) in rig:
                motors[name_of(p1)] = (name_of(p0), read_cf(getp(it, 'C1')))
        elif cls == 'WeldConstraint':
            a, b = getp(it, 'Part0Internal'), getp(it, 'Part1Internal')
            p0, p1 = to_dst.get(a.text if a is not None else None), to_dst.get(b.text if b is not None else None)
            if p0 is not None and p1 is not None:
                welds.append((p0, p1))
    owner = {id(p): name_of(p) for p in rig.values()}
    adj = {}
    for a, b in welds:
        adj.setdefault(id(a), []).append(b); adj.setdefault(id(b), []).append(a)
    for rn, rp in rig.items():
        stack = [rp]
        while stack:
            cur = stack.pop()
            for nb in adj.get(id(cur), []):
                if id(nb) not in owner:
                    owner[id(nb)] = rn; stack.append(nb)
    # sub-models (Axe, Club) move as one piece with whoever holds any of their parts
    for sub in model.findall('Item'):
        if sub.get('class') != 'Model': continue
        members = [it for it in sub.iter('Item') if it.get('class') in PARTS]
        held = [owner[id(m)] for m in members if id(m) in owner and name_of(m) not in RIG]
        if held:
            for m in members: owner[id(m)] = held[0]
    # loose accessories: nearest rig part
    for p in dst_parts:
        if id(p) in owner: continue
        c = _cf(p).t
        owner[id(p)] = min((n for n in rig if n != 'Root'), key=lambda n: np.linalg.norm(_cf(rig[n]).t - c))
    old = {id(p): _cf(p) for p in dst_parts}
    rc = old[id(rig['Root'])].R            # character frame
    new = {'Root': old[id(rig['Root'])]}
    feet_before = min(_corners(rig[n])[:, 1].min() for n in ('RLeg', 'LLeg') if n in rig)
    for name in ('Torso', 'Head', 'RArm', 'LArm', 'RLeg', 'LLeg'):
        if name not in rig or name not in motors: continue
        parent, C1 = motors[name]
        P0o, P1o = old[id(rig[parent])], old[id(rig[name])]
        P0n = new.get(parent, P0o)
        if name == 'Torso':
            sy = float(getp(rig['Torso'], 'size').find('Y').text)
            piv1 = np.array([0, -sy / 2, 0])          # bend at the hips
        else:
            piv1 = C1.t * s                            # joint point in the limb's space
        pivot_old = P1o * piv1
        pivot_new = P0n * (P0o.inv() * pivot_old)
        Q = rc @ euler(*spec.get(name, (0, 0, 0))) @ rc.T
        if name in ('RLeg', 'LLeg'):
            rot = Q                                    # legs stay planted when the torso bends
        else:
            rot = (P0n.R @ P0o.R.T) @ Q                # arms/head follow the torso
        new[name] = CF(pivot_new + rot @ (P1o.t - pivot_old), rot @ P1o.R)
    delta = {name: cfn * old[id(rig[name])].inv() for name, cfn in new.items()}
    for p in dst_parts:
        d = delta.get(owner[id(p)])
        if d is not None:
            _set_cf(p, d * old[id(p)])
    # keep the lowest foot on the ground
    feet_after = min(_corners(rig[n])[:, 1].min() for n in ('RLeg', 'LLeg') if n in rig)
    drop = feet_after - feet_before
    if abs(drop) > 1e-4:
        for p in dst_parts:
            cf = _cf(p); cf.t = cf.t - np.array([0, drop, 0]); _set_cf(p, cf)
    return True

def hand_point(model, arm='RArm'):
    """World position just past the end of an arm (for spell orbs etc.)."""
    for c in model.findall('Item'):
        if c.get('class') in PARTS and name_of(c) == arm:
            cf = _cf(c)
            sy = float(getp(c, 'size').find('Y').text)
            return cf * np.array([0, -sy * 0.62, 0])
    return None

def face_yaw(frm, to):
    """ry() yaw that turns an entity (looking down -Z) from `frm` towards `to` (x, z)."""
    dx, dz = to[0] - frm[0], to[1] - frm[1]
    return math.degrees(math.atan2(-dx, -dz))
