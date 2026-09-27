"""XML toolkit for generating/cloning Roblox instances inside an rbxlx tree."""
import copy, base64, math
import numpy as np
from lxml import etree

# ---------------------------------------------------------------- CFrame math
class CF:
    __slots__ = ('R', 't')
    def __init__(self, t=(0, 0, 0), R=None):
        self.t = np.array(t, float)
        self.R = np.eye(3) if R is None else np.array(R, float)
    def __mul__(self, o):
        if isinstance(o, CF):
            return CF(self.R @ o.t + self.t, self.R @ o.R)
        return self.R @ np.array(o, float) + self.t
    def inv(self):
        return CF(-self.R.T @ self.t, self.R.T)
    def __add__(self, v):
        return CF(self.t + np.array(v, float), self.R)
    def tolist(self):
        return self.t.tolist()
    @property
    def pos(self):
        return self.t
def rx(deg):
    a = math.radians(deg); c, s = math.cos(a), math.sin(a)
    return CF(R=[[1, 0, 0], [0, c, -s], [0, s, c]])
def ry(deg):
    a = math.radians(deg); c, s = math.cos(a), math.sin(a)
    return CF(R=[[c, 0, s], [0, 1, 0], [-s, 0, c]])
def rz(deg):
    a = math.radians(deg); c, s = math.cos(a), math.sin(a)
    return CF(R=[[c, -s, 0], [s, c, 0], [0, 0, 1]])
def at(x, y, z):
    return CF((x, y, z))
def look_at(eye, target, up=(0, 1, 0)):
    eye = np.array(eye, float); target = np.array(target, float)
    f = target - eye; f /= np.linalg.norm(f)
    r = np.cross(f, up); r /= np.linalg.norm(r)
    u = np.cross(r, f)
    # Roblox: columns are Right, Up, Back(-look)
    R = np.column_stack([r, u, -f])
    return CF(eye, R)

# ---------------------------------------------------------------- referents
_ref = [0]
def new_ref():
    _ref[0] += 1
    return 'RBXGEN%06d' % _ref[0]

# ---------------------------------------------------------------- property encoders
def _num(v):
    if isinstance(v, bool):
        return 'true' if v else 'false'
    if isinstance(v, (int, np.integer)):
        return str(int(v))
    r = float(v)
    if abs(r) < 1e-12: r = 0.0
    return repr(round(r, 6))
def P(parent, tag, name, value=None):
    e = etree.SubElement(parent, tag, name=name)
    if value is not None:
        e.text = value
    return e
