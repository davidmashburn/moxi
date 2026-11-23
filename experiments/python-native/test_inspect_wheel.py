"""Mach-O output contracts from thin and architecture-qualified otool runs."""
import unittest
import sys
from inspect_wheel import command, dylib_dependencies


class DependencyOutputTests(unittest.TestCase):
    def test_thin_and_architecture_qualified_headers(self):
        rows = ('\t@rpath/libKGENCompilerRTShared.dylib (compatibility version 0.0.0, current version 0.0.0)\n'
                '\t/usr/lib/libSystem.B.dylib (compatibility version 1.0.0, current version 1345.100.2)\n')
        expected = ['@rpath/libKGENCompilerRTShared.dylib', '/usr/lib/libSystem.B.dylib']
        for headers in ('/tmp/wheel/_core.so:\n',
                        '/tmp/wheel/_core.so:\n/tmp/wheel/_core.so (architecture arm64):\n'):
            with self.subTest(headers=headers):
                self.assertEqual(dylib_dependencies(headers + rows), expected)
        multiple = ('/tmp/wheel/_core.so (architecture arm64):\n' + rows +
                    '/tmp/wheel/_core.so (architecture x86_64):\n' + rows)
        self.assertEqual(dylib_dependencies(multiple), expected)

    def test_missing_or_unrecognized_rows_are_rejected(self):
        for output in ('/tmp/wheel/_core.so:\n', '/tmp/wheel/_core.so:\n\tunexpected dependency row\n'):
            with self.subTest(output=output), self.assertRaises(AssertionError):
                dylib_dependencies(output)

    def test_failed_tool_preserves_its_diagnostic(self):
        with self.assertRaisesRegex(RuntimeError, r'failed \(1\): signature diagnostic'):
            command(sys.executable, '-c',
                    'import sys; sys.stderr.write("signature diagnostic\\n"); sys.exit(1)')


if __name__ == '__main__':
    unittest.main()
