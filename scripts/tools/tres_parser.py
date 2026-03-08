"""
Godot .tres resource file parser.
Reads .tres files into Python dicts, writes them back preserving format.
Handles: strings, ints, floats, bools, Vector2i, Array[T], Dictionary nesting.
"""

import re
import json
import os

def parse_tres(filepath):
    """Parse a .tres file into a dict with 'header' and 'data' keys."""
    with open(filepath, 'r') as f:
        content = f.read()

    # Split header (everything before [resource]) from data
    resource_idx = content.find('[resource]')
    if resource_idx == -1:
        return {'header': content, 'data': {}}

    header = content[:resource_idx + len('[resource]')].strip()
    body = content[resource_idx + len('[resource]'):].strip()

    data = _parse_body(body)
    return {'header': header, 'data': data}


def write_tres(filepath, parsed):
    """Write a parsed dict back to .tres format."""
    lines = [parsed['header'], '']

    for key, value in parsed['data'].items():
        if key == 'script':
            lines.append(f'script = {value}')
        else:
            lines.append(f'{key} = {_serialize_value(value)}')

    with open(filepath, 'w') as f:
        f.write('\n'.join(lines) + '\n')


def _parse_body(body):
    """Parse the body after [resource] into a dict."""
    data = {}
    # We need to handle multi-line values (arrays, dicts)
    lines = body.split('\n')
    i = 0
    while i < len(lines):
        line = lines[i].strip()
        if not line or line.startswith('['):
            i += 1
            continue

        # Match key = value
        m = re.match(r'^(\w+)\s*=\s*(.*)$', line)
        if not m:
            i += 1
            continue

        key = m.group(1)
        value_str = m.group(2)

        # Check if value continues on next lines (arrays, dicts)
        # Count brackets to find complete value
        full_value = value_str
        bracket_depth = _bracket_depth(full_value)
        while bracket_depth > 0 and i + 1 < len(lines):
            i += 1
            full_value += '\n' + lines[i]
            bracket_depth = _bracket_depth(full_value)

        data[key] = _parse_value(full_value.strip())
        i += 1

    return data


def _bracket_depth(s):
    """Count unmatched opening brackets."""
    depth = 0
    in_string = False
    escape = False
    for c in s:
        if escape:
            escape = False
            continue
        if c == '\\':
            escape = True
            continue
        if c == '"':
            in_string = not in_string
            continue
        if in_string:
            continue
        if c in '([{':
            depth += 1
        elif c in ')]}':
            depth -= 1
    return depth


def _parse_value(s):
    """Parse a Godot value string into a Python value."""
    s = s.strip()

    # ExtResource reference - keep as-is
    if s.startswith('ExtResource('):
        return s

    # String
    if s.startswith('"') and s.endswith('"'):
        return s[1:-1]

    # Boolean
    if s == 'true':
        return True
    if s == 'false':
        return False

    # Vector2i
    m = re.match(r'^Vector2i\((-?\d+),\s*(-?\d+)\)$', s)
    if m:
        return {'_type': 'Vector2i', 'x': int(m.group(1)), 'y': int(m.group(2))}

    # Vector2
    m = re.match(r'^Vector2\((-?[\d.]+),\s*(-?[\d.]+)\)$', s)
    if m:
        return {'_type': 'Vector2', 'x': float(m.group(1)), 'y': float(m.group(2))}

    # Array[Type]([...])
    m = re.match(r'^Array\[(\w+)\]\(\[(.*)\]\)$', s, re.DOTALL)
    if m:
        array_type = m.group(1)
        inner = m.group(2).strip()
        if not inner:
            return []
        return _parse_array_contents(inner)

    # Plain array [...]
    if s.startswith('[') and s.endswith(']'):
        inner = s[1:-1].strip()
        if not inner:
            return []
        return _parse_array_contents(inner)

    # Dictionary {...}
    if s.startswith('{') and s.endswith('}'):
        return _parse_dict(s)

    # Integer
    try:
        return int(s)
    except ValueError:
        pass

    # Float
    try:
        return float(s)
    except ValueError:
        pass

    return s


def _parse_array_contents(s):
    """Parse comma-separated values inside an array, handling nested structures."""
    items = []
    depth = 0
    current = ''
    in_string = False
    escape = False

    for c in s:
        if escape:
            current += c
            escape = False
            continue
        if c == '\\':
            current += c
            escape = True
            continue
        if c == '"':
            in_string = not in_string
            current += c
            continue
        if in_string:
            current += c
            continue

        if c in '([{':
            depth += 1
            current += c
        elif c in ')]}':
            depth -= 1
            current += c
        elif c == ',' and depth == 0:
            item = current.strip()
            if item:
                items.append(_parse_value(item))
            current = ''
        else:
            current += c

    item = current.strip()
    if item:
        items.append(_parse_value(item))

    return items


