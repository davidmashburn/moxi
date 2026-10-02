#!/bin/sh
set -eu

script_dir=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
root_dir=$(CDPATH= cd -- "$script_dir/.." && pwd)
vendor_dir="$root_dir/vendor/kiwi"
include_dir="$vendor_dir/include"
repo_url="https://github.com/nucleic/kiwi.git"
tag_name="1.5.0"
pinned_sha="5e76d91fd77dc443cb0db36e7398fc13844a0524"

if ! command -v git >/dev/null 2>&1; then
    printf '%s\n' 'layout-kiwi: git is required to fetch Kiwi headers' >&2
    exit 1
fi
if ! command -v tar >/dev/null 2>&1; then
    printf '%s\n' 'layout-kiwi: tar is required to unpack Kiwi headers' >&2
    exit 1
fi

tag_sha=$(git ls-remote "$repo_url" "refs/tags/$tag_name^{}" | awk 'NR == 1 { print $1 }')
if [ "$tag_sha" != "$pinned_sha" ]; then
    printf '%s\n' "layout-kiwi: remote $tag_name resolves to ${tag_sha:-<missing>}, expected $pinned_sha" >&2
    exit 1
fi

tmp_dir=$(mktemp -d "${TMPDIR:-/tmp}/layout-kiwi.XXXXXX")
cleanup() {
    rm -rf "$tmp_dir"
}
trap cleanup EXIT HUP INT TERM

git -C "$tmp_dir" init -q
git -C "$tmp_dir" remote add origin "$repo_url"
git -C "$tmp_dir" fetch -q --depth 1 origin "$pinned_sha"
fetched_sha=$(git -C "$tmp_dir" rev-parse FETCH_HEAD^{commit})
if [ "$fetched_sha" != "$pinned_sha" ]; then
    printf '%s\n' "layout-kiwi: fetched $fetched_sha, expected $pinned_sha" >&2
    exit 1
fi

mkdir -p "$include_dir"
git -C "$tmp_dir" archive --format=tar "$pinned_sha" -- kiwi | tar -xf - -C "$include_dir"

header_count=$(find "$include_dir/kiwi" -type f -name '*.h' -print | wc -l | tr -d ' ')
if [ "$header_count" -eq 0 ]; then
    printf '%s\n' 'layout-kiwi: fetched archive did not contain Kiwi headers' >&2
    exit 1
fi

printf 'layout-kiwi: fetched Kiwi %s at %s (%s headers)\n' "$tag_name" "$pinned_sha" "$header_count"
