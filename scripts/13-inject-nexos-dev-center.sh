#!/usr/bin/env bash
# Injects NexOS Dev Center into the live ISO.
# Goal: make NexOS closer to the original plan with built-in editor/compiler/project tools.

set -Eeuo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib/common.sh
source "$SCRIPT_DIR/lib/common.sh"

NEXOS_EDITION="${NEXOS_EDITION:-main}"
EDITION_LABEL="${EDITION_LABEL:-NexOS Main}"

ensure_dir "$LB_CONFIG_DIR/hooks/normal"
ensure_dir "$LB_CONFIG_DIR/package-lists"

cat > "$LB_CONFIG_DIR/package-lists/47-nexos-dev-center-tools.list.chroot" <<'PKGS'
# NexOS Dev Center dependencies.
git
make
cmake
ninja-build
gcc
g++
gdb
pkg-config
shellcheck
python3
python3-venv
python3-pip
PKGS

cat > "$LB_CONFIG_DIR/hooks/normal/070-nexos-dev-center.hook.chroot" <<'HOOK'
#!/usr/bin/env bash
set -euo pipefail
export DEBIAN_FRONTEND=noninteractive

LIVE_USERNAME="__LIVE_USERNAME__"
NEXOS_EDITION="__NEXOS_EDITION__"
EDITION_LABEL="__EDITION_LABEL__"
home_dir="/home/$LIVE_USERNAME"

install_if_available() {
  local pkg="$1"
  if apt-cache show "$pkg" >/dev/null 2>&1; then
    apt-get install -y --no-install-recommends "$pkg" || true
  fi
}

apt-get update || true
for pkg in git make cmake ninja-build gcc g++ gdb pkg-config shellcheck python3 python3-venv python3-pip; do
  install_if_available "$pkg"
done

mkdir -p /usr/local/bin /usr/share/applications /usr/share/nexos "$home_dir/Desktop" "$home_dir/Projects/NexOS"

cat > /usr/local/bin/nexos-compiler-check <<'CHECK'
#!/usr/bin/env bash
set -euo pipefail
report="/tmp/nexos-compiler-check-$(date +%s).txt"
{
  echo "NexOS Compiler Check"
  echo "===================="
  date
  echo
  for cmd in gcc g++ make cmake ninja gdb git python3 pip3 shellcheck; do
    if command -v "$cmd" >/dev/null 2>&1; then
      printf '%-12s %s\n' "$cmd" "$(command -v "$cmd")"
      "$cmd" --version 2>/dev/null | head -n 1 || true
    else
      printf '%-12s missing\n' "$cmd"
    fi
    echo
  done
} > "$report" 2>&1
if command -v mousepad >/dev/null 2>&1; then mousepad "$report" >/dev/null 2>&1 & else xdg-open "$report" >/dev/null 2>&1 & fi
CHECK
chmod 0755 /usr/local/bin/nexos-compiler-check

cat > /usr/local/bin/nexos-dev-center <<'DEVCENTER'
#!/usr/bin/env bash
set -euo pipefail
projects_dir="$HOME/Projects/NexOS"
mkdir -p "$projects_dir"

safe_name() {
  echo "$1" | tr '[:upper:]' '[:lower:]' | sed 's/[^a-z0-9_-]/-/g; s/--*/-/g; s/^-//; s/-$//'
}

open_project() {
  local dir="$1"
  if command -v geany >/dev/null 2>&1; then geany "$dir" >/dev/null 2>&1 &
  elif command -v kate >/dev/null 2>&1; then kate "$dir" >/dev/null 2>&1 &
  else xfce4-terminal --working-directory="$dir" >/dev/null 2>&1 & fi
}

create_project() {
  local kind="$1" raw name dir
  raw="$(zenity --entry --title="NexOS Dev Center" --text="Project name:" --entry-text="my-nexos-project" || true)"
  [[ -n "$raw" ]] || return 0
  name="$(safe_name "$raw")"
  [[ -n "$name" ]] || name="nexos-project"
  dir="$projects_dir/$name"
  if [[ -e "$dir" ]]; then zenity --error --title="NexOS Dev Center" --text="Project already exists:\n$dir" || true; return 1; fi
  mkdir -p "$dir"
  case "$kind" in
    "C Project")
      cat > "$dir/main.c" <<'EOF'
#include <stdio.h>
int main(void) { printf("Hello from NexOS C project!\n"); return 0; }
EOF
      cat > "$dir/Makefile" <<'EOF'
APP := app
CC := gcc
CFLAGS := -Wall -Wextra -O2
all: $(APP)
$(APP): main.c
	$(CC) $(CFLAGS) main.c -o $(APP)
run: all
	./$(APP)
clean:
	rm -f $(APP)
EOF
      ;;
    "C++ Project")
      cat > "$dir/main.cpp" <<'EOF'
#include <iostream>
int main() { std::cout << "Hello from NexOS C++ project!" << std::endl; return 0; }
EOF
      cat > "$dir/Makefile" <<'EOF'
APP := app
CXX := g++
CXXFLAGS := -Wall -Wextra -O2 -std=c++17
all: $(APP)
$(APP): main.cpp
	$(CXX) $(CXXFLAGS) main.cpp -o $(APP)
run: all
	./$(APP)
clean:
	rm -f $(APP)
EOF
      ;;
    "Python Project")
      cat > "$dir/main.py" <<'EOF'
#!/usr/bin/env python3
print("Hello from NexOS Python project!")
EOF
      chmod +x "$dir/main.py"
      ;;
    "Bash Script")
      cat > "$dir/script.sh" <<'EOF'
#!/usr/bin/env bash
set -Eeuo pipefail
echo "Hello from a NexOS bash script!"
EOF
      chmod +x "$dir/script.sh"
      ;;
    "Web Starter")
      cat > "$dir/index.html" <<'EOF'
