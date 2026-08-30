"""GPU renderer API contract without requiring a native link in unit tests."""

from moxi import BACKEND_GPU, backend_capabilities, test_check


def main():
    var capabilities = backend_capabilities(BACKEND_GPU)
    test_check(not capabilities.available)
    test_check(capabilities.gpu_acceleration)
    print("Moxi Metal contract test passed")
