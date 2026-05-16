#!/usr/bin/env bash
# Injects the built-in NexOS AI Assistant into the live OS.
# Real local assistant app: startup service, corner orb, dashboard, local API,
# command router, skills, permissions, history, safe app controls, and TTS.

set -Eeuo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib/common.sh
source "$SCRIPT_DIR/lib/common.sh"

NEXOS_EDITION="${NEXOS_EDITION:-main}"
EDITION_LABEL="${EDITION_LABEL:-NexOS Main}"

ensure_dir "$LB_CONFIG_DIR/hooks/normal"
ensure_dir "$LB_CONFIG_DIR/package-lists"

cat > "$LB_CONFIG_DIR/package-lists/54-nexos-ai-assistant.list.chroot" <<'PKGS'
# NexOS AI Assistant runtime.
python3
python3-tk
espeak-ng
xdg-utils
wmctrl
x11-xserver-utils
PKGS

cat > "$LB_CONFIG_DIR/hooks/normal/140-nexos-ai-assistant.hook.chroot" <<'HOOK'
#!/usr/bin/env bash
set -euo pipefail
export DEBIAN_FRONTEND=noninteractive

LIVE_USERNAME="__LIVE_USERNAME__"
EDITION_LABEL="__EDITION_LABEL__"
home_dir="/home/$LIVE_USERNAME"
app_dir="/opt/nexos/NexOS_AI_Assistant"

install_if_available() {
  local pkg="$1"
  if apt-cache show "$pkg" >/dev/null 2>&1; then
    apt-get install -y --no-install-recommends "$pkg" || true
  fi
}

apt-get update || true
for pkg in python3 python3-tk espeak-ng xdg-utils wmctrl x11-xserver-utils; do
  install_if_available "$pkg"
done

mkdir -p \
  "$app_dir" \
  "$app_dir/services/command-router" \
  "$app_dir/services/native-wake-daemon" \
  "$app_dir/skills" \
  "$app_dir/integration" \
  "$app_dir/docs" \
  "$app_dir/assets" \
  /usr/local/bin \
  /usr/share/applications \
  /usr/share/icons/hicolor/scalable/apps \
  "$home_dir/Desktop" \
  "$home_dir/.config/autostart" \
  "$home_dir/.config/xfce4/xfconf/xfce-perchannel-xml"

cat > /usr/share/icons/hicolor/scalable/apps/nexos-ai-assistant.svg <<'SVG'
<svg xmlns="http://www.w3.org/2000/svg" width="128" height="128" viewBox="0 0 128 128">
  <defs>
    <radialGradient id="orb" cx="40%" cy="30%" r="70%">
      <stop offset="0" stop-color="#dff7ff"/>
      <stop offset="0.35" stop-color="#38bdf8"/>
      <stop offset="1" stop-color="#312e81"/>
    </radialGradient>
    <filter id="glow"><feGaussianBlur stdDeviation="5" result="b"/><feMerge><feMergeNode in="b"/><feMergeNode in="SourceGraphic"/></feMerge></filter>
  </defs>
  <rect x="7" y="7" width="114" height="114" rx="30" fill="#020617" stroke="#38bdf8" stroke-width="3"/>
  <circle cx="64" cy="64" r="35" fill="url(#orb)" filter="url(#glow)"/>
  <path d="M45 82V45h12l18 24V45h10v37H73L55 58v24z" fill="#eff6ff"/>
</svg>
SVG

cat > "$app_dir/integration/permissions.json" <<'JSON'
{
  "version": 1,
  "mode": "safe",
  "allowed_intents": [
    "assistant.chat",
    "assistant.wake",
    "dashboard.open",
    "dashboard.hide",
    "dashboard.toggle",
    "system.status",
    "app.open",
    "task.add",
    "web.search"
  ],
  "allowed_apps": {
    "terminal": ["xfce4-terminal", "x-terminal-emulator"],
    "files": ["thunar", "xdg-open"],
    "browser": ["nexos-browser", "firefox-esr", "xdg-open"],
    "settings": ["xfce4-settings-manager"],
    "control center": ["nexos-control-center"],
    "dev center": ["nexos-dev-center"],
    "install center": ["nexos-install-center"],
    "assistant": ["nexos-assistant-toggle"],
    "calculator": ["galculator", "qalculate-gtk", "gnome-calculator"]
  },
  "blocked": ["rm", "mkfs", "shutdown", "reboot", "dd", "chmod -R 777 /", "sudo"]
}
JSON

