#!/usr/bin/env python3
"""Proper Luau syntax balance checker — strips strings & comments correctly."""
import re
from pathlib import Path

def check(path):
    with open(path) as f:
        src = f.read()
    # Strip block comments --[[ ... ]]
    c = re.sub(r'--\[\[.*?\]\]', '', src, flags=re.DOTALL)
    # Strip line comments
    c = re.sub(r'--[^\n]*', '', c)
    # Strip double-quoted strings (handle escapes)
    c = re.sub(r'"(?:[^"\\]|\\.)*"', '""', c)
    # Strip single-quoted strings
    c = re.sub(r"'(?:[^'\\]|\\.)*'", "''", c)
    # Strip long-bracket strings [[ ... ]] and [=[ ... ]=]
    c = re.sub(r'\[(=*)\[.*?\]\1\]', '""', c, flags=re.DOTALL)

    funcs = len(re.findall(r'\bfunction\b', c))
    ends = len(re.findall(r'\bend\b', c))
    ifs = len(re.findall(r'\bif\b', c))
    fors = len(re.findall(r'\bfor\b', c))
    whiles = len(re.findall(r'\bwhile\b', c))
    dos = len(re.findall(r'\bdo\b', c))
    # do appears in: for...do, while...do, standalone do...end, repeat...until (no do)
    # Each for/while consumes one do. Standalone do = dos - fors - whiles
    standalone_dos = dos - fors - whiles
    expected_ends = funcs + ifs + fors + whiles + standalone_dos

    opens = c.count('(')
    closes = c.count(')')
    obraces = c.count('{')
    cbraces = c.count('}')
    obrackets = c.count('[')
    cbrackets = c.count(']')

    print(f"=== {path} ===")
    print(f"function: {funcs}, if: {ifs}, for: {fors}, while: {whiles}, do: {dos} (standalone: {standalone_dos})")
    print(f"end: {ends}, expected: {expected_ends} -> {'OK' if ends == expected_ends else 'MISMATCH'}")
    print(f"parens: {opens} vs {closes} -> {'OK' if opens == closes else 'MISMATCH'}")
    print(f"braces: {obraces} vs {cbraces} -> {'OK' if obraces == cbraces else 'MISMATCH'}")
    print(f"brackets: {obrackets} vs {cbrackets} -> {'OK' if obrackets == cbrackets else 'MISMATCH'}")
    return ends == expected_ends and opens == closes and obraces == cbraces and obrackets == cbrackets

root = Path(__file__).resolve().parent.parent
ok1 = check(root / "RezurXLib.lua")
ok2 = check(root / "DOMINUS_V8.luau")
print()
print("RESULT:", "ALL OK" if (ok1 and ok2) else "SYNTAX ERROR DETECTED")
