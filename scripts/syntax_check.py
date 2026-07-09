#!/usr/bin/env python3
"""Basic Luau syntax sanity check — counts block opener/closer balance.
Not a full parser, but catches the most common mistakes (unbalanced
function/end, if/end, do/end, Connect(...end), etc.).
"""
import sys
import re

def check_file(path):
    with open(path, "r") as f:
        src = f.read()
    # Strip strings and comments to avoid false positives
    # (simplified — doesn't handle all edge cases, but good enough for sanity)
    cleaned = re.sub(r'"(?:[^"\\]|\\.)*"', '""', src)
    cleaned = re.sub(r"'(?:[^'\\]|\\.)*'", "''", cleaned)
    cleaned = re.sub(r'\[(?:[^\]])*\]', '[]', cleaned)
    # Strip block comments --[[ ... ]]
    cleaned = re.sub(r'--\[\[.*?\]\]', '', cleaned, flags=re.DOTALL)
    # Strip line comments
    cleaned = re.sub(r'--[^\n]*', '', cleaned)

    # Count block keywords
    funcs = len(re.findall(r'\bfunction\b', cleaned))
    ends = len(re.findall(r'\bend\b', cleaned))
    ifs = len(re.findall(r'\bif\b', cleaned))
    fors = len(re.findall(r'\bfor\b', cleaned))
    whiles = len(re.findall(r'\bwhile\b', cleaned))
    dos = len(re.findall(r'\bdo\b', cleaned))

    # Each function/if/for/while/do needs one 'end' (do...end, while...do...end, etc.)
    # 'do' as a standalone block (do ... end) also needs an end
    # Note: 'for x in y do' uses do, so we don't double-count
    expected_ends = funcs + ifs + fors + whiles
    # Actually for/while use 'do', so: for...do...end → 1 for + 1 do + 1 end
    # But our regex counts 'do' separately. Let's be more careful:
    # function...end → 1 function + 1 end
    # if...end → 1 if + 1 end
    # for...do...end → 1 for + 1 do + 1 end (do is part of for syntax)
    # while...do...end → 1 while + 1 do + 1 end (do is part of while syntax)
    # do...end (standalone) → 1 do + 1 end
    # So: ends == funcs + ifs + fors + whiles + standalone_dos
    # standalone_dos = dos - fors - whiles (since for/while each consume one do)
    standalone_dos = dos - fors - whiles
    expected_ends = funcs + ifs + fors + whiles + standalone_dos

    # Count parens balance
    opens = cleaned.count('(')
    closes = cleaned.count(')')

    # Count braces
    obraces = cleaned.count('{')
    cbraces = cleaned.count('}')

    # Count brackets
    obrackets = cleaned.count('[')
    cbrackets = cleaned.count(']')

    print(f"=== {path} ===")
    print(f"function: {funcs}, if: {ifs}, for: {fors}, while: {whiles}, do: {dos} (standalone: {standalone_dos})")
    print(f"end: {ends}, expected: {expected_ends} → {'OK' if ends == expected_ends else 'MISMATCH!'}")
    print(f"parens: ( {opens} vs ) {closes} → {'OK' if opens == closes else 'MISMATCH!'}")
    print(f"braces: {{ {obraces} vs }} {cbraces} → {'OK' if obraces == cbraces else 'MISMATCH!'}")
    print(f"brackets: [ {obrackets} vs ] {cbrackets} → {'OK' if obrackets == cbrackets else 'MISMATCH!'}")
    return ends == expected_ends and opens == closes and obraces == cbraces and obrackets == cbrackets

ok1 = check_file("/home/z/my-project/RezurXLib.lua")
ok2 = check_file("/home/z/my-project/DOMINUS_V8.luau")
print()
print("RESULT:", "ALL OK" if (ok1 and ok2) else "SYNTAX ERROR DETECTED")
