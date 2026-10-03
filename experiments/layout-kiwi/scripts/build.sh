#!/bin/sh
set -eu

script_dir=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
root_dir=$(CDPATH= cd -- "$script_dir/.." && pwd)
build_dir="${LAYOUT_KIWI_BUILD_DIR:-$root_dir/build}"
cxx="${CXX:-c++}"
ar_tool="${AR:-ar}"
system_name=$(uname -s)
case "$system_name" in
    Darwin)
        dynamic_extension=dylib
        dynamic_flag=-dynamiclib
        ;;
    Linux)
        dynamic_extension=so
        dynamic_flag=-shared
        ;;
    *)
        printf '%s\n' "layout-kiwi: unsupported system $system_name (expected Darwin or Linux)" >&2
        exit 1
        ;;
esac

"$root_dir/scripts/bootstrap.sh"
mkdir -p "$build_dir"

common_flags="-std=c++17 -Wall -Wextra -Wpedantic -Werror"
release_flags="$common_flags -O3 -DNDEBUG"
test_flags="$common_flags -O3"
include_flags="-I$root_dir/include -I$root_dir/vendor/kiwi/include"
object_file="$build_dir/bridge.o"
static_library="$build_dir/liblayout_kiwi.a"
dynamic_library="$build_dir/liblayout_kiwi.$dynamic_extension"

# shellcheck disable=SC2086
"$cxx" $release_flags -fPIC $include_flags -c "$root_dir/src/bridge.cpp" -o "$object_file"
"$ar_tool" rcs "$static_library" "$object_file"
# shellcheck disable=SC2086
"$cxx" $release_flags "$dynamic_flag" "$object_file" -o "$dynamic_library"

if [ -f "$root_dir/tests/bridge_test.cpp" ]; then
    test_executable="$build_dir/bridge_test"
    # shellcheck disable=SC2086
    "$cxx" $test_flags $include_flags "$root_dir/tests/bridge_test.cpp" "$static_library" -o "$test_executable"
    printf 'layout-kiwi: built %s\n' "$test_executable"
fi

printf 'layout-kiwi: built %s and %s\n' "$static_library" "$dynamic_library"
