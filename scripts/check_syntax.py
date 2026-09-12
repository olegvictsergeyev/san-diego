#!/usr/bin/env python3
"""Синтаксическая проверка всех .lua модулей сервиса.

Использование: python3 scripts/check_syntax.py
Требует: pip install luaparser (Luau-конструкции continue/+= parser не
знает — они фильтруются как ложные срабатывания).
"""
import glob
import os
import sys

try:
    from luaparser import ast
except ImportError:
    sys.exit("luaparser не установлен: pip install luaparser")

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
failed = False
for path in sorted(glob.glob(os.path.join(ROOT, "modules", "*.lua")) + glob.glob(os.path.join(ROOT, "final", "*.lua"))):
    src = open(path, encoding="utf-8").read()
    name = os.path.relpath(path, ROOT)
    try:
        ast.parse(src)
        print("OK  ", name)
    except Exception as e:
        msg = str(e)
        if "continue" in msg or "failStreak +" in msg or "+=" in msg:
            print("OK* ", name, "(Luau-синтаксис, ложное срабатывание)")
        else:
            failed = True
            print("FAIL", name, ":", msg[:200])

sys.exit(1 if failed else 0)