cat > "$app_dir/skills/app-launcher.skill.json" <<'JSON'
{
  "id": "app-launcher",
  "name": "App Launcher",
  "description": "Safely opens whitelisted NexOS apps.",
  "intents": ["app.open"],
  "examples": ["Hey NexOS open terminal", "OK NexOS open files", "Hey Nexus open dev center"]
}
JSON
cat > "$app_dir/skills/system-control.skill.json" <<'JSON'
{
  "id": "system-control",
  "name": "System Control",
  "description": "Reads safe system status and opens NexOS settings.",
  "intents": ["system.status", "dashboard.open", "dashboard.toggle"],
  "examples": ["Hey NexOS system status", "Hey NexOS open dashboard"]
}
JSON
cat > "$app_dir/skills/productivity.skill.json" <<'JSON'
{
  "id": "productivity",
  "name": "Productivity",
  "description": "Creates local tasks and reminders inside the assistant runtime.",
  "intents": ["task.add"],
  "examples": ["Hey NexOS add task test the new ISO"]
}
JSON

cat > "$app_dir/nexos_assistant.py" <<'PY'
#!/usr/bin/env python3
from __future__ import annotations

import http.server
import json
import os
import platform
import queue
import re
import shutil
import socketserver
import subprocess
import sys
import threading
import time
import urllib.parse
from pathlib import Path
from typing import Any

try:
    import tkinter as tk
    from tkinter import ttk
except Exception as exc:
    print(f"NexOS Assistant requires python3-tk: {exc}", file=sys.stderr)
    raise

APP_DIR = Path(__file__).resolve().parent
USER_DIR = Path.home() / ".nexos-assistant"
USER_DIR.mkdir(parents=True, exist_ok=True)
SETTINGS_PATH = USER_DIR / "settings.json"
HISTORY_PATH = USER_DIR / "command_history.jsonl"
TASKS_PATH = USER_DIR / "tasks.json"
PERMISSIONS_PATH = APP_DIR / "integration" / "permissions.json"
SKILLS_DIR = APP_DIR / "skills"
HOST = "127.0.0.1"
PORT = int(os.environ.get("NEXOS_COMPANION_PORT", "4780"))
WAKE_PHRASES = ("hey nexos", "hey nexus", "ok nexos", "okay nexos")


def load_json(path: Path, default: Any) -> Any:
    try:
        return json.loads(path.read_text(encoding="utf-8"))
    except Exception:
        return default


def save_json(path: Path, data: Any) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(data, indent=2), encoding="utf-8")


def log_history(entry: dict[str, Any]) -> None:
    entry.setdefault("time", time.strftime("%Y-%m-%d %H:%M:%S"))
    with HISTORY_PATH.open("a", encoding="utf-8") as fh:
        fh.write(json.dumps(entry, ensure_ascii=False) + "\n")


