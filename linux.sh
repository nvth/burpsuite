#!/usr/bin/env bash
set -euo pipefail

BURP_DRIVE_URL="https://drive.usercontent.google.com/download?id=1FL9-u9cWqho0h8f6sYie0uYras6AUCOK&export=download&authuser=0"
BURP_GITHUB_URL="https://github.com/nvth/burpsuite/releases/download/v2026.3.3/burpsuite_pro.jar"
BURP_URL="https://portswigger-cdn.net/burp/releases/download?product=pro&version=&type=jar"
BURP_URLS=("$BURP_DRIVE_URL" "$BURP_GITHUB_URL" "$BURP_URL")
JDK_URL="https://github.com/nvth/burpsuite/releases/download/v2024.7.4/jdk-21.0.9_linux-x64_bin.tar.gz"
LOADER_UBUNTU_URL="https://github.com/nvth/burpsuite/releases/download/v2026.3.3/core.jar"
ICON_URL="https://github.com/nvth/burpsuite/releases/download/v2024.7.4/burppro.ico"
SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$SCRIPT_DIR/burpsuite_nvth"
DATA_DIR="$ROOT_DIR/data"
BIN_DIR="$ROOT_DIR/bin"
JDK_DIR="$ROOT_DIR/jdk"

BURP_JAR="$DATA_DIR/burpsuite_pro.jar"
LOADER_UBUNTU="$DATA_DIR/core.jar"
ICON_PATH="$DATA_DIR/burppro.ico"
LAUNCHER="$BIN_DIR/burp"
JDK_TAR="$DATA_DIR/jdk-21.0.9_linux-x64_bin.tar.gz"
ENV_FILE="/etc/profile.d/burpsuite_nvth_java.sh"

echo "== Burp Suite Pro (Linux) Installer =="
echo "Root directory: $ROOT_DIR"
echo "Data directory: $DATA_DIR"
echo "Bin directory: $BIN_DIR"

if [[ $EUID -ne 0 ]]; then
  echo "This script must be run as root or with sudo."
  echo "Example: sudo bash $0"
  exit 1
fi

mkdir -p "$DATA_DIR" "$BIN_DIR"

curl_download_with_resume() {
  local dest="$1"
  local resume_mode="${2:-yes}"
  shift 2
  local attempt rc=0
  local -a curl_args=()

  for attempt in 1 2 3 4; do
    if [[ "$resume_mode" == "yes" && -s "$dest" ]]; then
      echo "Download interrupted. Resuming $dest (attempt $attempt/4)..." >&2
      curl_args=(-C - -o "$dest" "$@")
    elif [[ "$resume_mode" != "yes" && $attempt -gt 1 ]]; then
      rm -f -- "$dest"
      echo "Retrying download (attempt $attempt/4)..." >&2
      curl_args=(-o "$dest" "$@")
    else
      curl_args=(-o "$dest" "$@")
    fi

    if curl "${curl_args[@]}"; then
      return 0
    else
      rc=$?
    fi
    if [[ $attempt -lt 4 ]]; then
      sleep 2
    fi
  done

  return "$rc"
}

download_file() {
  local url="$1"
  local dest="$2"
  local label="$3"
  echo "Downloading $label..."
  if command -v curl >/dev/null 2>&1; then
    if ! curl_download_with_resume "$dest" yes -L --fail --show-error --progress-bar --connect-timeout 30 --speed-time 120 --speed-limit 1024 "$url"; then
      return 1
    fi
  elif command -v wget >/dev/null 2>&1; then
    if ! wget -c -O "$dest" "$url"; then
      return 1
    fi
  else
    echo "curl or wget not found. Please install one of them."
    return 1
  fi
  if [[ ! -s "$dest" ]]; then
    echo "Download failed or file is empty: $dest"
    return 1
  fi
}

validate_tar_gz() {
  local file="$1"
  if ! command -v tar >/dev/null 2>&1; then
    echo "tar not found. Please install tar and re-run."
    exit 1
  fi
  tar -tzf "$file" >/dev/null 2>&1
}

