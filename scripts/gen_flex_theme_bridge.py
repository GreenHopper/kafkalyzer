#!/usr/bin/env python3
"""Generate a legacy flutter/material -> material_ui ThemeData converter for
themes produced by flex_color_scheme (which still targets legacy flutter/material).

Both packages are API-identical forks, so a field-by-field copy works.
"""
import re, os

LEGACY_SRC = '/home/kaufmannr/development/flutter/packages/flutter/lib/src/material'  # <flutter-sdk>/packages/flutter/lib/src/material
OUT = 'lib/src/flex_theme_bridge.dart'

if not os.path.isdir(LEGACY_SRC):
    raise SystemExit(f'Legacy material source not found: {LEGACY_SRC}\n'
                     'Set LEGACY_SRC to <flutter-sdk>/packages/flutter/lib/src/material')

def _read(path: str) -> str:
    try:
        with open(path, encoding='utf-8') as fh:
            return fh.read()
    except OSError as e:
        raise SystemExit(f'Failed to read {path}: {e}') from e

SHARED_WORDS = {
    'Color','TextStyle','double','int','bool','num','Widget','String','Object','dynamic','void',
    'Radius','BorderRadius','Size','Alignment','AlignmentGeometry','EdgeInsets','EdgeInsetsGeometry',
    'Duration','Curve','TextDecoration','IconData','MouseCursor','FocusNode','TextSpan','WidgetSpan',
    'TapRegionShape','PointerDeviceKind','ScribbleContext','UIFeature','UIFeaturePadding',
    'KeyboardShortcut','ShortcutActivator','SpellCheckConfiguration','ScrollBehavior','ScrollPhysics',
    'TextScaler','TextHeightBehavior','SelectionChangedCause','FocusHighlightMode','FocusTraversalGroup',
    'FocusTraversalPolicy','FocusHighlightStrategy','SemanticsBinding','Axis','CrossAxisAlignment',
    'MainAxisSize','BoxFit','BoxBorder','Shadow','FontWeight','FontFeature','FontFeatures','TextDirection',
    'Brightness','TargetPlatform','PlatformBrightness','ImageFilter','Function','VoidCallback',
    'IconSize','IconColor','IconWeight','IconGeometry','IconPlatform','BorderSide','BoxShadow',
    'List','Set','Map','Iterable','WidgetStateProperty','MaterialStateProperty','WidgetState',
    'MaterialState','Scribbleable','FocusHighlightStrategy','EdgeInsets','EdgeInsetsGeometry',
    'FocusNode','TextBaseline','TextLeadingDistribution','Overflow','WrapAlignment','WrapAlignment?',
    'Axis','CrossAxisAlignment','MainAxisSize','BoxFit','BoxBorder','Shadow','TextOverflow',
    'TextWrap','StrutStyle','StrutStyle?',
    'ElevationOverlayMode','ElevationOverlayMode?','MaterialType','MaterialType?',
    'ImageFilter','FilterQuality','FilterQuality?','Clip','Clip?','ShapeBorder','ShapeBorder?',
    # classes that live in flutter/widgets, flutter/painting or dart:ui (shared with material_ui):
    'IconThemeData','IconThemeData?','PageTransitionBuilder','PageTransitionsThemeBuilder',
    'Offset','Offset?','BorderRadiusGeometry','BorderRadiusGeometry?','Decoration','Decoration?',
    'OutlinedBorder','OutlinedBorder?','BoxConstraints','BoxConstraints?','NotchedShape','NotchedShape?',
    'Locale','Locale?','StrokeCap','StrokeCap?','TextCapitalization','TextCapitalization?',
    'TextAlign','TextAlign?','Icon','Icon?','AnimationController','AnimationController?',
    'Animation','Animation?','AnimationStyle','AnimationStyle?','ButtonLayerBuilder','ButtonLayerBuilder?','ButtonStyleButton',
    'DismissDirection','DismissDirection?','TooltipTriggerMode','TooltipTriggerMode?',
    'MainAxisAlignment','MainAxisAlignment?',
    'TabBarIndicator','TabBarIndicator?','ButtonState','ButtonState?',
}