def speak(text: str) -> None:
    settings = load_json(SETTINGS_PATH, {"voice": True})
    if not settings.get("voice", True):
        return
    for cmd in (["espeak-ng", text], ["spd-say", text]):
        if shutil.which(cmd[0]):
            try:
                subprocess.Popen(cmd, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
                return
            except Exception:
                pass


def strip_wake(text: str) -> str:
    lower = text.strip().lower()
    for phrase in WAKE_PHRASES:
        if lower.startswith(phrase):
            return text.strip()[len(phrase):].strip(" ,")
    return text.strip()


def detect_intent(text: str) -> dict[str, Any]:
    raw = text.strip()
    lower = strip_wake(raw).lower()
    if not lower:
        return {"ok": True, "intent": "assistant.wake", "text": raw, "message": "I am listening."}
    if lower in {"show dashboard", "open dashboard", "open assistant"}:
        return {"ok": True, "intent": "dashboard.open", "text": raw, "message": "Opening NexOS dashboard."}
    if lower in {"hide dashboard", "close dashboard"}:
        return {"ok": True, "intent": "dashboard.hide", "text": raw, "message": "Closing dashboard."}
    if lower in {"toggle dashboard", "toggle assistant"}:
        return {"ok": True, "intent": "dashboard.toggle", "text": raw, "message": "Toggling dashboard."}
    if "system status" in lower or lower == "status":
        return {"ok": True, "intent": "system.status", "text": raw, "message": "Checking system status."}
    if lower.startswith("open "):
        return {"ok": True, "intent": "app.open", "text": raw, "target": lower[5:].strip(), "message": f"Opening {lower[5:].strip()}."}
    if lower.startswith("add task "):
        return {"ok": True, "intent": "task.add", "text": raw, "target": raw.split(" ", 2)[-1], "message": "Task added."}
    if lower.startswith("search web ") or lower.startswith("search for "):
        target = re.sub(r"^(search web|search for)\s+", "", lower).strip()
        return {"ok": True, "intent": "web.search", "text": raw, "target": target, "message": f"Searching for {target}."}
    return {"ok": True, "intent": "assistant.chat", "text": raw, "message": "I heard you. Local AI chat brain is ready for model integration."}


class AssistantRuntime:
    def __init__(self) -> None:
        self.ui_queue: queue.Queue[dict[str, Any]] = queue.Queue()
        self.root = tk.Tk()
        self.root.withdraw()
        self.root.title("NexOS Assistant")
        self.root.configure(bg="#050816")
        self.dashboard_visible = False
        self.dashboard: tk.Toplevel | None = None
        self.status_var = tk.StringVar(value="Idle")
        self.chat_var = tk.StringVar(value="")
        self._build_orb()
        self._start_api()
        self.root.after(250, self._poll_queue)
        speak("NexOS online.")

    def _build_orb(self) -> None:
        self.orb = tk.Toplevel(self.root)
        self.orb.title("NexOS Orb")
        self.orb.overrideredirect(True)
        self.orb.attributes("-topmost", True)
        self.orb.configure(bg="#050816")
        size = 84
        sw = self.orb.winfo_screenwidth()
        sh = self.orb.winfo_screenheight()
        self.orb.geometry(f"{size}x{size}+{max(20, sw-size-24)}+{max(20, sh-size-86)}")
        canvas = tk.Canvas(self.orb, width=size, height=size, highlightthickness=0, bg="#050816")
        canvas.pack(fill="both", expand=True)
        canvas.create_oval(10, 10, size-10, size-10, fill="#0ea5e9", outline="#bae6fd", width=2)
        canvas.create_oval(23, 23, size-23, size-23, fill="#1e1b4b", outline="#38bdf8", width=2)
        canvas.create_text(size/2, size/2, text="N", fill="#e0f2fe", font=("Sans", 28, "bold"))
        canvas.bind("<Button-1>", lambda _e: self.toggle_dashboard())
        self.orb.bind("<Button-1>", lambda _e: self.toggle_dashboard())

    def _make_panel(self, parent: ttk.Notebook, title: str, text: str) -> None:
        frame = tk.Frame(parent, bg="#0b1020")
        parent.add(frame, text=title)
        lbl = tk.Label(frame, text=text, justify="left", anchor="nw", bg="#0b1020", fg="#dbeafe", font=("Sans", 12), padx=20, pady=20)
        lbl.pack(fill="both", expand=True)

    def _build_dashboard(self) -> None:
        if self.dashboard and self.dashboard.winfo_exists():
            return
        self.dashboard = tk.Toplevel(self.root)
        self.dashboard.title("NexOS Assistant Dashboard")
        self.dashboard.geometry("1180x760")
        self.dashboard.configure(bg="#050816")
        self.dashboard.protocol("WM_DELETE_WINDOW", self.hide_dashboard)
        top = tk.Frame(self.dashboard, bg="#050816", padx=18, pady=14)
        top.pack(fill="x")
        tk.Label(top, text="NexOS", bg="#050816", fg="#e0f2fe", font=("Sans", 30, "bold")).pack(side="left")
        tk.Label(top, textvariable=self.status_var, bg="#050816", fg="#7dd3fc", font=("Sans", 13)).pack(side="right")
        notebook = ttk.Notebook(self.dashboard)
        notebook.pack(fill="both", expand=True, padx=14, pady=10)
        chat = tk.Frame(notebook, bg="#0b1020")
        notebook.add(chat, text="AI Chat")
        self.chat_log = tk.Text(chat, bg="#020617", fg="#dbeafe", insertbackground="#38bdf8", relief="flat", height=20)
        self.chat_log.pack(fill="both", expand=True, padx=14, pady=14)
        bottom = tk.Frame(chat, bg="#0b1020")
        bottom.pack(fill="x", padx=14, pady=(0,14))
        entry = tk.Entry(bottom, textvariable=self.chat_var, bg="#111827", fg="#e5f2ff", insertbackground="#38bdf8", relief="flat", font=("Sans", 13))
        entry.pack(side="left", fill="x", expand=True, ipady=10)
        entry.bind("<Return>", lambda _e: self.submit_text())
        tk.Button(bottom, text="Send", command=self.submit_text, bg="#0ea5e9", fg="white", relief="flat", padx=18).pack(side="left", padx=8)
        tk.Button(bottom, text="Listen", command=lambda: self.handle_command("hey nexos"), bg="#312e81", fg="white", relief="flat", padx=18).pack(side="left")
        self._make_panel(notebook, "Voice", "Wake phrases: Hey NexOS, Hey Nexus, OK NexOS, Okay NexOS\nHotkeys wired at OS level: ALT+SPACE and CTRL+ALT+N.\nVoice output uses espeak-ng when available.")
        self._make_panel(notebook, "System", self.system_status())
        self._make_panel(notebook, "Tasks", "Local tasks are stored in ~/.nexos-assistant/tasks.json")
        self._make_panel(notebook, "Schedule", "Agenda integration placeholder for NexOS calendar services.")
        self._make_panel(notebook, "Notifications", "NexOS assistant notifications and command replies appear here.")
        self._make_panel(notebook, "Weather", "Weather skill is ready for a provider/API bridge.")
        self._make_panel(notebook, "Devices", "Connected device skill is ready for OS hardware bridges.")
        self._make_panel(notebook, "Command Center", "Try: open terminal, open files, open control center, system status, add task test ISO")
        self._make_panel(notebook, "App Launcher", "Safe apps: terminal, files, browser, settings, control center, dev center, install center, calculator")
        self._make_panel(notebook, "Settings", str(load_json(SETTINGS_PATH, {"voice": True, "wake": True})))
        self._make_panel(notebook, "Skills", "\n".join(p.name for p in SKILLS_DIR.glob("*.skill.json")) or "No skills found")
        self._make_panel(notebook, "History", HISTORY_PATH.read_text(encoding="utf-8")[-4000:] if HISTORY_PATH.exists() else "No command history yet.")

    def show_dashboard(self) -> None:
        self._build_dashboard()
        self.dashboard_visible = True
        assert self.dashboard is not None
        self.dashboard.deiconify()
        self.dashboard.lift()
        self.dashboard.focus_force()

    def hide_dashboard(self) -> None:
        self.dashboard_visible = False
        if self.dashboard:
            self.dashboard.withdraw()

    def toggle_dashboard(self) -> None:
        if self.dashboard_visible:
            self.hide_dashboard()
        else:
            self.show_dashboard()

    def submit_text(self) -> None:
        text = self.chat_var.get().strip()
        self.chat_var.set("")
        if text:
            self.handle_command(text)

    def append_chat(self, who: str, text: str) -> None:
        self._build_dashboard()
        self.chat_log.insert("end", f"{who}: {text}\n")
        self.chat_log.see("end")

    def system_status(self) -> str:
        disk = shutil.disk_usage(str(Path.home()))
        return "\n".join([
            f"OS: NexOS ({platform.system()} {platform.release()})",
            f"CPU cores: {os.cpu_count()}",
            f"Disk: {disk.used // (1024**3)}GB used / {disk.total // (1024**3)}GB total",
            f"User data: {USER_DIR}",
            f"Local API: http://{HOST}:{PORT}",
        ])

    def open_app(self, target: str) -> tuple[bool, str]:
        perms = load_json(PERMISSIONS_PATH, {})
        apps = perms.get("allowed_apps", {})
        key = target.lower().strip()
        candidates = apps.get(key) or apps.get(key.replace("nexos ", ""))
        if not candidates:
            return False, f"{target} is not in the NexOS safe app whitelist."
        for cmd in candidates:
            exe = cmd.split()[0]
            if shutil.which(exe):
                try:
                    subprocess.Popen(cmd.split(), stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
                    return True, f"Opening {target}."
                except Exception:
                    continue
        return False, f"No installed launcher found for {target}."

    def handle_command(self, text: str) -> dict[str, Any]:
        route = detect_intent(text)
        intent = route.get("intent")
        msg = route.get("message", "Done.")
        ok = True
        if intent == "dashboard.open":
            self.show_dashboard()
        elif intent == "dashboard.hide":
            self.hide_dashboard()
        elif intent == "dashboard.toggle":
            self.toggle_dashboard()
        elif intent == "system.status":
            msg = self.system_status()
            self.show_dashboard()
        elif intent == "app.open":
            ok, msg = self.open_app(route.get("target", ""))
        elif intent == "task.add":
            tasks = load_json(TASKS_PATH, [])
            tasks.append({"text": route.get("target", text), "done": False, "created": time.strftime("%Y-%m-%d %H:%M:%S")})
            save_json(TASKS_PATH, tasks)
        elif intent == "web.search":
            q = urllib.parse.quote_plus(route.get("target", text))
            subprocess.Popen(["xdg-open", f"https://www.google.com/search?q={q}"], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
        elif intent == "assistant.wake":
            self.show_dashboard()
        result = {"ok": ok, "intent": intent, "message": msg, "route": route}
        log_history({"input": text, "result": result})
        self.status_var.set(msg.split("\n", 1)[0][:120])
        self.append_chat("You", text)
        self.append_chat("NexOS", msg)
        speak(msg.split("\n", 1)[0])
        return result

    def _start_api(self) -> None:
        runtime = self
        class Handler(http.server.BaseHTTPRequestHandler):
            def _send(self, data: Any, status: int = 200) -> None:
                body = json.dumps(data).encode("utf-8")
                self.send_response(status)
                self.send_header("Content-Type", "application/json")
                self.send_header("Content-Length", str(len(body)))
                self.end_headers()
                self.wfile.write(body)
            def do_GET(self) -> None:
                if self.path == "/health": self._send({"ok": True, "app": "NexOS Assistant"}); return
                if self.path == "/skills": self._send([load_json(p, {}) for p in SKILLS_DIR.glob("*.skill.json")]); return
                if self.path == "/settings": self._send(load_json(SETTINGS_PATH, {"voice": True, "wake": True})); return
                if self.path == "/history": self._send({"path": str(HISTORY_PATH), "tail": HISTORY_PATH.read_text(encoding="utf-8")[-5000:] if HISTORY_PATH.exists() else ""}); return
                self._send({"ok": False, "error": "not found"}, 404)
            def do_POST(self) -> None:
                length = int(self.headers.get("Content-Length", "0"))
                payload = json.loads(self.rfile.read(length).decode("utf-8") or "{}")
                if self.path in {"/command-router", "/command"}:
                    text = payload.get("text") or payload.get("command") or payload.get("raw") or ""
                    runtime.ui_queue.put({"type": "command", "text": text})
                    self._send({"ok": True, "message": "Command queued.", "text": text})
                    return
                if self.path == "/dashboard/toggle": runtime.ui_queue.put({"type": "toggle"}); self._send({"ok": True}); return
                if self.path == "/dashboard/open": runtime.ui_queue.put({"type": "open"}); self._send({"ok": True}); return
                if self.path == "/settings": save_json(SETTINGS_PATH, payload); self._send({"ok": True, "settings": payload}); return
                self._send({"ok": False, "error": "not found"}, 404)
            def log_message(self, *_args: Any) -> None: return
        def serve() -> None:
            with socketserver.ThreadingTCPServer((HOST, PORT), Handler) as httpd:
                httpd.allow_reuse_address = True
                httpd.serve_forever()
        threading.Thread(target=serve, daemon=True).start()

    def _poll_queue(self) -> None:
        try:
            while True:
                item = self.ui_queue.get_nowait()
                if item["type"] == "command": self.handle_command(item.get("text", ""))
                elif item["type"] == "toggle": self.toggle_dashboard()
                elif item["type"] == "open": self.show_dashboard()
        except queue.Empty:
            pass
        self.root.after(200, self._poll_queue)

    def run(self) -> None:
        self.root.mainloop()

if __name__ == "__main__":
    AssistantRuntime().run()
PY
chmod 0755 "$app_dir/nexos_assistant.py"

cat > "$app_dir/services/command-router/nexos_command_router.py" <<'PY'
#!/usr/bin/env python3
from __future__ import annotations
import argparse, json, os, re, sys, urllib.request
API=os.environ.get('NEXOS_COMPANION_API','http://127.0.0.1:4780')
def strip(t): return re.sub(r'^(hey|ok|okay|hi)\s+nex(os|us)[,\s]*','',t.strip(),flags=re.I).strip()
def main():
    p=argparse.ArgumentParser(); p.add_argument('command', nargs='*'); p.add_argument('--json', action='store_true'); args=p.parse_args()
    text=' '.join(args.command).strip() or sys.stdin.read().strip(); body=json.dumps({'text':text}).encode()
    try:
        req=urllib.request.Request(API.rstrip()+'/command-router',data=body,headers={'Content-Type':'application/json'},method='POST')
        out=json.loads(urllib.request.urlopen(req,timeout=5).read().decode())
    except Exception as e: out={'ok':False,'error':str(e),'text':text}
    print(json.dumps(out,indent=2) if args.json else out.get('message', json.dumps(out)))
    return 0 if out.get('ok') else 2
if __name__=='__main__': raise SystemExit(main())
PY
chmod 0755 "$app_dir/services/command-router/nexos_command_router.py"

cat > "$app_dir/services/native-wake-daemon/nexos_wake_daemon.py" <<'PY'
#!/usr/bin/env python3
from __future__ import annotations
import argparse, json, os, sys, urllib.request
API=os.environ.get('NEXOS_COMPANION_API','http://127.0.0.1:4780')
WAKE=('hey nexos','hey nexus','ok nexos','okay nexos')
def post(text):
    req=urllib.request.Request(API.rstrip()+'/command-router',data=json.dumps({'text':text}).encode(),headers={'Content-Type':'application/json'},method='POST')
    return urllib.request.urlopen(req,timeout=5).read().decode()
def main():
    p=argparse.ArgumentParser(); p.add_argument('--stdin', action='store_true'); args=p.parse_args()
    print('NexOS wake daemon ready. Type wake commands here for testing.')
    for line in sys.stdin:
        text=line.strip()
        if text.lower().startswith(WAKE):
            try: print(post(text))
            except Exception as e: print('wake route failed:', e)
    return 0
if __name__=='__main__': raise SystemExit(main())
PY
chmod 0755 "$app_dir/services/native-wake-daemon/nexos_wake_daemon.py"

cat > /usr/local/bin/nexos-assistant <<EOF
#!/usr/bin/env bash
exec python3 "$app_dir/nexos_assistant.py" "\$@"
EOF
chmod 0755 /usr/local/bin/nexos-assistant
cat > /usr/local/bin/nexos-assistant-toggle <<'EOF'
#!/usr/bin/env bash
python3 - <<'PY'
import json, urllib.request
try:
    req=urllib.request.Request('http://127.0.0.1:4780/dashboard/toggle', data=b'{}', headers={'Content-Type':'application/json'}, method='POST')
    print(urllib.request.urlopen(req, timeout=2).read().decode())
except Exception:
    import subprocess
    subprocess.Popen(['nexos-assistant'])
PY
EOF
chmod 0755 /usr/local/bin/nexos-assistant-toggle
cat > /usr/local/bin/nexos-assistant-wake <<'EOF'
#!/usr/bin/env bash
python3 - <<'PY'
import json, urllib.request, subprocess
try:
    req=urllib.request.Request('http://127.0.0.1:4780/command-router', data=json.dumps({'text':'hey nexos'}).encode(), headers={'Content-Type':'application/json'}, method='POST')
    print(urllib.request.urlopen(req, timeout=2).read().decode())
except Exception:
    subprocess.Popen(['nexos-assistant'])
PY
EOF
chmod 0755 /usr/local/bin/nexos-assistant-wake
cat > /usr/local/bin/nexos-command-router <<EOF
#!/usr/bin/env bash
exec python3 "$app_dir/services/command-router/nexos_command_router.py" "\$@"
EOF
chmod 0755 /usr/local/bin/nexos-command-router
cat > /usr/local/bin/nexos-wake-daemon <<EOF
#!/usr/bin/env bash
exec python3 "$app_dir/services/native-wake-daemon/nexos_wake_daemon.py" "\$@"
EOF
chmod 0755 /usr/local/bin/nexos-wake-daemon

cat > /usr/share/applications/nexos-assistant.desktop <<'DESKTOP'
[Desktop Entry]
Version=1.0
Type=Application
Name=NexOS Assistant
Comment=Jarvis-style NexOS desktop assistant with orb and dashboard
Exec=nexos-assistant
Icon=/usr/share/icons/hicolor/scalable/apps/nexos-ai-assistant.svg
Terminal=false
StartupNotify=false
Categories=Utility;System;
X-XFCE-Trusted=true
DESKTOP
chmod 0755 /usr/share/applications/nexos-assistant.desktop
cp -f /usr/share/applications/nexos-assistant.desktop "$home_dir/Desktop/NexOS Assistant.desktop" || true
chmod 0755 "$home_dir/Desktop/NexOS Assistant.desktop" 2>/dev/null || true

cat > "$home_dir/.config/autostart/nexos-assistant.desktop" <<'DESKTOP'
[Desktop Entry]
Type=Application
Name=NexOS Assistant
Comment=Start NexOS AI assistant orb and local API
Exec=sh -c 'sleep 5; nexos-assistant'
Icon=/usr/share/icons/hicolor/scalable/apps/nexos-ai-assistant.svg
Terminal=false
X-GNOME-Autostart-enabled=true
DESKTOP

# XFCE global keyboard shortcuts for assistant wake/toggle.
cat > "$home_dir/.config/xfce4/xfconf/xfce-perchannel-xml/xfce4-keyboard-shortcuts.xml" <<'XML'
<?xml version="1.0" encoding="UTF-8"?>
<channel name="xfce4-keyboard-shortcuts" version="1.0">
  <property name="commands" type="empty">
    <property name="custom" type="empty">
      <property name="&lt;Alt&gt;space" type="string" value="nexos-assistant-wake"/>
      <property name="&lt;Primary&gt;&lt;Alt&gt;n" type="string" value="nexos-assistant-toggle"/>
    </property>
  </property>
</channel>
XML

cat > "$app_dir/docs/NEXOS_AI_ASSISTANT_OS_INTEGRATION.md" <<'MD'
# NexOS AI Assistant OS Integration

Installed commands:

- `nexos-assistant` starts the local orb/dashboard app.
- `nexos-assistant-toggle` toggles the dashboard through the local API.
- `nexos-assistant-wake` sends a wake command to the assistant.
- `nexos-command-router "hey nexos open terminal" --json` tests routing.
- `nexos-wake-daemon --stdin` tests wake phrase routing.

Runtime files:

- `~/.nexos-assistant/settings.json`
- `~/.nexos-assistant/tasks.json`
- `~/.nexos-assistant/command_history.jsonl`

Local API:

- `GET http://127.0.0.1:4780/health`
- `GET http://127.0.0.1:4780/skills`
- `GET http://127.0.0.1:4780/settings`
- `GET http://127.0.0.1:4780/history`
- `POST http://127.0.0.1:4780/command-router`
- `POST http://127.0.0.1:4780/dashboard/toggle`

Current voice behavior:

- Voice replies use `espeak-ng` when available.
- Wake phrase routing exists through the wake daemon and hotkeys.
- Full offline microphone wake-word detection should be wired later with a native Vosk/openWakeWord daemon.
MD

if command -v gtk-update-icon-cache >/dev/null 2>&1; then
  gtk-update-icon-cache -f /usr/share/icons/hicolor >/dev/null 2>&1 || true
fi

# Mark launchers trusted at build time and again at login when the UI final pass is present.
if command -v gio >/dev/null 2>&1; then
  gio set "$home_dir/Desktop/NexOS Assistant.desktop" metadata::trusted true 2>/dev/null || true
fi

cat >> /usr/share/nexos/app-map.txt <<'APPMAP_APPEND'

NexOS AI Assistant:
- Built-in local assistant app with always-on-top corner orb.
- Full dashboard UI with chat, voice state, system overview, tasks, command center, app launcher, settings, skills, and history.
- Local API on 127.0.0.1:4780.
- Safe command router with permission whitelist and skills JSON.
- Startup integration: ~/.config/autostart/nexos-assistant.desktop.
- Hotkeys: ALT+SPACE wakes NexOS, CTRL+ALT+N toggles dashboard.
APPMAP_APPEND

chown -R "$LIVE_USERNAME:$LIVE_USERNAME" "$home_dir" 2>/dev/null || true
mkdir -p /etc/skel
rsync -a "$home_dir/" /etc/skel/ 2>/dev/null || true
HOOK

sed -i \
  -e "s/__LIVE_USERNAME__/$LIVE_USERNAME/g" \
  -e "s/__EDITION_LABEL__/$EDITION_LABEL/g" \
  "$LB_CONFIG_DIR/hooks/normal/140-nexos-ai-assistant.hook.chroot"
chmod 0755 "$LB_CONFIG_DIR/hooks/normal/140-nexos-ai-assistant.hook.chroot"

success "Injected NexOS AI Assistant for $NEXOS_EDITION."
