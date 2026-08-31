"""Native integration contract for the editable Mojo module ABI."""

from std.ffi import external_call

from moxi import test_check


def main() raises:
    var source = "examples/editable_showcase.mojo"
    var output = "/tmp/moxi-live-contract.dylib"
    var c_source = source.as_c_string_slice()
    var c_output = output.as_c_string_slice()
    test_check(
        external_call["moxi_dev_build_live_script", Int32](
            c_source.ptr(),
            c_output.ptr(),
        ) != 0
    )
    test_check(
        external_call["moxi_dev_load_live_script", Int32](c_output.ptr()) != 0
    )
    test_check(
        external_call["moxi_dev_render_live_script", Int32](
            24.0,
            32.0,
            640.0,
            320.0,
        ) > 0
    )
    external_call["moxi_dev_clear_live_script", NoneType]()
    print("Moxi live-reload contract passed")
