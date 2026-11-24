#!/usr/bin/env python3
"""Herramienta de desarrollo: compara PyEval con Python real.

Uso: python3 tools/py_diff.py programas.py
El archivo tiene programas separados por líneas '#---'. Cada programa puede empezar con
'#inputs: a|b|c' y '#files: {"x.txt": "..."}' (JSON).
Imprime los programas donde la salida o el error no coinciden.
"""
import io, json, os, subprocess, sys, tempfile, contextlib, builtins

def run_python(code, inputs, files):
    out = io.StringIO()
    it = iter(inputs)
    fs = dict(files)
    class F(io.StringIO):
        def __init__(self, name, mode):
            self.name_, self.mode_ = name, mode
            super().__init__(fs.get(name, "") if mode == "r" else ("" if mode == "w" else fs.get(name, "")))
            if mode == "a": self.seek(0, 2)
        def write(self, s):
            r = super().write(s); fs[self.name_] = self.getvalue(); return r
    def fake_open(name, mode="r", encoding=None):
        mode = mode.replace("t", "")
        if mode == "r" and name not in fs:
            raise FileNotFoundError(2, "No such file or directory", name)
        if mode == "w": fs[name] = ""
        if mode == "a": fs.setdefault(name, "")
        return F(name, mode)
    g = {"__builtins__": builtins, "input": lambda *a: next(it), "open": fake_open}
    err = ""
    with contextlib.redirect_stdout(out):
        try:
            exec(compile(code, "<p>", "exec"), g)
        except StopIteration:
            err = "EOFError"
        except SyntaxError as e:
            err = type(e).__name__
        except RecursionError:
            err = "RecursionError"
        except Exception as e:
            err = type(e).__name__
    return out.getvalue().rstrip("\n"), err

def main():
    src = open(sys.argv[1]).read()
    progs = []
    for chunk in src.split("#---\n"):
        lines = chunk.strip("\n").split("\n")
        inputs, files = [], {}
        while lines and lines[0].startswith(("#inputs:", "#files:")):
            h = lines.pop(0)
            if h.startswith("#inputs:"): inputs = h[8:].strip().split("|")
            else: files = json.loads(h[7:])
        progs.append({"code": "\n".join(lines), "inputs": inputs, "files": files})
    tmp = tempfile.mkdtemp()
    pin, pout = os.path.join(tmp, "in.json"), os.path.join(tmp, "out.json")
    json.dump(progs, open(pin, "w"))
    root = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
    subprocess.run(["godot", "--headless", "--path", root, "-s", "tools/py_diff_runner.gd", "--", pin, pout], capture_output=True)
    got = json.load(open(pout))
    bad = 0
    for p, g in zip(progs, got):
        exp_out, exp_err = run_python(p["code"], p["inputs"], p["files"])
        if g["output"] != exp_out or g["error"] != exp_err:
            bad += 1
            print("=" * 60); print(p["code"])
            print("--- python:", repr(exp_out), exp_err)
            print("--- pyeval:", repr(g["output"]), g["error"], g["message"])
    print(f"{len(progs) - bad}/{len(progs)} iguales")
    sys.exit(1 if bad else 0)

main()