def enc(props, name, typ, v):
    if typ == 'string':
        P(props, 'string', name, v)
    elif typ == 'bool':
        P(props, 'bool', name, 'true' if v else 'false')
    elif typ in ('float', 'double', 'int', 'int64', 'token'):
        P(props, typ, name, _num(v))
    elif typ == 'Vector3':
        e = P(props, 'Vector3', name)
        for k, x in zip('XYZ', v): P(e, k, None) if False else None
        for k, x in zip('XYZ', v):
            s = etree.SubElement(e, k); s.text = _num(x)
    elif typ == 'Vector2':
        e = P(props, 'Vector2', name)
        for k, x in zip('XY', v):
            s = etree.SubElement(e, k); s.text = _num(x)
    elif typ == 'CFrame':
        e = P(props, 'CoordinateFrame', name)
        cf = v
        for k, x in zip('XYZ', cf.t):
            s = etree.SubElement(e, k); s.text = _num(x)
        for i in range(3):
            for j in range(3):
                s = etree.SubElement(e, 'R%d%d' % (i, j)); s.text = _num(cf.R[i, j])
    elif typ == 'Color3uint8':
        r, g, b = [int(max(0, min(255, round(c)))) for c in v]
        P(props, 'Color3uint8', name, str((255 << 24) | (r << 16) | (g << 8) | b))
    elif typ == 'Color3':
        e = P(props, 'Color3', name)
        for k, x in zip('RGB', v):
            s = etree.SubElement(e, k); s.text = _num(x / 255.0)
    elif typ == 'UDim2':
        e = P(props, 'UDim2', name)
        for k, x in zip(('XS', 'XO', 'YS', 'YO'), v):
            s = etree.SubElement(e, k); s.text = _num(x) if k.endswith('S') else str(int(x))
    elif typ == 'UDim':
        e = P(props, 'UDim', name)
        s = etree.SubElement(e, 'S'); s.text = _num(v[0])
        s = etree.SubElement(e, 'O'); s.text = str(int(v[1]))
    elif typ == 'ContentId':
        e = P(props, 'ContentId', name)
        s = etree.SubElement(e, 'url'); s.text = v
    elif typ == 'Content':
        e = P(props, 'Content', name)
        s = etree.SubElement(e, 'url'); s.text = v
    elif typ == 'BinaryString':
        P(props, 'BinaryString', name, v)
    elif typ == 'ProtectedString':
        e = P(props, 'ProtectedString', name)
        e.text = etree.CDATA(v)
    elif typ == 'Ref':
        P(props, 'Ref', name, v or 'null')
    elif typ in ('ColorSequence', 'NumberSequence', 'NumberRange'):
        P(props, typ, name, v)
    elif typ == 'Font':
        e = P(props, 'Font', name)
        fam = etree.SubElement(e, 'Family'); u = etree.SubElement(fam, 'url'); u.text = v[0]
        w = etree.SubElement(e, 'Weight'); w.text = str(v[1])
        st = etree.SubElement(e, 'Style'); st.text = v[2]
    elif typ == 'Rect2D':
        e = P(props, 'Rect2D', name)
        mn = etree.SubElement(e, 'min'); a = etree.SubElement(mn, 'X'); a.text = _num(v[0]); b = etree.SubElement(mn, 'Y'); b.text = _num(v[1])
        mx = etree.SubElement(e, 'max'); a = etree.SubElement(mx, 'X'); a.text = _num(v[2]); b = etree.SubElement(mx, 'Y'); b.text = _num(v[3])
    else:
        raise ValueError(typ)

def item(cls, name, props=(), parent=None, ref=None):
    it = etree.Element('Item', {'class': cls, 'referent': ref or new_ref()})
    pr = etree.SubElement(it, 'Properties')
    enc(pr, 'Name', 'string', name)
    for p in props:
        enc(pr, p[0], p[1], p[2])
    if parent is not None:
        parent.append(it)
    return it

def tags_b64(*tags):
    return base64.b64encode('\0'.join(tags).encode()).decode()
def b64(s):
    return base64.b64encode(s.encode()).decode()

# ---------------------------------------------------------------- materials
MAT = dict(Plastic=256, SmoothPlastic=272, Neon=288, Wood=512, WoodPlanks=528, Marble=784, Slate=800,
           Concrete=816, Granite=832, Brick=848, Pebble=864, Cobblestone=880, Rock=896, Sandstone=912,
           CorrodedMetal=1040, DiamondPlate=1056, Foil=1072, Metal=1088, Grass=1280, Sand=1296,
           Fabric=1312, Ice=1536, Glacier=1552, Glass=1568, ForceField=1584)
SHAPE = dict(ball=0, block=1, cyl=2)
# Stud-style material variants that already exist in the place's MaterialService.
VARIANT_BASE = {'Studs': 'Plastic', '2022 Stud': 'Glacier', '2022 Weld': 'Glacier', '2022 Inlet': 'Glacier',
                '2022 Small Stud': 'Glacier', '2022 Big Stud': 'Glacier', '2022 Universal': 'Glacier',
                '2022 Diamond Stud': 'Glacier', '2022 Glue': 'Glacier', 'Glue': 'Plastic'}

def part(parent, name, size, cf, color, material='Plastic', variant=None, shape='block', cls='Part',
         transparency=0, collide=True, query=None, touch=False, shadow=True, reflect=0, tags=None, extra=()):
    if variant:
        material = VARIANT_BASE[variant]
    props = [('Anchored', 'bool', True), ('CFrame', 'CFrame', cf), ('size', 'Vector3', size),
             ('Color3uint8', 'Color3uint8', color), ('Material', 'token', MAT[material]),
             ('Transparency', 'float', transparency), ('CanCollide', 'bool', collide),
             ('CanTouch', 'bool', touch), ('CanQuery', 'bool', collide if query is None else query),
             ('CastShadow', 'bool', shadow), ('Reflectance', 'float', reflect),
             ('TopSurface', 'token', 0), ('BottomSurface', 'token', 0),
             ('LeftSurface', 'token', 0), ('RightSurface', 'token', 0),
             ('FrontSurface', 'token', 0), ('BackSurface', 'token', 0)]
    if cls == 'Part':
        props.append(('shape', 'token', SHAPE[shape]))
    if variant:
        props.append(('MaterialVariantSerialized', 'BinaryString', b64(variant)))
    if tags:
        props.append(('Tags', 'BinaryString', tags_b64(*tags)))
    props.extend(extra)
    return item(cls, name, props, parent)

