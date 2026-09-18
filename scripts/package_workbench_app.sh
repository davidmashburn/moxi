#!/usr/bin/env bash
set -euo pipefail

repo_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$repo_dir"

if [[ "$(uname -s)" != "Darwin" ]]; then
  echo "the Moxi Data Workbench app bundle requires macOS" >&2
  exit 1
fi

dist_dir="$repo_dir/dist"
app_path="$dist_dir/Moxi Data Workbench.app"
app_name="Moxi Data Workbench.app"

# Build and sign a new bundle in a fresh directory. Reusing the previous
# executable inode can leave launchd/taskgated with a stale code-signature
# result after the binary changes.
mkdir -p "$dist_dir"
stage_root="$(mktemp -d "$dist_dir/.moxi-data-workbench-stage.XXXXXX")"
backup_root=""
staged_app="$stage_root/$app_name"
backup_app=""
old_app_moved=0
new_app_installed=0

cleanup() {
  local exit_status=$?
  local preserve_backup=0

  # If replacing the old bundle failed before the new one was installed,
  # restore the original bundle before cleaning up the temporary paths.
  if (( exit_status != 0 && old_app_moved == 1 && new_app_installed == 0 )); then
    if [[ ! -e "$app_path" && -e "$backup_app" ]]; then
      if ! mv "$backup_app" "$app_path"; then
        preserve_backup=1
        echo "could not restore the previous app bundle; it remains at $backup_app" >&2
        exit_status=1
      fi
    fi
  fi

  if [[ -n "$stage_root" && -d "$stage_root" ]]; then
    rm -rf -- "$stage_root"
  fi
  if (( preserve_backup == 0 )) && [[ -n "$backup_root" && -d "$backup_root" ]]; then
    rm -rf -- "$backup_root"
  fi

  return "$exit_status"
}
trap cleanup EXIT

mkdir -p "$staged_app/Contents/MacOS"
cp "$dist_dir/moxi-data-workbench" "$staged_app/Contents/MacOS/moxi-data-workbench"
cp native/moxi_workbench_Info.plist "$staged_app/Contents/Info.plist"
chmod +x "$staged_app/Contents/MacOS/moxi-data-workbench"

# A linker-signed executable is not enough for LaunchServices to accept an
# application bundle. Ad-hoc sign the bundle so Info.plist and its resource
# seal are present, then verify the exact staged bundle before installation.
/usr/bin/codesign --force --sign - --timestamp=none "$staged_app"
/usr/bin/codesign --verify --deep --strict --verbose=2 "$staged_app"

# Move the old bundle aside and install the freshly signed directory with a
# single same-filesystem rename. This keeps a failed replacement recoverable.
backup_root="$(mktemp -d "$dist_dir/.moxi-data-workbench-backup.XXXXXX")"
backup_app="$backup_root/$app_name"
if [[ -e "$app_path" || -L "$app_path" ]]; then
  mv "$app_path" "$backup_app"
  old_app_moved=1
fi
if ! mv "$staged_app" "$app_path"; then
  exit 1
fi
new_app_installed=1

echo "Packaged and ad-hoc signed: $app_path"