def _split_generic(t: str) -> list[str]:
    """Split 'A<B, C<D>>' into top-level parts. Only '<'/'>' count as depth
    (function types like 'void Function(void)' may contain commas in parens)."""
    out = []
    depth = 0; cur = ''
    for ch in t:
        if ch == '<': depth += 1
        elif ch == '>': depth -= 1
        if ch == ',' and depth == 0:
            out.append(cur.strip()); cur = ''
        else:
            cur += ch
    if cur.strip(): out.append(cur.strip())
    return out

def is_shared(t: str) -> bool:
    t = t.strip().rstrip('?').strip()
    if not t:
        return False
    if t in SHARED_WORDS:
        return True
    if '<' not in t:
        return False
    head = t[:t.index('<')].strip()
    if head not in SHARED_WORDS:
        return False
    inner = t[t.index('<') + 1: t.rindex('>')]
    for a in _split_generic(inner):
        a2 = a.rstrip('?').strip()
        if a2 in SHARED_WORDS:
            continue
        if '<' in a2:
            if not is_shared(a):
                return False
            continue
        # function type like 'void Function(BuildContext, Animation<double>)'
        if 'Function' in a2 or '(' in a2:
            continue
        return False
    return True

def find_class_file(name: str) -> str | None:
    snake = re.sub(r'(?<!^)(?=[A-Z])', '_', name).lower() + '.dart'
    if os.path.exists(os.path.join(LEGACY_SRC, snake)):
        return snake
    try:
        files = sorted(os.listdir(LEGACY_SRC))
    except OSError as e:
        raise SystemExit(f'Failed to list {LEGACY_SRC}: {e}') from e
    for f in files:
        if f.endswith('.dart') and re.search(r'\b(?:class|enum|abstract class)\s+' + re.escape(name) + r'\b',
                                             _read(os.path.join(LEGACY_SRC, f))):
            return f
    return None

class Info:
    def __init__(self, name, file):
        self.name = name
        self.file = file
        self.params = []
        self.kind = 'class'
        self.enums: list[str] | None = None
        self.fields = {}  # field name -> type (from class body declarations)
        self.public: set[str] = set()  # public field/getter names
        self.src = ''  # full legacy source of the defining file

def _is_redirecting(src: str, open_brace: int) -> bool:
    """True if `} ) = OtherFactory` follows this constructor body."""
    depth = 0; j = open_brace
    while True:
        c = src[j]
        if c == '{': depth += 1
        elif c == '}':
            depth -= 1
            if depth == 0: break
        j += 1
    tail = src[j:j + 30].lstrip(') \n')
    return tail.startswith('=')

def extract_params(src: str, cls: str):
    # Anchor to line start: inline calls like `data = Foo({` inside other
    # constructors must not match. Skip redirecting factories (`= Foo.other`).
    pat = re.compile(r'^\s*(?:const\s+|factory\s+)?' + re.escape(cls) + r'\s*\(\s*\{', re.M)
    m = None
    for cand in pat.finditer(src):
        ob = src.index('{', cand.start())
        if not _is_redirecting(src, ob):
            m = cand
            break
    if not m:
        return None
    start = src.index('{', m.start())
    depth = 0; j = start
    while True:
        c = src[j]
        if c == '{': depth += 1
        elif c == '}':
            depth -= 1
            if depth == 0: break
        j += 1
    body = src[start+1:j]
    params = []
    depth = 0; cur = ''
    for ch in body:
        if ch in '<(': depth += 1
        elif ch in '>)': depth -= 1
        if ch == ',' and depth == 0:
            params.append(cur); cur = ''
        else:
            cur += ch
    if cur.strip(): params.append(cur)
    out = []
    for p in params:
        p = p.strip()
        p = re.sub(r'^required\s+', '', p).strip()
        if not p: continue
        tm = re.match(r'this\.([a-z][a-zA-Z0-9_]*)\s*(?::|=|,|$)', p)
        if tm:
            out.append(('this:' + tm.group(1), 'THIS'))
            continue
        sm = re.match(r'super\.([a-zA-Z0-9_]+)\s*(?::|=|,|$)', p)
        if sm:
            out.append(('super:' + sm.group(1), 'SUPER'))
            continue
        pm = re.match(r'(?:final\s+)?([A-Za-z_][\w<>, ?]*?)\s+([a-z][a-zA-Z0-9_]*)\s*(?::|=|$)', p)
        if pm:
            out.append((pm.group(2), pm.group(1).strip()))
    return out