def model(parent, name, tags=None):
    props = []
    if tags:
        props.append(('Tags', 'BinaryString', tags_b64(*tags)))
    return item('Model', name, props, parent)
def folder(parent, name):
    return item('Folder', name, (), parent)

# ---------------------------------------------------------------- reading helpers
def props_of(it):
    return it.find('Properties')
def getp(it, name):
    p = props_of(it)
    if p is None: return None
    for c in p:
        if c.get('name') == name: return c
    return None
def name_of(it):
    c = getp(it, 'Name'); return c.text if c is not None else ''
def child(it, name, cls=None):
    for c in it.findall('Item'):
        if name_of(c) == name and (cls is None or c.get('class') == cls):
            return c
    return None
def set_prop(it, name, typ, v):
    p = props_of(it)
    old = getp(it, name)
    if old is not None:
        p.remove(old)
    enc(p, name, typ, v)
def del_prop(it, name):
    old = getp(it, name)
    if old is not None: props_of(it).remove(old)
def read_cf(el):
    g = lambda k: float(el.find(k).text)
    t = (g('X'), g('Y'), g('Z'))
    R = [[g('R00'), g('R01'), g('R02')], [g('R10'), g('R11'), g('R12')], [g('R20'), g('R21'), g('R22')]]
    return CF(t, R)
def write_cf(el, cf):
    for k, x in zip('XYZ', cf.t): el.find(k).text = _num(x)
    for i in range(3):
        for j in range(3):
            el.find('R%d%d' % (i, j)).text = _num(cf.R[i, j])
def read_v3(el):
    return np.array([float(el.find(k).text) for k in 'XYZ'])
def write_v3(el, v):
    for k, x in zip('XYZ', v): el.find(k).text = _num(x)

PARTS = {'Part', 'MeshPart', 'UnionOperation', 'WedgePart', 'CornerWedgePart', 'TrussPart', 'Seat',
         'SpawnLocation', 'VehicleSeat', 'NegateOperation', 'IntersectOperation'}
STRIP = {'BillboardGui', 'SurfaceGui', 'Script', 'LocalScript', 'ModuleScript', 'ProximityPrompt',
         'ClickDetector', 'Weld', 'WeldConstraint', 'Motor6D', 'Motor', 'Snap', 'ManualWeld', 'Sound',
         'Animator', 'AnimationController', 'Humanoid', 'StringValue', 'NumberValue', 'IntValue',
         'BoolValue', 'ObjectValue', 'Configuration', 'Highlight', 'SelectionBox', 'RopeConstraint',
         'AlignPosition', 'AlignOrientation'}

def world_bbox(root):
    lo = np.array([np.inf] * 3); hi = -lo
    for it in root.iter('Item'):
        if it.get('class') in PARTS:
            tr = getp(it, 'Transparency')
            if tr is not None and float(tr.text) >= 0.99: continue
            cf = read_cf(getp(it, 'CFrame'))
            sz = getp(it, 'size')
            if sz is None: continue
            s = read_v3(sz)
            half = np.abs(cf.R) @ (s / 2)
            lo = np.minimum(lo, cf.t - half); hi = np.maximum(hi, cf.t + half)
    return lo, hi

def _scale_seq(text, s):
    vals = text.split()
    out = []
    for i in range(0, len(vals), 3):
        t, v, e = float(vals[i]), float(vals[i + 1]), float(vals[i + 2])
        out += [_num(t), _num(v * s), _num(e * s)]
    return ' '.join(out) + ' '