validate_jar() {
  local file="$1"
  if command -v unzip >/dev/null 2>&1; then
    unzip -t -qq "$file" >/dev/null 2>&1
    return $?
  fi
  if command -v zipinfo >/dev/null 2>&1; then
    zipinfo -t "$file" >/dev/null 2>&1
    return $?
  fi
  local jar_cmd=""
  if [[ -n "${JAVA_HOME:-}" && -x "$JAVA_HOME/bin/jar" ]]; then
    jar_cmd="$JAVA_HOME/bin/jar"
  elif command -v jar >/dev/null 2>&1; then
    jar_cmd="$(command -v jar)"
  fi
  if [[ -n "$jar_cmd" ]]; then
    "$jar_cmd" tf "$file" >/dev/null 2>&1
    return $?
  fi
  echo "No tool to validate JAR (unzip/zipinfo/jar). Please install unzip or a full JDK."
  return 2
}

is_jar_file() {
  local file="$1"
  [[ -s "$file" ]] && [[ "$(head -c 2 "$file" 2>/dev/null)" == "PK" ]]
}

download_google_drive() {
  local dest="$1"
  local page="${dest}.drive-page.$$"
  local result="${dest}.drive-result.$$"
  local cookies="${dest}.drive-cookies.$$"
  local form_data="${dest}.drive-form.$$"
  local response_url action method field value download_status has_id=0 has_export=0 has_confirm=0
  local -a form_args=()

  if ! response_url="$(curl -L --fail --progress-bar --show-error --connect-timeout 30 --speed-time 120 --speed-limit 1024 -c "$cookies" -o "$page" -w '%{url_effective}' "$BURP_DRIVE_URL")"; then
    rm -f -- "$page" "$result" "$cookies"
    return 1
  fi

  if is_jar_file "$page"; then
    mv -f -- "$page" "$dest"
    rm -f -- "$result" "$cookies" "$form_data"
    return 0
  fi

  if ! command -v python3 >/dev/null 2>&1; then
    echo "Python 3 is required to parse Google's Download anyway form."
    rm -f -- "$page" "$result" "$cookies" "$form_data"
    return 1
  fi

  if ! python3 - "$page" "$response_url" > "$form_data" <<'PY'
from html.parser import HTMLParser
import sys
from urllib.parse import urljoin

class DownloadFormParser(HTMLParser):
    def __init__(self):
        super().__init__(convert_charrefs=True)
        self.action = ""
        self.method = "GET"
        self.fields = []
        self.active = False
        self.found = False
        self.button = None

    def handle_starttag(self, tag, attrs):
        attrs = dict(attrs)
        if tag == "form" and not self.found and attrs.get("id") == "download-form":
            self.found = True
            self.active = True
            self.action = attrs.get("action", "")
            self.method = attrs.get("method", "GET").upper()
        elif self.active and tag == "input":
            name = attrs.get("name")
            input_type = attrs.get("type", "").lower()
            is_download_button = input_type == "submit" and (
                attrs.get("id") == "uc-download-link"
                or "download anyway" in attrs.get("value", "").lower()
            )
            if name and (input_type == "hidden" or is_download_button):
                self.fields.append((name, attrs.get("value", "")))
        elif self.active and tag == "button" and attrs.get("name"):
            self.button = [attrs.get("name"), attrs.get("value", ""), attrs.get("id", ""), ""]

    def handle_data(self, data):
        if self.button is not None:
            self.button[3] += data

    def handle_endtag(self, tag):
        if tag == "button" and self.button is not None:
            name, value, element_id, label = self.button
            if element_id == "uc-download-link" or "download anyway" in label.lower():
                self.fields.append((name, value or label.strip()))
            self.button = None
        elif tag == "form" and self.active:
            self.active = False

parser = DownloadFormParser()
with open(sys.argv[1], "r", encoding="utf-8", errors="replace") as page:
    parser.feed(page.read())
if not parser.found or not parser.action:
    raise SystemExit(1)
print(urljoin(sys.argv[2], parser.action))
print(parser.method)
for name, value in parser.fields:
    print(f"{name}\t{value}")
PY
  then
    rm -f -- "$page" "$result" "$cookies" "$form_data"
    return 1
  fi

  {
    IFS= read -r action || true
    IFS= read -r method || true
    while IFS=$'\t' read -r field value; do
      [[ -n "$field" ]] || continue
      form_args+=(--data-urlencode "$field=$value")
      [[ "$field" == "id" ]] && has_id=1
      [[ "$field" == "export" ]] && has_export=1
      [[ "$field" == "confirm" ]] && has_confirm=1
    done
  } < "$form_data"
  if [[ -z "$action" || $has_id -ne 1 || $has_export -ne 1 || $has_confirm -ne 1 ]]; then
    rm -f -- "$page" "$result" "$cookies" "$form_data"
    return 1
  fi

  echo "Submitting Google's current Download anyway form..."
  if [[ "$method" == "GET" ]]; then
    if curl_download_with_resume "$result" yes -L --fail --progress-bar --show-error --connect-timeout 30 --speed-time 120 --speed-limit 1024 -b "$cookies" -c "$cookies" -G "${form_args[@]}" "$action"; then
      download_status=0
    else
      download_status=$?
    fi
  elif [[ "$method" == "POST" ]]; then
    if curl_download_with_resume "$result" no -L --fail --progress-bar --show-error --connect-timeout 30 --speed-time 120 --speed-limit 1024 -b "$cookies" -c "$cookies" -X POST "${form_args[@]}" "$action"; then
      download_status=0
    else
      download_status=$?
    fi
  else
    rm -f -- "$page" "$result" "$cookies" "$form_data"
    return 1
  fi
  if [[ $download_status -eq 0 ]] && is_jar_file "$result"; then
    mv -f -- "$result" "$dest"
    rm -f -- "$page" "$cookies" "$form_data"
    return 0
  fi

  rm -f -- "$page" "$result" "$cookies" "$form_data"
  return 1
}