def _parse_dict(s):
    """Parse a Godot dictionary string into a Python dict."""
    s = s.strip()
    if s == '{}':
        return {}

    # Remove outer braces
    inner = s[1:-1].strip()
    if not inner:
        return {}

    result = {}
    # Split by key: value pairs, handling nested structures
    depth = 0
    current = ''
    in_string = False
    escape = False

    for c in inner:
        if escape:
            current += c
            escape = False
            continue
        if c == '\\':
            current += c
            escape = True
            continue
        if c == '"':
            in_string = not in_string
            current += c
            continue
        if in_string:
            current += c
            continue

        if c in '([{':
            depth += 1
            current += c
        elif c in ')]}':
            depth -= 1
            current += c
        elif c == ',' and depth == 0:
            _add_dict_entry(result, current.strip())
            current = ''
        else:
            current += c

    if current.strip():
        _add_dict_entry(result, current.strip())

    return result


def _add_dict_entry(result, entry):
    """Parse a 'key: value' or '"key": value' entry and add to result dict."""
    # Match "key": value
    m = re.match(r'^"([^"]+)"\s*:\s*(.+)$', entry, re.DOTALL)
    if m:
        key = m.group(1)
        val = _parse_value(m.group(2).strip())
        result[key] = val


def _serialize_value(value):
    """Serialize a Python value back to Godot .tres format."""
    if value is None:
        return '""'

    if isinstance(value, str):
        if value.startswith('ExtResource('):
            return value
        return f'"{value}"'

    if isinstance(value, bool):
        return 'true' if value else 'false'

    if isinstance(value, int):
        return str(value)

    if isinstance(value, float):
        return str(value)

    if isinstance(value, dict):
        if '_type' in value:
            t = value['_type']
            if t == 'Vector2i':
                return f'Vector2i({value["x"]}, {value["y"]})'
            if t == 'Vector2':
                return f'Vector2({value["x"]}, {value["y"]})'
        # Regular dictionary
        return _serialize_dict(value)

    if isinstance(value, list):
        if not value:
            return 'Array[Dictionary]([])'
        # Check if all items are dicts
        all_dicts = all(isinstance(v, dict) and '_type' not in v for v in value)
        if all_dicts:
            items = ', '.join(_serialize_dict(v) for v in value)
            return f'Array[Dictionary]([{items}])'
        items = ', '.join(_serialize_value(v) for v in value)
        return f'[{items}]'

    return str(value)


def _serialize_dict(d):
    """Serialize a dict to Godot format."""
    if not d:
        return '{}'
    pairs = []
    for k, v in sorted(d.items()):
        pairs.append(f'"{k}": {_serialize_value(v)}')
    return '{\n' + ',\n'.join(pairs) + '\n}'


def load_zone(filepath):
    """Load a zone .tres and return JSON-friendly data."""
    parsed = parse_tres(filepath)
    data = parsed['data']
    # Convert Vector2i types for JSON
    result = {}
    for key, val in data.items():
        if key == 'script':
            continue
        result[key] = _to_json(val)
    return result


def save_zone(filepath, zone_data):
    """Save zone data back to .tres, preserving the original header."""
    parsed = parse_tres(filepath)
    # Update data fields from zone_data
    for key, val in zone_data.items():
        parsed['data'][key] = _from_json(key, val, parsed['data'].get(key))
    write_tres(filepath, parsed)


def _to_json(val):
    """Convert parsed value to JSON-safe format."""
    if isinstance(val, dict) and '_type' in val:
        if val['_type'] in ('Vector2i', 'Vector2'):
            return {'x': val['x'], 'y': val['y']}
    if isinstance(val, dict):
        return {k: _to_json(v) for k, v in val.items()}
    if isinstance(val, list):
        return [_to_json(v) for v in val]
    if isinstance(val, str) and val.startswith('ExtResource('):
        return None  # Skip internal references
    return val


def _from_json(key, val, original):
    """Convert JSON value back to internal format for serialization."""
    # Detect Vector2i fields by key name or original type
    vector_fields = {'world_pos', 'baked_offset'}
    if key in vector_fields and isinstance(val, dict):
        return {'_type': 'Vector2i', 'x': int(val['x']), 'y': int(val['y'])}
    if isinstance(original, dict) and original.get('_type') == 'Vector2i' and isinstance(val, dict):
        return {'_type': 'Vector2i', 'x': int(val['x']), 'y': int(val['y'])}
    return val


# ── Quick test ──
if __name__ == '__main__':
    import sys
    if len(sys.argv) < 2:
        print("Usage: python tres_parser.py <file.tres>")
        sys.exit(1)
    parsed = parse_tres(sys.argv[1])
    data = load_zone(sys.argv[1])
    print(json.dumps(data, indent=2))
