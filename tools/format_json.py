#!/usr/bin/env python3
"""Formatea data/worlds.json: indentado, pero con listas y objetos cortos en una línea.

Uso: python3 tools/format_json.py [archivo]
"""
import json
import sys
from pathlib import Path

WIDTH = 110


def dump(obj, indent=0):
    pad = "  " * indent
    inline = json.dumps(obj, ensure_ascii=False)
    if not isinstance(obj, (dict, list)) or len(inline) + len(pad) <= WIDTH and not _has_nested_big(obj):
        return inline
    if isinstance(obj, list):
        items = [("  " * (indent + 1)) + dump(v, indent + 1) for v in obj]
        return "[\n" + ",\n".join(items) + "\n" + pad + "]"
    items = [("  " * (indent + 1)) + json.dumps(k, ensure_ascii=False) + ": " + dump(v, indent + 1) for k, v in obj.items()]
    return "{\n" + ",\n".join(items) + "\n" + pad + "}"


def _has_nested_big(obj):
    """Los niveles completos (con muchas claves) no van en una línea aunque entren."""
    return isinstance(obj, dict) and len(obj) > 6


def main():
    path = Path(sys.argv[1] if len(sys.argv) > 1 else Path(__file__).resolve().parent.parent / "data" / "worlds.json")
    data = json.loads(path.read_text())
    path.write_text(dump(data) + "\n")


if __name__ == "__main__":
    main()
