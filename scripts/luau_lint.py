#!/usr/bin/env python3
"""
Luau Static Analyzer — catches the bug patterns we keep hitting.
No Roblox client needed. Pure static analysis.

Usage: python3 luau_lint.py <file.luau>
"""

import re
import sys
from pathlib import Path

class Issue:
    def __init__(self, severity, line, msg, rule):
        self.severity = severity  # ERROR / WARN / INFO
        self.line = line
        self.msg = msg
        self.rule = rule
    def __str__(self):
        return f"  [{self.severity}] line {self.line}: {self.msg}  ({self.rule})"

issues = []

def analyze(filepath: str):
    code = Path(filepath).read_text(encoding='utf-8', errors='replace')
    lines = code.split('\n')

    # ==========================================
    # RULE 1: math.huge in remote calls
    # ==========================================
    for i, line in enumerate(lines, 1):
        if 'math.huge' in line and ('FireServer' in line or 'InvokeServer' in line):
            issues.append(Issue('ERROR', i,
                'math.huge breaks Roblox network serializer. Use 1e9 or other finite number.',
                'no-infinity-over-network'))

    # ==========================================
    # RULE 2: Forward references to local functions
    # Find every `local function Foo` and `local Foo = function`, then check
    # if Foo is CALLED before its definition line.
    # ==========================================
    func_defs = {}  # name -> def line
    for i, line in enumerate(lines, 1):
        m = re.match(r'\s*local\s+function\s+(\w+)', line)
        if m:
            func_defs[m.group(1)] = i
        m = re.match(r'\s*local\s+(\w+)\s*=\s*function', line)
        if m:
            func_defs[m.group(1)] = i

    # Find forward declarations (local Foo with no assignment)
    forward_decls = set()
    for i, line in enumerate(lines, 1):
        m = re.match(r'\s*local\s+(\w+)\s*$', line)
        if m:
            forward_decls.add(m.group(1))

    # Check calls
    for i, line in enumerate(lines, 1):
        # Skip comment lines
        stripped = line.lstrip()
        if stripped.startswith('--'):
            continue
        # Find calls like Foo( or Foo:
        for name in func_defs:
            if name in forward_decls:
                continue  # forward-declared, safe
            def_line = func_defs[name]
            if i >= def_line:
                continue  # called after def, fine
            # Look for actual call pattern
            if re.search(rf'\b{re.escape(name)}\s*[\(\.]', line):
                # Make sure it's not the def line itself
                if not re.match(rf'\s*local\s+(function\s+)?{re.escape(name)}', line):
                    issues.append(Issue('ERROR', i,
                        f'Forward reference to "{name}" (defined on line {def_line}). '
                        f'Add `local {name}` at the top to forward-declare.',
                        'no-forward-reference'))

    # ==========================================
    # RULE 3: Remote calls without pcall
    # Find :FireServer( and :InvokeServer( not wrapped in pcall
    # ==========================================
    for i, line in enumerate(lines, 1):
        stripped = line.lstrip()
        if stripped.startswith('--'):
            continue
        if (':FireServer(' in line or ':InvokeServer(' in line
            or '.FireServer(' in line or '.InvokeServer(' in line):
            # Check if line is inside a pcall
            # Simple heuristic: line contains 'pcall' OR a recent line opened a pcall
            if 'pcall' in line:
                continue
            # Look back up to 5 lines for pcall( on its own line
            in_pcall = False
            for j in range(max(0, i - 6), i - 1):
                if j < len(lines) and 'pcall(' in lines[j] and ')' not in lines[j]:
                    in_pcall = True
                    break
            if not in_pcall:
                issues.append(Issue('WARN', i,
                    'Remote call without pcall — one failure can crash the loop.',
                    'wrap-remotes-in-pcall'))

    # ==========================================
    # RULE 4: RunService.Heartbeat:Connect without guard
    # If the callback does heavy work, it should early-exit
    # ==========================================
    heartbeat_conns = []
    for i, line in enumerate(lines, 1):
        if 'Heartbeat:Connect' in line or 'Stepped:Connect' in line:
            heartbeat_conns.append(i)
    # Heuristic: if more than 3 heartbeat/stepped connections, warn
    if len(heartbeat_conns) > 3:
        issues.append(Issue('WARN', heartbeat_conns[3],
            f'{len(heartbeat_conns)} RunService connections found — consider consolidating.',
            'too-many-runservice-conns'))

    # ==========================================
    # RULE 5: CurrentOption = {""} for Rayfield dropdowns
    # ==========================================
    for i, line in enumerate(lines, 1):
        if 'CurrentOption' in line and '""' in line:
            issues.append(Issue('ERROR', i,
                'CurrentOption = {""} is invalid — must be a real option string like "None".',
                'rayfield-currentoption-string'))

    # ==========================================
    # RULE 6: Dropdown callback using v[1] without dropValue()
    # ==========================================
    in_dropdown = False
    dropdown_start_line = 0
    for i, line in enumerate(lines, 1):
        if 'CreateDropdown' in line:
            in_dropdown = True
            dropdown_start_line = i
        if in_dropdown and 'Callback' in line and 'function' in line:
            # Find the next few lines for v[1] usage
            for j in range(i, min(i + 8, len(lines))):
                if 'v[1]' in lines[j - 1] and 'dropValue' not in lines[j - 1]:
                    issues.append(Issue('WARN', j,
                        'Dropdown callback uses v[1] — Rayfield may pass a string in newer versions. '
                        'Use dropValue(v) helper.',
                        'rayfield-dropdown-v1'))
                    break
            in_dropdown = False

    # ==========================================
    # RULE 7: workspace.X.Y.Z without nil checks
    # ==========================================
    for i, line in enumerate(lines, 1):
        stripped = line.lstrip()
        if stripped.startswith('--'):
            continue
        # Pattern: workspace.Foo.Bar.Baz (3+ levels deep, no FindFirstChild)
        m = re.search(r'workspace\.(\w+)\.(\w+)\.(\w+)', line)
        if m and 'FindFirstChild' not in line and 'WaitForChild' not in line:
            issues.append(Issue('WARN', i,
                f'Direct workspace.{m.group(1)}.{m.group(2)}.{m.group(3)} access — '
                f'will error if any level is nil. Use FindFirstChild chain.',
                'nil-safe-workspace-access'))

    # ==========================================
    # RULE 8: loadstring without pcall
    # ==========================================
    for i, line in enumerate(lines, 1):
        if 'loadstring(' in line and 'pcall' not in line:
            issues.append(Issue('WARN', i,
                'loadstring without pcall — if the source fails to compile, script crashes silently.',
                'wrap-loadstring-in-pcall'))

    # ==========================================
    # RULE 9: task.spawn without pcall in the spawned function
    # ==========================================
    for i, line in enumerate(lines, 1):
        if 'task.spawn(function()' in line or 'task.spawn(function ()' in line:
            # Look ahead 3 lines for remote calls without pcall
            for j in range(i, min(i + 5, len(lines))):
                if (':FireServer(' in lines[j] or ':InvokeServer(' in lines[j]) and 'pcall' not in lines[j]:
                    issues.append(Issue('WARN', j + 1,
                        'Remote call in task.spawn without pcall — errors here are silent and deadly.',
                        'pcall-in-task-spawn'))
                    break

    # ==========================================
    # RULE 10: Comments claiming "FIX" but no pcall/error handling nearby
    # (Smell test for cargo-cult comments)
    # ==========================================
    for i, line in enumerate(lines, 1):
        if 'CRITICAL' in line and 'Fix' in line:
            # Look ahead 10 lines for the actual fix
            found_safety = False
            for j in range(i, min(i + 10, len(lines))):
                if 'pcall' in lines[j] or 'if not' in lines[j] or 'nil' in lines[j]:
                    found_safety = True
                    break
            if not found_safety:
                issues.append(Issue('INFO', i,
                    'Comment claims CRITICAL FIX but no nil-check or pcall found nearby.',
                    'verify-critical-fix-comments'))

    # ==========================================
    # REPORT
    # ==========================================
    print(f"\n{'=' * 60}")
    print(f"LUAU STATIC ANALYSIS — {filepath}")
    print(f"{'=' * 60}")
    print(f"Lines scanned: {len(lines)}")
    print(f"Issues found: {len(issues)}\n")

    errors = [i for i in issues if i.severity == 'ERROR']
    warns  = [i for i in issues if i.severity == 'WARN']
    infos  = [i for i in issues if i.severity == 'INFO']

    if errors:
        print(f"--- ERRORS ({len(errors)}) ---")
        for e in errors:
            print(e)
        print()

    if warns:
        print(f"--- WARNINGS ({len(warns)}) ---")
        for w in warns:
            print(w)
        print()

    if infos:
        print(f"--- INFO ({len(infos)}) ---")
        for n in infos:
            print(n)
        print()

    if not issues:
        print("✅ No issues found. Code is clean (statically).")
        print("   (Note: this doesn't catch runtime/game-specific issues.)")
    else:
        print(f"Summary: {len(errors)} error(s), {len(warns)} warning(s), {len(infos)} info")

    return len(errors) == 0

if __name__ == '__main__':
    if len(sys.argv) < 2:
        print("Usage: python3 luau_lint.py <file.luau>")
        sys.exit(1)
    ok = analyze(sys.argv[1])
    sys.exit(0 if ok else 1)