def class_body(src: str, cls: str) -> str:
    m = re.search(r'(?:class|abstract class)\s+' + re.escape(cls) + r'\b', src)
    if not m:
        return ''
    start = src.index('{', m.end())
    depth = 0; j = start
    while True:
        c = src[j]
        if c == '{': depth += 1
        elif c == '}':
            depth -= 1
            if depth == 0: break
        j += 1
    return src[start+1:j]

def extract_fields(src: str, cls: str):
    """Map field name -> declared type from the class body."""
    body = class_body(src, cls)
    fields = {}
    for fm in re.finditer(r'\bfinal\s+([A-Za-z_][\w<>, ?]*?)\s+([a-z][a-zA-Z0-9_]*)\s*(?:=|;)', body):
        fields[fm.group(2)] = fm.group(1).strip()
    return fields

def extract_public_names(src: str, cls: str):
    """Public field + getter names of the class body."""
    body = class_body(src, cls)
    names = set()
    for fm in re.finditer(r'\bfinal\s+[\w<>, ?]+?\s+([a-z][a-zA-Z0-9_]*)\s*(?:=|;)', body):
        names.add(fm.group(1))
    for gm in re.finditer(r'\bget\s+([a-z][a-zA-Z0-9_]*)\b', body):
        names.add(gm.group(1))
    return names

def extract_enum_values(src: str, cls: str):
    m = re.search(r'enum\s+' + re.escape(cls) + r'\s*\{([^}]*)\}', src)
    if not m: return None
    vals = []
    for v in m.group(1).split(','):
        v = v.strip()
        if v and not v.startswith('//'):
            vals.append(v.split('//')[0].strip())
    return [v for v in vals if v]

registry = {}
SKIP_TYPES = {
    'NoDefaultCupertinoThemeData', 'ThemeExtension', 'CupertinoAdaptiveTextSelectionToolbar',
    # abstract slider shapes / delegates FlexColorScheme never sets (null in its output):
    'RangeThumbSelector', 'SliderTrackShape', 'SliderTickMarkShape', 'SliderThumbShape',
    'RangeSliderThumbShape', 'RangeSliderTickMarkShape', 'Thumb', 'RangeSliderTrackShape',
    'SliderComponentShape', 'RangeSliderValueIndicatorShape',
    'InteractiveInkFeatureFactory',
}

def get_info(name: str) -> Info | None:
    base = name.split('<')[0].strip().rstrip('?').strip()
    if base in SKIP_TYPES:
        return None
    if base in registry:
        return registry[base]
    f = find_class_file(base)
    if not f:
        return None
    src = _read(os.path.join(LEGACY_SRC, f))
    info = Info(base, f)
    if re.search(r'\benum\s+' + re.escape(base) + r'\b', src):
        info.kind = 'enum'
        info.enums = extract_enum_values(src, base)
        if info.enums is None:
            info.kind = 'unknown'
    else:
        info.params = extract_params(src, base) or []
        info.fields = extract_fields(src, base)
        info.public = extract_public_names(src, base)
        info.src = src
    registry[base] = info
    return info

def lookup_field(info: Info, param: str) -> str | None:
    """Field type lookup restricted to the class body (fields may be
    declared with a getter/field split, but must belong to this class)."""
    if param in info.fields:
        return info.fields[param]
    body = class_body(getattr(info, 'src', ''), info.name)
    m = re.search(r'\bfinal\s+([A-Za-z_][\w<>, ?]*?)\s+' + re.escape(param) + r'\s*(?:=|;)', body)
    if m:
        return m.group(1).strip()
    return None

def needs_mapping(t: str) -> bool:
    t = t.strip().rstrip('?').strip()
    if not t: return False
    if t in ('Object', 'dynamic', 'void'): return False
    if is_shared(t): return False
    base = (t[:t.index('<')] if '<' in t else t).strip()
    return get_info(base) is not None

# ---- parse ThemeData ----
td = get_info('ThemeData')
assert td and td.params, "failed to parse ThemeData"

