# utils.py
import os
import shutil
import tempfile
import subprocess
from pathlib import Path
import json

# Prefer tree_sitter if available
TREE_SITTER_AVAILABLE = False
try:
    from tree_sitter import Language, Parser
    TREE_SITTER_AVAILABLE = True
except Exception:
    TREE_SITTER_AVAILABLE = False

import ast

def clone_repo(url: str) -> str:
    import os, subprocess, tempfile, shutil
    base_dir = os.path.join(os.getcwd(), "tmp_repos")
    os.makedirs(base_dir, exist_ok=True)
    tmp = tempfile.mkdtemp(prefix="codegen_", dir=base_dir)
    cmd = ["/usr/bin/git", "clone", "--depth", "1", url, tmp]
    print(f"[INFO] Cloning into {tmp}")
    try:
        subprocess.check_call(cmd)
    except Exception as e:
        shutil.rmtree(tmp, ignore_errors=True)
        raise RuntimeError(f"Failed to clone {url}: {e}")
    return tmp


def walk_tree(local_path: str) -> list:
    out = []
    ignore = {".git", "node_modules", "__pycache__", ".venv", "venv"}
    for root, dirs, files in os.walk(local_path):
        dirs[:] = [d for d in dirs if d not in ignore]
        for f in files:
            full = os.path.join(root, f)
            try:
                size = os.path.getsize(full)
                if size > 300_000:
                    content = ""
                else:
                    with open(full, "r", encoding="utf-8", errors="ignore") as fh:
                        content = fh.read()
            except Exception:
                content = ""
            rel = os.path.relpath(full, local_path)
            out.append({"path": full, "relpath": rel, "name": f, "content": content})
    return out

# AST based Python parser fallback
class PythonAnalyzer(ast.NodeVisitor):
    def __init__(self):
        self.functions = []
        self.classes = []
        self.calls = []  # list of (caller, callee) strings
        self.current_function = None
        self.current_class = None

    def visit_FunctionDef(self, node):
        name = node.name
        qualname = name
        if self.current_class:
            qualname = f"{self.current_class}.{name}"
        self.functions.append({
            "name": qualname,
            "lineno": node.lineno,
            "args": [a.arg for a in node.args.args]
        })
        prev = self.current_function
        self.current_function = qualname
        self.generic_visit(node)
        self.current_function = prev

    def visit_ClassDef(self, node):
        name = node.name
        self.classes.append({
            "name": name,
            "lineno": node.lineno,
            "bases": [getattr(b, 'id', getattr(b, 'attr', None)) for b in node.bases]
        })
        prev_class = self.current_class
        self.current_class = name
        self.generic_visit(node)
        self.current_class = prev_class

    def visit_Call(self, node):
        # Get function name if possible
        func = node.func
        fname = None
        if isinstance(func, ast.Name):
            fname = func.id
        elif isinstance(func, ast.Attribute):
            # e.g., module.func or self.func
            attr = []
            cur = func
            while isinstance(cur, ast.Attribute):
                attr.append(cur.attr)
                cur = cur.value
            if isinstance(cur, ast.Name):
                attr.append(cur.id)
            fname = ".".join(reversed(attr))
        if fname and self.current_function:
            self.calls.append({"caller": self.current_function, "callee": fname})
        self.generic_visit(node)

def parse_python_source(content: str):
    analyzer = PythonAnalyzer()
    try:
        tree = ast.parse(content)
        analyzer.visit(tree)
    except Exception:
        # parsing failed, return empty structure
        pass
    return {
        "functions": analyzer.functions,
        "classes": analyzer.classes,
        "calls": analyzer.calls
    }

def parse_files_with_ccg(file_list: list) -> dict:
    """
    For each file in file_list, try to parse with tree-sitter if available,
    otherwise use AST fallback for python files. Build a lightweight CCG:
    {
      "modules": {
         "<relpath>": {
             "functions": [...],
             "classes": [...],
             "calls": [...]
         }, ...
      },
      "call_edges": [ ["module::func", "module2::func2"], ...]
    }
    """
    modules = {}
    call_edges = []

    for f in file_list:
        rel = f.get("relpath")
        content = f.get("content", "")
        ext = os.path.splitext(f.get("name", ""))[1].lower()

        parsed = {"functions": [], "classes": [], "calls": []}
        if ext in {".py"}:
            parsed = parse_python_source(content)
        else:
            # For non-Python, naive fallback: pick lines with keywords
            funcs = []
            classes = []
            for line in content.splitlines():
                s = line.strip()
                if s.startswith("def "):
                    funcs.append({"name": s[4:].split("(")[0]})
                if s.startswith("class "):
                    classes.append({"name": s[6:].split("(")[0].split(":")[0]})
            parsed["functions"] = funcs
            parsed["classes"] = classes
            parsed["calls"] = []

        # Normalize names for edges
        for c in parsed.get("calls", []):
            caller = c.get("caller")
            callee = c.get("callee")
            if caller and callee:
                call_edges.append([f"{rel}::{caller}", f"{rel}::{callee}"])

        modules[rel] = parsed

    # Identify hotspots (most referenced functions/classes)
    degree = {}
    for a, b in call_edges:
        degree[a] = degree.get(a, 0) + 1
        degree[b] = degree.get(b, 0) + 1
    hotspots = sorted(degree.items(), key=lambda x: -x[1])[:10]

    ccg = {
        "modules": modules,
        "call_edges": call_edges,
        "hotspots": [h[0] for h in hotspots]
    }
    return ccg

def write_output(repo_name, md):
    # Replace invalid path characters
    safe_name = repo_name.replace(":", "_").replace("/", "_")
    output_dir = os.path.join("outputs", safe_name)
    os.makedirs(output_dir, exist_ok=True)
    output_path = os.path.join(output_dir, "docs.md")

    with open(output_path, "w", encoding="utf-8") as f:
        f.write(md)

    print(f"[✔] Documentation written to: {output_path}")
    return output_path