def clone(src, placement, origin, s=1.0, strip=STRIP, collide=None, stud_scale=None, keep_gui=False,
          name=None, drop=None):
    """Deep-copy `src`, mapping world point p -> placement * (s * (p - origin)).
    collide: None keeps original CanCollide, True/False forces it.
    drop(item) -> True removes that item."""
    e = copy.deepcopy(src)
    # remove unwanted classes
    for it in list(e.iter('Item')):
        if it is e: continue
        cls = it.get('class')
        if (cls in strip and not (keep_gui and cls in ('BillboardGui', 'SurfaceGui'))) or (drop and drop(it)):
            par = it.getparent()
            if par is not None: par.remove(it)
    # new referents
    mapping = {}
    for it in e.iter('Item'):
        old = it.get('referent'); nr = new_ref(); mapping[old] = nr; it.set('referent', nr)
    for it in e.iter('Item'):
        pr = props_of(it)
        if pr is None: continue
        for c in pr:
            if c.tag == 'Ref' and c.text and c.text != 'null':
                c.text = mapping.get(c.text, 'null')
    origin = np.array(origin, float)
    def mapcf(cf):
        return CF(placement * (s * (cf.t - origin)), placement.R @ cf.R)
    st = s if stud_scale is None else stud_scale
    for it in e.iter('Item'):
        cls = it.get('class')
        if cls in PARTS:
            c = getp(it, 'CFrame'); write_cf(c, mapcf(read_cf(c)))
            for nm in ('size', 'Size'):
                z = getp(it, nm)
                if z is not None: write_v3(z, read_v3(z) * s)
            po = getp(it, 'PivotOffset')
            if po is not None:
                cf = read_cf(po); cf.t = cf.t * s; write_cf(po, cf)
            set_prop(it, 'Anchored', 'bool', True)
            if collide is not None:
                set_prop(it, 'CanCollide', 'bool', collide)
            set_prop(it, 'CanTouch', 'bool', False)
            for nm in ('Velocity', 'RotVelocity', 'AssemblyLinearVelocity', 'AssemblyAngularVelocity'):
                del_prop(it, nm)
        elif cls == 'Model':
            w = getp(it, 'WorldPivotData')
            if w is not None and w.find('CFrame') is not None:
                write_cf(w.find('CFrame'), mapcf(read_cf(w.find('CFrame'))))
            elif w is not None and w.find('X') is not None:
                write_cf(w, mapcf(read_cf(w)))
            pp = getp(it, 'PrimaryPart')
        elif cls == 'Attachment':
            c = getp(it, 'CFrame')
            if c is not None:
                cf = read_cf(c); cf.t = cf.t * s; write_cf(c, cf)
        elif cls == 'SpecialMesh':
            mt = getp(it, 'MeshType')
            if mt is not None and mt.text == '5':
                for nm in ('Scale',):
                    z = getp(it, nm)
                    if z is not None: write_v3(z, read_v3(z) * s)
            z = getp(it, 'Offset')
            if z is not None: write_v3(z, read_v3(z) * s)
        elif cls == 'ParticleEmitter':
            z = getp(it, 'Size')
            if z is not None and z.text: z.text = _scale_seq(z.text, s)
            z = getp(it, 'Speed')
            if z is not None and z.text:
                a = [float(x) for x in z.text.split()]; z.text = ' '.join(_num(x * s) for x in a) + ' '
            z = getp(it, 'Acceleration')
            if z is not None: write_v3(z, read_v3(z) * s)
        elif cls in ('PointLight', 'SpotLight', 'SurfaceLight'):
            z = getp(it, 'Range')
            if z is not None: z.text = _num(min(60, float(z.text) * s))
        elif cls == 'Texture':
            for nm in ('StudsPerTileU', 'StudsPerTileV', 'OffsetStudsU', 'OffsetStudsV'):
                z = getp(it, nm)
                if z is not None: z.text = _num(float(z.text) * st)
        elif cls == 'Beam':
            for nm in ('Width0', 'Width1', 'CurveSize0', 'CurveSize1', 'TextureLength'):
                z = getp(it, nm)
                if z is not None: z.text = _num(float(z.text) * s)
        elif cls in ('Fire', 'Smoke'):
            for nm in ('size_xml', 'Size', 'heat_xml', 'RiseVelocity'):
                z = getp(it, nm)
                if z is not None: z.text = _num(float(z.text) * s)
    if name is not None:
        set_prop(e, 'Name', 'string', name)
    return e
