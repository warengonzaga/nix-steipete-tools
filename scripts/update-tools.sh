#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

if ! command -v jq >/dev/null 2>&1; then
  echo "[update-tools] jq is required" >&2
  exit 1
fi

if ! command -v nix >/dev/null 2>&1; then
  echo "[update-tools] nix is required" >&2
  exit 1
fi

prefetch_hash() {
  local url="$1"
  nix store prefetch-file --json "$url" | jq -r .hash
}

latest_release() {
  local repo="$1"
  gh api "repos/${repo}/releases/latest"
}

update_nix_file() {
  local file="$1"
  local version="$2"
  local url="$3"
  local hash="$4"

  python3 - <<PY
from pathlib import Path
import re

path = Path("$file")
text = path.read_text()
text, n1 = re.subn(r'version = "[^"]+";', f'version = "{version}";', text, count=1)
text, n2 = re.subn(r'url = "[^"]+";', f'url = "{url}";', text, count=1)
text, n3 = re.subn(r'hash = "sha256-[^"]+";', f'hash = "{hash}";', text, count=1)

if n1 == 0 or n2 == 0 or n3 == 0:
    raise SystemExit(f"update failed for {path}: version/url/hash not found")

path.write_text(text)
PY
}

update_tool() {
  local tool="$1"
  local repo="$2"
  local asset_regex="$3"
  local nix_file="$4"

  echo "[update-tools] ${tool}" >&2
  local json
  json=$(latest_release "$repo")

  local tag
  tag=$(echo "$json" | jq -r .tag_name)
  local version
  version="${tag#v}"

  local asset
  asset=$(echo "$json" | jq -r --arg re "$asset_regex" '.assets[] | select(.name|test($re)) | .browser_download_url' | head -1)

  if [[ -z "$asset" ]]; then
    echo "[update-tools] no asset matched for ${tool} (${asset_regex})" >&2
    return 1
  fi

  local hash
  hash=$(prefetch_hash "$asset")

  update_nix_file "$nix_file" "$version" "$asset" "$hash"
}

update_oracle() {
  local tool="oracle"
  local repo="steipete/oracle"
  local nix_file="$repo_root/nix/pkgs/oracle.nix"

  echo "[update-tools] ${tool}" >&2
  local json
  json=$(latest_release "$repo")

  local tag
  tag=$(echo "$json" | jq -r .tag_name)
  local version
  version="${tag#v}"

  local asset
  asset=$(echo "$json" | jq -r '.assets[] | select(.name|test("oracle-[0-9.]+\\.tgz")) | .browser_download_url' | head -1)

  if [[ -z "$asset" ]]; then
    echo "[update-tools] no asset matched for oracle" >&2
    return 1
  fi

  local asset_hash
  asset_hash=$(prefetch_hash "$asset")

  local lock_url
  lock_url="https://github.com/steipete/oracle/archive/refs/tags/${tag}.tar.gz"
  local lock_hash
  lock_hash=$(prefetch_hash "$lock_url")

  python3 - <<PY
from pathlib import Path
import re

path = Path("$nix_file")
text = path.read_text()
text, n1 = re.subn(r'version = "[^"]+";', f'version = "{version}";', text, count=1)
text, n2 = re.subn(r'url = "[^"]+";', f'url = "{asset}";', text, count=1)
text, n3 = re.subn(r'hash = "sha256-[^"]+";', f'hash = "{asset_hash}";', text, count=1)
text, n4 = re.subn(r'lockSrc = fetchFromGitHub \{[^}]*?hash = "sha256-[^"]+";',
                   lambda m: re.sub(r'hash = "sha256-[^"]+";', f'hash = "{lock_hash}";', m.group(0)),
                   text, count=1, flags=re.S)
text, n5 = re.subn(r'pnpmDeps.*?hash = "sha256-[^"]+";',
                   lambda m: re.sub(r'hash = "sha256-[^"]+";', 'hash = "sha256-AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA=";', m.group(0)),
                   text, count=1, flags=re.S)

if n1 == 0 or n2 == 0 or n3 == 0 or n4 == 0 or n5 == 0:
    raise SystemExit(f"update failed for {path}: fields not found")

path.write_text(text)
PY

  # Derive pnpmDeps hash from a build mismatch
  set +e
  build_log=$(nix build .#oracle 2>&1)
  set -e
  if echo "$build_log" | grep -q "got: sha256-"; then
    pnpm_hash=$(echo "$build_log" | sed -n 's/.*got: \(sha256-[A-Za-z0-9+/=]*\).*/\1/p' | head -1)
    if [[ -n "$pnpm_hash" ]]; then
      python3 - <<PY
from pathlib import Path
import re

path = Path("$nix_file")
text = path.read_text()
text, n = re.subn(r'pnpmDeps.*?hash = "sha256-[^"]+";',
                  lambda m: re.sub(r'hash = "sha256-[^"]+";', f'hash = "{pnpm_hash}";', m.group(0)),
                  text, count=1, flags=re.S)
if n == 0:
    raise SystemExit(f"update failed for {path}: pnpmDeps hash not found")
path.write_text(text)
PY
    else
      echo "[update-tools] failed to extract pnpmDeps hash" >&2
      return 1
    fi
  else
    echo "[update-tools] no pnpmDeps hash mismatch found" >&2
    return 1
  fi
}

update_tool summarize "steipete/summarize" "summarize-macos-arm64-v[0-9.]+\\.tar\\.gz" "$repo_root/nix/pkgs/summarize.nix"
update_tool gogcli "steipete/gogcli" "gogcli_[0-9.]+_darwin_arm64\\.tar\\.gz" "$repo_root/nix/pkgs/gogcli.nix"
update_tool camsnap "steipete/camsnap" "camsnap-macos-arm64\\.tar\\.gz" "$repo_root/nix/pkgs/camsnap.nix"
update_tool sonoscli "steipete/sonoscli" "sonoscli-macos-arm64\\.tar\\.gz" "$repo_root/nix/pkgs/sonoscli.nix"
update_tool bird "steipete/bird" "bird-macos-universal-v[0-9.]+\\.tar\\.gz" "$repo_root/nix/pkgs/bird.nix"
update_tool peekaboo "steipete/peekaboo" "peekaboo-macos-universal\\.tar\\.gz" "$repo_root/nix/pkgs/peekaboo.nix"
update_tool poltergeist "steipete/poltergeist" "poltergeist-macos-universal-v[0-9.]+\\.tar\\.gz" "$repo_root/nix/pkgs/poltergeist.nix"
update_tool sag "steipete/sag" "sag_[0-9.]+_darwin_universal\\.tar\\.gz" "$repo_root/nix/pkgs/sag.nix"
update_tool imsg "steipete/imsg" "imsg-macos\\.zip" "$repo_root/nix/pkgs/imsg.nix"
update_oracle