ensure_valid_jar() {
  local file="$1"
  local label="$2"
  shift 2
  if [[ -f "$file" ]]; then
    if validate_jar "$file"; then
      echo "$label already exists and is valid."
      return 0
    else
      local rc=$?
      if [[ $rc -eq 2 ]]; then
        exit 1
      fi
    fi
    echo "$label is invalid. Re-downloading..."
    rm -f -- "$file"
  fi

  local url rc downloaded
  for url in "$@"; do
    echo "Trying download URL: $url"
    if [[ "$url" == "$BURP_DRIVE_URL" ]]; then
      if download_google_drive "$file"; then downloaded=1; else downloaded=0; fi
    elif download_file "$url" "$file" "$label"; then
      downloaded=1
    else
      downloaded=0
    fi

    if [[ $downloaded -eq 1 ]]; then
      if validate_jar "$file"; then
        return 0
      else
        rc=$?
        if [[ $rc -eq 2 ]]; then
          rm -f -- "$file"
          exit 1
        fi
        echo "$label validation failed for this source. Trying the next source."
      fi
    else
      echo "Download failed from this source. Trying the next source."
    fi
    rm -f -- "$file"
  done

  echo "Unable to download a valid $label from any configured source."
  exit 1
}

get_java_major() {
  local java_cmd="${1:-}"
  if [[ -z "$java_cmd" ]]; then
    if [[ -n "${JAVA_HOME:-}" && -x "$JAVA_HOME/bin/java" ]]; then
      java_cmd="$JAVA_HOME/bin/java"
    elif command -v java >/dev/null 2>&1; then
      java_cmd="$(command -v java)"
    else
      return 1
    fi
  fi
  local line
  line="$("$java_cmd" -version 2>&1 | head -n 1)"
  if [[ $line =~ \"1\.([0-9]+) ]]; then
    echo "${BASH_REMATCH[1]}"
    return 0
  fi
  if [[ $line =~ \"([0-9]+)\. ]]; then
    echo "${BASH_REMATCH[1]}"
    return 0
  fi
  if [[ $line =~ \"([0-9]+)\" ]]; then
    echo "${BASH_REMATCH[1]}"
    return 0
  fi
  return 1
}

get_java_home_from_bin() {
  local java_cmd="$1"
  local resolved_java=""
  if command -v readlink >/dev/null 2>&1; then
    resolved_java="$(readlink -f -- "$java_cmd" 2>/dev/null || true)"
  fi
  if [[ -z "$resolved_java" ]] && command -v realpath >/dev/null 2>&1; then
    resolved_java="$(realpath -- "$java_cmd" 2>/dev/null || true)"
  fi
  [[ -n "$resolved_java" ]] || resolved_java="$java_cmd"
  dirname -- "$(dirname -- "$resolved_java")"
}

install_java21() {
  if [[ -f "$JDK_TAR" ]]; then
    echo "JDK archive already exists. Verifying..."
    if ! validate_tar_gz "$JDK_TAR"; then
      echo "JDK archive is invalid or incomplete. Re-downloading..."
      rm -f "$JDK_TAR"
      download_file "$JDK_URL" "$JDK_TAR" "OpenJDK 21"
    else
      echo "JDK archive looks OK."
    fi
  else
    download_file "$JDK_URL" "$JDK_TAR" "OpenJDK 21"
  fi

  echo "Installing OpenJDK 21..."
  local top_dir
  set +o pipefail
  top_dir="$(tar -tzf "$JDK_TAR" | head -n 1 | cut -d/ -f1)"
  local tar_status=$?
  set -o pipefail
  if [[ $tar_status -ne 0 ]]; then
    echo "Failed to read JDK archive. Please re-run the script to re-download."
    exit 1
  fi
  if [[ -z "$top_dir" || "$top_dir" == "." || "$top_dir" == ".." || "$top_dir" == */* ]]; then
    echo "JDK archive has an invalid top-level directory."
    exit 1
  fi

  local extract_dir="$DATA_DIR/jdk_extract"
  local extracted_jdk="$extract_dir/$top_dir"
  rm -rf -- "$extract_dir"
  mkdir -p "$extract_dir"
  tar -xzf "$JDK_TAR" -C "$extract_dir"

  if [[ ! -x "$extracted_jdk/bin/java" ]]; then
    echo "Java binary not found after extraction: $extracted_jdk/bin/java"
    rm -rf -- "$extract_dir"
    exit 1
  fi

  local extracted_major
  extracted_major="$(get_java_major "$extracted_jdk/bin/java" || true)"
  if [[ "$extracted_major" != "21" ]]; then
    echo "Downloaded JDK has Java major version $extracted_major; expected 21."
    rm -rf -- "$extract_dir"
    exit 1
  fi

  rm -rf -- "$JDK_DIR"
  mv -- "$extracted_jdk" "$JDK_DIR"
  rm -rf -- "$extract_dir"

  export JAVA_HOME="$JDK_DIR"
  export PATH="$JAVA_HOME/bin:$PATH"
}

JAVA_BIN="$JDK_DIR/bin/java"
JAVA_MAJOR="$(get_java_major "$JAVA_BIN" || true)"
if [[ "$JAVA_MAJOR" != "21" ]]; then
  SYSTEM_JAVA_BIN="$(command -v java 2>/dev/null || true)"
  SYSTEM_JAVA_MAJOR=""
  if [[ -n "$SYSTEM_JAVA_BIN" ]]; then
    SYSTEM_JAVA_MAJOR="$(get_java_major "$SYSTEM_JAVA_BIN" || true)"
  fi
  if [[ "$SYSTEM_JAVA_MAJOR" != "21" && -n "${JAVA_HOME:-}" && -x "$JAVA_HOME/bin/java" ]]; then
    SYSTEM_JAVA_BIN="$JAVA_HOME/bin/java"
    SYSTEM_JAVA_MAJOR="$(get_java_major "$SYSTEM_JAVA_BIN" || true)"
  fi
  if [[ "$SYSTEM_JAVA_MAJOR" == "21" ]]; then
    JAVA_BIN="$SYSTEM_JAVA_BIN"
    JAVA_MAJOR="$SYSTEM_JAVA_MAJOR"
    echo "Found Java 21 at $JAVA_BIN. Reusing it; no JDK download is needed."
  else
    echo "Java 21 was not found in the application folder or on the system. Installing it now."
    install_java21
    JAVA_BIN="$JDK_DIR/bin/java"
    JAVA_MAJOR="$(get_java_major "$JAVA_BIN" || true)"
  fi
fi
if [[ "$JAVA_MAJOR" != "21" ]]; then
  echo "Could not find or install a Java 21 runtime. Last checked: $JAVA_BIN."
  exit 1
fi
if [[ "$JAVA_BIN" == "$JDK_DIR/bin/java" ]]; then
  JAVA_HOME="$JDK_DIR"
else
  JAVA_HOME="$(get_java_home_from_bin "$JAVA_BIN")"
fi
export JAVA_HOME
export PATH="$JAVA_HOME/bin:$PATH"
cat > "$ENV_FILE" <<EOF
export JAVA_HOME="$JAVA_HOME"
export PATH="\$JAVA_HOME/bin:\$PATH"
EOF
chmod 644 "$ENV_FILE"
echo "JAVA_HOME set to $JAVA_HOME"
echo "Environment file created: $ENV_FILE"
echo "Using Java 21: $JAVA_BIN"

ensure_valid_jar "$BURP_JAR" "burpsuite_pro.jar" "${BURP_URLS[@]}"

if [[ -f "$SCRIPT_DIR/core.jar" && "$SCRIPT_DIR/core.jar" != "$LOADER_UBUNTU" ]]; then
  cp -f "$SCRIPT_DIR/core.jar" "$LOADER_UBUNTU"
fi
if [[ ! -f "$LOADER_UBUNTU" ]]; then
  echo "[INFO] Local core.jar not found. Downloading Core from GitHub release v2026.3.3."
fi
ensure_valid_jar "$LOADER_UBUNTU" "core.jar" "$LOADER_UBUNTU_URL"

if [[ ! -f "$ICON_PATH" ]]; then
  if [[ -f "$SCRIPT_DIR/burppro.ico" ]]; then
    cp -f "$SCRIPT_DIR/burppro.ico" "$ICON_PATH"
  else
    download_file "$ICON_URL" "$ICON_PATH" "burppro.ico"
  fi
fi

if [[ -f "$LOADER_UBUNTU" ]]; then
  echo "Using core.jar (data)"
  ACTIVE_LOADER="$LOADER_UBUNTU"
else
  echo "Core JAR not found. Please place core.jar in $SCRIPT_DIR."
  exit 1
fi

{
  printf '%s\n' '#!/usr/bin/env bash'
  printf 'CONFIGURED_JAVA_BIN=%q\n' "$JAVA_BIN"
  cat <<'EOF'
set -euo pipefail

SCRIPT_PATH="${BASH_SOURCE[0]}"
if command -v readlink >/dev/null 2>&1; then
  SCRIPT_PATH="$(readlink -f "$SCRIPT_PATH")"
elif command -v realpath >/dev/null 2>&1; then
  SCRIPT_PATH="$(realpath "$SCRIPT_PATH")"
fi
ROOT_DIR="$(cd -- "$(dirname -- "$SCRIPT_PATH")/.." && pwd)"
DATA_DIR="$ROOT_DIR/data"
JDK_DIR="$ROOT_DIR/jdk"
BURP_JAR="$DATA_DIR/burpsuite_pro.jar"

if [[ -f "$DATA_DIR/core.jar" ]]; then
  LOADER_JAR="$DATA_DIR/core.jar"
else
  echo "Core JAR not found in $DATA_DIR." >&2
  exit 1
fi

if [[ ! -f "$BURP_JAR" ]]; then
  echo "burpsuite_pro.jar not found in $DATA_DIR." >&2
  exit 1
fi

get_java_major() {
  local java_cmd="${1:-}"
  [[ -n "$java_cmd" && -x "$java_cmd" ]] || return 1
  local line
  line="$("$java_cmd" -version 2>&1 | head -n 1)"
  if [[ $line =~ \"1\.([0-9]+) ]]; then
    echo "${BASH_REMATCH[1]}"
    return 0
  fi
  if [[ $line =~ \"([0-9]+)\. ]]; then
    echo "${BASH_REMATCH[1]}"
    return 0
  fi
  if [[ $line =~ \"([0-9]+)\" ]]; then
    echo "${BASH_REMATCH[1]}"
    return 0
  fi
  return 1
}

JAVA_BIN="$JDK_DIR/bin/java"
JAVA_MAJOR="$(get_java_major "$JAVA_BIN" || true)"
if [[ "$JAVA_MAJOR" != "21" ]]; then
  SYSTEM_JAVA_BIN="$CONFIGURED_JAVA_BIN"
  JAVA_MAJOR="$(get_java_major "$SYSTEM_JAVA_BIN" || true)"
  if [[ "$JAVA_MAJOR" != "21" ]]; then
    SYSTEM_JAVA_BIN="$(command -v java 2>/dev/null || true)"
    JAVA_MAJOR="$(get_java_major "$SYSTEM_JAVA_BIN" || true)"
  fi
  if [[ "$JAVA_MAJOR" != "21" && -n "${JAVA_HOME:-}" && -x "$JAVA_HOME/bin/java" ]]; then
    SYSTEM_JAVA_BIN="$JAVA_HOME/bin/java"
    JAVA_MAJOR="$(get_java_major "$SYSTEM_JAVA_BIN" || true)"
  fi
  if [[ "$JAVA_MAJOR" == "21" ]]; then
    JAVA_BIN="$SYSTEM_JAVA_BIN"
  fi
fi
if [[ "$JAVA_MAJOR" != "21" ]]; then
  echo "Java 21 not found in the application folder, PATH, or JAVA_HOME. Re-run the installer." >&2
  exit 1
fi

get_total_mem_gb() {
  local kb
  kb="$(awk '/MemTotal:/ {print $2}' /proc/meminfo 2>/dev/null || true)"
  if [[ -z "$kb" ]]; then
    echo "0"
    return 1
  fi
  echo $((kb / 1024 / 1024))
  return 0
}

get_java_opts() {
  local mem_gb
  mem_gb="$(get_total_mem_gb || true)"
  if [[ -z "$mem_gb" || "$mem_gb" -le 0 ]]; then
    echo ""
    return 0
  fi
  if [[ "$mem_gb" -lt 16 ]]; then
    echo ""
    return 0
  fi
  if [[ "$mem_gb" -lt 32 ]]; then
    echo "-Xmx8g"
    return 0
  fi
  echo ""
}

JAVA_OPTS="$(get_java_opts)"

"$JAVA_BIN" $JAVA_OPTS --add-opens=java.desktop/javax.swing=ALL-UNNAMED \
  --add-opens=java.base/java.lang=ALL-UNNAMED \
  --add-opens=java.base/jdk.internal.org.objectweb.asm=ALL-UNNAMED \
  --add-opens=java.base/jdk.internal.org.objectweb.asm.tree=ALL-UNNAMED \
  --add-opens=java.base/jdk.internal.org.objectweb.asm.Opcodes=ALL-UNNAMED \
  -javaagent:"$LOADER_JAR" -noverify -jar "$BURP_JAR" >/dev/null 2>&1 &
EOF
} > "$LAUNCHER"

chmod +x "$LAUNCHER"
echo "Launcher created: $LAUNCHER"

# Create symlink
SYMLINK_PATH="/usr/local/bin/burp"
if [[ $EUID -eq 0 ]]; then
  ln -sf "$LAUNCHER" "$SYMLINK_PATH"
  echo "Symlink created: $SYMLINK_PATH"
else
  if command -v sudo >/dev/null 2>&1; then
    if sudo ln -sf "$LAUNCHER" "$SYMLINK_PATH"; then
      echo "Symlink created: $SYMLINK_PATH"
    else
      echo "Could not write to /usr/local/bin. Falling back to ~/.local/bin"
      mkdir -p "$HOME/.local/bin"
      SYMLINK_PATH="$HOME/.local/bin/burp"
      ln -sf "$LAUNCHER" "$SYMLINK_PATH"
      echo "Symlink created: $SYMLINK_PATH"
    fi
  else
    echo "sudo not found. Falling back to ~/.local/bin"
    mkdir -p "$HOME/.local/bin"
    SYMLINK_PATH="$HOME/.local/bin/burp"
    ln -sf "$LAUNCHER" "$SYMLINK_PATH"
    echo "Symlink created: $SYMLINK_PATH"
  fi
fi

# Create desktop shortcut (no terminal)
DESKTOP_DIR="$HOME/.local/share/applications"
DESKTOP_FILE="$DESKTOP_DIR/BurpSuiteProfessional.desktop"
mkdir -p "$DESKTOP_DIR"

cat > "$DESKTOP_FILE" <<EOF
[Desktop Entry]
Type=Application
Name=Burp Suite Professional
Exec=$SYMLINK_PATH
Icon=$ICON_PATH
Terminal=false
Categories=Development;Security;
EOF

echo "Desktop shortcut created: $DESKTOP_FILE"
if [[ ! -f "$ICON_PATH" ]]; then
  echo "Warning: burppro.ico not found. You can add it later at $ICON_PATH."
fi

# Create uninstall script
UNINSTALL_SH="$ROOT_DIR/uninstall.sh"
printf '#!/usr/bin/env bash\nINSTALL_USER=%q\n' "${SUDO_USER:-$(id -un)}" > "$UNINSTALL_SH"
cat >> "$UNINSTALL_SH" <<'EOF'
set -euo pipefail

if [[ $EUID -ne 0 ]]; then
  echo "This script must be run as root or with sudo."
  echo "Example: sudo bash $0"
  exit 1
fi

ROOT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
BIN_DIR="$ROOT_DIR/bin"
DATA_DIR="$ROOT_DIR/data"
JDK_DIR="$ROOT_DIR/jdk"
USER_HOME="$(getent passwd "$INSTALL_USER" | cut -d: -f6)"
if [[ -z "$USER_HOME" || "$USER_HOME" != /* || "$USER_HOME" == / || ! -d "$USER_HOME" ]]; then
  echo "[ERROR] Cannot resolve the installation account's home directory: $INSTALL_USER" >&2
  exit 1
fi
DESKTOP_FILE="$USER_HOME/.local/share/applications/BurpSuiteProfessional.desktop"
ENV_FILE="/etc/profile.d/burpsuite_nvth_java.sh"
SYMLINK_SYSTEM="/usr/local/bin/burp"
SYMLINK_USER="$USER_HOME/.local/bin/burp"

echo "[INFO] Close every Burp Suite instance before continuing so it cannot save the license again."
read -r -p "Remove Burp Suite NVTH files AND stored Burp license/preferences for $INSTALL_USER? Other Burp installations sharing these preferences are affected. (Y/N) " answer
if [[ ! $answer =~ ^[Yy]([Ee][Ss])?$ ]]; then
  echo "Canceled."
  exit 1
fi

# Remove only the verified Burp preference node for the installation account.
BURP_PREFS="$USER_HOME/.java/.userPrefs/burp"
if [[ -e "$BURP_PREFS" || -L "$BURP_PREFS" ]]; then
  USER_HOME_REAL="$(realpath -e -- "$USER_HOME")"
  BURP_PREFS_REAL="$(realpath -m -- "$BURP_PREFS")"
  if [[ "$BURP_PREFS_REAL" != "$USER_HOME_REAL/.java/.userPrefs/burp" ]]; then
    echo "[ERROR] Burp preferences resolve through a redirected path. Remove them manually: $BURP_PREFS" >&2
    exit 1
  fi
  rm -rf -- "$BURP_PREFS"
  echo "[INFO] Removed stored Burp license and preferences for $INSTALL_USER."
else
  echo "[INFO] No Burp Java preferences found for $INSTALL_USER."
fi

if [[ -L "$SYMLINK_SYSTEM" ]]; then
  if [[ $EUID -eq 0 ]]; then
    rm -f "$SYMLINK_SYSTEM"
  elif command -v sudo >/dev/null 2>&1; then
    sudo rm -f "$SYMLINK_SYSTEM"
  else
    echo "sudo not found. Skipping removal of $SYMLINK_SYSTEM."
  fi
fi

if [[ -L "$SYMLINK_USER" ]]; then
  rm -f "$SYMLINK_USER"
fi

if [[ -f "$DESKTOP_FILE" ]]; then
  rm -f "$DESKTOP_FILE"
fi

if [[ -d "$BIN_DIR" ]]; then
  rm -rf "$BIN_DIR"
fi

if [[ -d "$DATA_DIR" ]]; then
  rm -rf "$DATA_DIR"
fi

if [[ -d "$JDK_DIR" ]]; then
  rm -rf "$JDK_DIR"
fi

if [[ -f "$ENV_FILE" ]]; then
  rm -f "$ENV_FILE"
fi

UNINSTALL_TXT="$ROOT_DIR/UNINSTALL.txt"
if [[ -f "$UNINSTALL_TXT" ]]; then
  rm -f "$UNINSTALL_TXT"
fi

SELF="$0"
echo "Uninstall completed. Removing uninstall script."
sleep 1
rm -f "$SELF"
EOF
chmod +x "$UNINSTALL_SH"
echo "Uninstall script created: $UNINSTALL_SH"

# Create uninstall instructions
UNINSTALL_TXT="$ROOT_DIR/UNINSTALL.txt"
cat > "$UNINSTALL_TXT" <<EOF
UNINSTALL (Linux)

Step 1: Close all Burp Suite instances and open a terminal.
Step 2: Run as root:
  sudo bash $UNINSTALL_SH
Uninstall also removes the installation account's stored Burp license and Java preferences.
Other Burp installations sharing these preferences will need configuration/activation again.
EOF
echo "Uninstall instructions created: $UNINSTALL_TXT"

resolve_java_bin() {
  local java_bin="$JDK_DIR/bin/java"
  local major
  if [[ -x "$java_bin" ]]; then
    major="$(get_java_major "$java_bin" || true)"
    if [[ "$major" == "21" ]]; then
      echo "$java_bin"
      return 0
    fi
  fi
  java_bin="$(command -v java 2>/dev/null || true)"
  if [[ -n "$java_bin" ]]; then
    major="$(get_java_major "$java_bin" || true)"
    if [[ "$major" == "21" ]]; then
      echo "$java_bin"
      return 0
    fi
  fi
  if [[ -n "${JAVA_HOME:-}" && -x "$JAVA_HOME/bin/java" ]]; then
    java_bin="$JAVA_HOME/bin/java"
    major="$(get_java_major "$java_bin" || true)"
    if [[ "$major" == "21" ]]; then
      echo "$java_bin"
      return 0
    fi
  fi
  return 1
}

get_total_mem_gb() {
  local kb
  kb="$(awk '/MemTotal:/ {print $2}' /proc/meminfo 2>/dev/null || true)"
  if [[ -z "$kb" ]]; then
    echo "0"
    return 1
  fi
  # Round down to whole GB
  echo $((kb / 1024 / 1024))
  return 0
}

get_java_opts() {
  local mem_gb
  mem_gb="$(get_total_mem_gb || true)"
  if [[ -z "$mem_gb" || "$mem_gb" -le 0 ]]; then
    echo ""
    return 0
  fi
  if [[ "$mem_gb" -lt 16 ]]; then
    echo ""
    return 0
  fi
  if [[ "$mem_gb" -lt 32 ]]; then
    echo "-Xmx8g"
    return 0
  fi
  # >= 32GB: no Xmx override
  echo ""
}

run_as_user() {
  local cmd="$1"
  if [[ -n "${SUDO_USER:-}" && "$SUDO_USER" != "root" ]]; then
    local display="${DISPLAY:-:0}"
    local xauth="${XAUTHORITY:-}"
    if [[ -z "$xauth" ]]; then
      local guess="/home/$SUDO_USER/.Xauthority"
      if [[ -f "$guess" ]]; then
        xauth="$guess"
      fi
    fi
    if [[ -n "$xauth" ]]; then
      sudo -u "$SUDO_USER" env DISPLAY="$display" XAUTHORITY="$xauth" bash -lc "$cmd"
    else
      sudo -u "$SUDO_USER" env DISPLAY="$display" bash -lc "$cmd"
    fi
  else
    bash -lc "$cmd"
  fi
}

echo "Starting Core and Burp Suite..."
if [[ -z "${JAVA_BIN:-}" || ! -x "$JAVA_BIN" ]]; then
  JAVA_BIN="$(resolve_java_bin || true)"
fi
if [[ -z "$JAVA_BIN" ]]; then
  echo "Java 21 not found. Re-run the installer."
else
  JAVA_OPTS="$(get_java_opts)"
  if [[ -f "$ACTIVE_LOADER" ]]; then
    run_as_user "\"$JAVA_BIN\" -jar \"$ACTIVE_LOADER\" >/dev/null 2>&1 &"
    sleep 2
  fi
  run_as_user "\"$JAVA_BIN\" ${JAVA_OPTS} --add-opens=java.desktop/javax.swing=ALL-UNNAMED --add-opens=java.base/java.lang=ALL-UNNAMED --add-opens=java.base/jdk.internal.org.objectweb.asm=ALL-UNNAMED --add-opens=java.base/jdk.internal.org.objectweb.asm.tree=ALL-UNNAMED --add-opens=java.base/jdk.internal.org.objectweb.asm.Opcodes=ALL-UNNAMED -javaagent:\"$ACTIVE_LOADER\" -noverify -jar \"$BURP_JAR\" >/dev/null 2>&1 &"
fi

echo ""
echo "Done. You can launch Burp Suite from your app menu or run: $SYMLINK_PATH"