SPECIAL = {
    'visualDensity': 'VISUAL_DENSITY',
    'splashFactory': 'SPLASH',
    'cupertinoOverrideTheme': 'NULL',
    'extensions': 'NULL',
    'adaptations': 'NULL',
}

# (ClassName, param) -> (abstract base type, concrete const subtypes)
SPECIAL_PARAMS = {
    ('SliderThemeData', 'valueIndicatorShape'):
        ('SliderComponentShape', ['DropSliderValueIndicatorShape',
                                  'RectangularSliderValueIndicatorShape',
                                  'RoundedRectSliderValueIndicatorShape']),
    ('SliderThemeData', 'rangeValueIndicatorShape'):
        ('RangeSliderValueIndicatorShape', ['PaddleRangeSliderValueIndicatorShape',
                                            'RectangularRangeSliderValueIndicatorShape',
                                            'RoundedRectRangeSliderValueIndicatorShape']),
}

# closure of material types
mapped = []
def add_map(t):
    base = (t[:t.index('<')] if '<' in t else t).strip().rstrip('?').strip()
    if base == 'ThemeData' or base in [m.name for m in mapped]:
        return
    mi = get_info(base)
    if mi and mi.kind != 'unknown':
        mapped.append(mi)

for (name, t) in td.params:
    if name in SPECIAL: continue
    if needs_mapping(t):
        add_map(t)

def resolve_pt(mi: Info, pn: str, pt: str) -> str:
    """Resolve constructor param type to a concrete type ('' if unknown)."""
    if pt == 'THIS':
        param = pn[5:]
        return lookup_field(mi, param) or ''
    if pt == 'SUPER':
        return ''
    return pt

changed = True
while changed:
    changed = False
    for mi in list(mapped):
        for (pn, pt) in mi.params:
            pt = resolve_pt(mi, pn, pt)
            if not pt or not needs_mapping(pt): continue
            base = (pt[:pt.index('<')] if '<' in pt else pt).strip().rstrip('?').strip()
            if base == 'ThemeData' or base in [m.name for m in mapped]: continue
            nmi = get_info(base)
            if nmi and nmi.kind != 'unknown':
                mapped.append(nmi)
                changed = True

SKIPPED_PARAMS = []  # (ClassName, param)

def gen_param(info: Info, v: str, pn: str, pt: str, args: list, skipped: list) -> bool:
    """Emit one constructor arg. Returns True if emitted."""
    param = pn
    if pt == 'THIS':
        param = pn[5:]
        ftype = lookup_field(info, param)
        if not ftype:
            skipped.append(f'{info.name}.{param}')
            return False
        pt = ftype
    elif pt == 'SUPER':
        param = pn[6:]
        skipped.append(f'{info.name}.{param} (super)')
        return False
    sp = SPECIAL_PARAMS.get((info.name, param))
    if sp:
        base_type, _shapes = sp
        helper = f'_map{base_type}Shapes'
        args.append(f'{param}: {helper}({v}.{param})')
        return True
    # Skip params with no public accessor on the legacy class (private-only fields).
    pub = getattr(info, 'public', None)
    if pub and param not in pub:
        skipped.append(f'{info.name}.{param} (not public)')
        return False
    # Prefer the field's nullability (constructor params may be looser).
    ftype = lookup_field(info, param)
    nullable = (ftype or pt).rstrip().endswith('?')
    if pt in ('Object?', 'Object', 'dynamic', 'void'):
        args.append(f'{param}: {v}.{param}')
        return True
    if needs_mapping(pt):
        base = (pt[:pt.index('<')] if '<' in pt else pt).strip().rstrip('?').strip()
        ti = get_info(base)
        if ti and ti.kind != 'unknown':
            src = f'{v}.{param}'
            if ti.kind == 'enum':
                if nullable:
                    args.append(f'{param}: {src} == null ? null : '
                               f'modern.{base}.values[legacy.{base}.values.indexOf({src}!)]')
                else:
                    args.append(f'{param}: '
                               f'modern.{base}.values[legacy.{base}.values.indexOf({src})]')
            elif base == 'MaterialColor':
                e = f'modern.MaterialColor({src}!.value, {src}!.swatch)'
                args.append(f'{param}: {src} == null ? null : {e}' if nullable else f'{param}: {e}')
            else:
                e = f'_map{base}({src}!)' if nullable else f'_map{base}({src})'
                args.append(f'{param}: {src} == null ? null : {e}' if nullable else f'{param}: {e}')
            return True
        skipped.append(f'{info.name}.{param}')
        return False
    if is_shared(pt):
        args.append(f'{param}: {v}.{param}')
        return True
    skipped.append(f'{info.name}.{param}')
    return False