<!doctype html><html><head><meta charset="utf-8"><title>NexOS Web Starter</title>
<style>body{font-family:system-ui;background:#101827;color:#e5f8ff;display:grid;place-items:center;min-height:100vh}main{background:#18243a;padding:32px;border-radius:24px;max-width:720px}</style></head>
<body><main><h1>NexOS Web Starter</h1><p>Edit this page and open it in NexOS Browser.</p><button onclick="alert('Hello from NexOS!')">Test</button></main></body></html>
EOF
      ;;
  esac
  cat > "$dir/README.md" <<EOF
# $name

Created with NexOS Dev Center.

Use NexOS Dev Center to build/check this project.
EOF
  zenity --question --title="NexOS Dev Center" --text="Project created:\n$dir\n\nOpen it now?" && open_project "$dir" || true
}

build_project() {
  local dir log
  dir="$(zenity --file-selection --directory --title="NexOS Dev Center - Choose project folder" --filename="$projects_dir/" || true)"
  [[ -n "$dir" ]] || return 0
  log="/tmp/nexos-dev-build-$(date +%s).log"
  {
    echo "NexOS Dev Center Build/Check"
    echo "Project: $dir"
    echo
    cd "$dir"
    if [[ -f Makefile ]]; then make
    elif [[ -f CMakeLists.txt ]]; then cmake -S . -B build -G Ninja || cmake -S . -B build; cmake --build build
    elif [[ -f main.py ]]; then python3 -m py_compile main.py; echo "Python syntax check passed."
    elif [[ -f script.sh ]]; then command -v shellcheck >/dev/null 2>&1 && shellcheck script.sh || true; bash -n script.sh; echo "Bash syntax check passed."
    elif [[ -f index.html ]]; then echo "Web project found: index.html"; command -v nexos-browser >/dev/null 2>&1 && nexos-browser "file://$dir/index.html" || true
    else echo "No supported project files found."; exit 2
    fi
  } > "$log" 2>&1 && zenity --text-info --title="NexOS Dev Center - Complete" --width=820 --height=520 --filename="$log" || zenity --text-info --title="NexOS Dev Center - Failed" --width=820 --height=520 --filename="$log" || true
}

while true; do
  choice="$(zenity --list --title="NexOS Dev Center" --width=760 --height=500 --print-column=1 --column="Action" --column="Description" \
    "C Project" "Create a GCC C starter" \
    "C++ Project" "Create a G++ starter" \
    "Python Project" "Create a Python starter" \
    "Bash Script" "Create a Bash starter" \
    "Web Starter" "Create an HTML/CSS/JS starter" \
    "Build/Check Project" "Build or syntax-check project" \
    "Compiler Check" "Show installed compiler tools" \
    "Open Projects Folder" "Open ~/Projects/NexOS" \
    "Exit" "Close Dev Center" || true)"
  [[ -n "$choice" ]] || exit 0
  case "$choice" in
    "C Project"|"C++ Project"|"Python Project"|"Bash Script"|"Web Starter") create_project "$choice" ;;
    "Build/Check Project") build_project ;;
    "Compiler Check") nexos-compiler-check ;;
    "Open Projects Folder") xdg-open "$projects_dir" >/dev/null 2>&1 & ;;
    "Exit") exit 0 ;;
  esac
done
DEVCENTER
chmod 0755 /usr/local/bin/nexos-dev-center

make_desktop() {
  local path="$1" name="$2" comment="$3" exec_cmd="$4" icon="$5" cats="$6"
  cat > "$path" <<DESKTOP
[Desktop Entry]
Type=Application
Name=$name
Comment=$comment
Exec=$exec_cmd
Icon=$icon
Terminal=false
Categories=$cats
DESKTOP
}

make_desktop /usr/share/applications/nexos-dev-center.desktop "NexOS Dev Center" "Create and build starter projects" "nexos-dev-center" "applications-development" "Development;"
make_desktop /usr/share/applications/nexos-compiler-check.desktop "NexOS Compiler Check" "Check compiler and developer tools" "nexos-compiler-check" "utilities-terminal" "Development;System;"

cp -f /usr/share/applications/nexos-dev-center.desktop "$home_dir/Desktop/NexOS Dev Center.desktop" || true
cp -f /usr/share/applications/nexos-compiler-check.desktop "$home_dir/Desktop/NexOS Compiler Check.desktop" || true
chmod 0755 "$home_dir/Desktop/NexOS Dev Center.desktop" "$home_dir/Desktop/NexOS Compiler Check.desktop" 2>/dev/null || true

cat >> /usr/share/nexos/app-map.txt <<'APPMAP_APPEND'

Developer helpers:
- NexOS Dev Center: creates starter C, C++, Python, Bash, and Web projects.
- NexOS Compiler Check: checks GCC, G++, Make, CMake, Ninja, GDB, Python, Git, and ShellCheck availability.
APPMAP_APPEND

chown -R "$LIVE_USERNAME:$LIVE_USERNAME" "$home_dir" 2>/dev/null || true
mkdir -p /etc/skel
rsync -a "$home_dir/" /etc/skel/ 2>/dev/null || true
HOOK

sed -i \
  -e "s/__LIVE_USERNAME__/$LIVE_USERNAME/g" \
  -e "s/__NEXOS_EDITION__/$NEXOS_EDITION/g" \
  -e "s/__EDITION_LABEL__/$EDITION_LABEL/g" \
  "$LB_CONFIG_DIR/hooks/normal/070-nexos-dev-center.hook.chroot"
chmod 0755 "$LB_CONFIG_DIR/hooks/normal/070-nexos-dev-center.hook.chroot"

success "Injected NexOS Dev Center for $NEXOS_EDITION."