def gen_expr(info: Info, v: str) -> str | None:
    """Emit an expression mapping `v` (legacy instance) to a modern instance."""
    if info.kind == 'enum':
        return f'modern.{info.name}.values[legacy.{info.name}.values.indexOf({v})]'
    if info.name == 'MaterialColor':
        return f'modern.MaterialColor({v}.value, {v}.swatch)'
    args = []
    for (pn, pt) in info.params:
        gen_param(info, v, pn, pt, args, SKIPPED_PARAMS)
    if not args:
        return f'modern.{info.name}()'
    body = ',\n      '.join(args)
    return f'modern.{info.name}(\n      {body}\n    )'

lines = []
lines.append('// GENERATED by scripts/gen_flex_theme_bridge.py -- do not edit by hand.')
lines.append('// Bridges legacy `package:flutter/material` ThemeData (as produced by')
lines.append('// flex_color_scheme, which has not yet migrated to package:material_ui) into')
lines.append('// the modern `package:material_ui` ThemeData expected by Flutter 3.47+ apps.')
lines.append('//')
lines.append('// See https://github.com/rydmike/flex_color_scheme/issues/310')
lines.append('//')
lines.append("import 'package:flutter/material.dart' as legacy;")
lines.append("import 'package:material_ui/material_ui.dart' as modern;")
lines.append('')
# ---- special runtime-type shape mappers ----
for (cls, param), (base_type, shapes) in SPECIAL_PARAMS.items():
    helper = f'_map{base_type}Shapes'
    lines.append(f'modern.{base_type}? {helper}(legacy.{base_type}? v) {{')
    lines.append('  if (v == null) return null;')
    for s in shapes:
        lines.append(f'  if (v is legacy.{s}) return const modern.{s}();')
    lines.append('  return null;')
    lines.append('}')
    lines.append('')

# ---- per-type helper functions ----
for info in mapped:
    if info.kind == 'enum':
        continue
    if info.name == 'MaterialColor':
        continue
    expr = gen_expr(info, 't')
    lines.append(f'modern.{info.name} _map{info.name}(legacy.{info.name} t) {{')
    lines.append(f'  return {expr};')
    lines.append('}')
    lines.append('')

# ---- main converter ----
lines.append('/// Converts a legacy flex_color_scheme `ThemeData` into a modern material_ui `ThemeData`.')
lines.append('// ignore: deprecated_member_use')
lines.append('modern.ThemeData flexThemeToModern(legacy.ThemeData t) {')
args = []
skipped_all = []
for (name, t) in td.params:
    if name in SPECIAL:
        mode = SPECIAL[name]
        if mode == 'VISUAL_DENSITY':
            args.append('visualDensity: modern.VisualDensity('
                        'horizontal: t.visualDensity.horizontal, vertical: t.visualDensity.vertical)')
        elif mode == 'SPLASH':
            args.append('splashFactory: t.splashFactory is legacy.NoSplash ? modern.NoSplash.splashFactory : null')
        continue
    gen_param(td, 't', name, t, args, skipped_all)
body = ',\n    '.join(args)
lines.append(f'  return modern.ThemeData(\n    {body}\n  );')
lines.append('}')
lines.append('')
if skipped_all:
    lines.append('// Fields intentionally not mapped (null in FlexColorScheme output or unmappable):')
    lines.append('//   ' + ', '.join(skipped_all))

try:
    with open(OUT, 'w', encoding='utf-8') as f:
        f.write('\n'.join(lines) + '\n')
except OSError as e:
    raise SystemExit(f'Failed to write {OUT}: {e}') from e

print("mapped types:", [m.name for m in mapped])
print("skipped td fields:", skipped_all)
print("skipped nested params:", sorted(set(SKIPPED_PARAMS)))
