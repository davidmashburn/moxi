"""Orchestration checks for the workbench release gate."""

from pathlib import Path
import json
import subprocess
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[1]
import sys

sys.path.insert(0, str(ROOT / "scripts"))
import workbench_release_gate as gate


class FakeRunner:
    def __init__(self, failing_task=None):
        self.failing_task = failing_task
        self.calls = []

    def __call__(self, command, **kwargs):
        self.calls.append((list(command), kwargs))
        if command[:2] == ["git", "rev-parse"]:
            return subprocess.CompletedProcess(command, 0, stdout="abc123\n", stderr="")
        if command[:2] == ["git", "status"]:
            return subprocess.CompletedProcess(command, 0, stdout=" M source.mojo\n", stderr="")
        task = command[2]
        status = 7 if task == self.failing_task else 0
        return subprocess.CompletedProcess(
            command,
            status,
            stdout=f"stdout for {task}\n",
            stderr=f"stderr for {task}\n" if status else "",
        )


def fixed_now():
    return gate.dt.datetime(2026, 9, 23, 15, 0, tzinfo=gate.UTC)


class WorkbenchReleaseGateTests(unittest.TestCase):
    def test_optional_lanes_are_explicit_and_ordered(self):
        required = [spec.task for spec in gate.command_specs()]
        self.assertEqual(
            required,
            [
                "workbench-test",
                "native-custom-paint-cache",
                "native-accessibility-abi",
                "data-workbench-build",
                "workbench-artifact-check",
            ],
        )
        optional = [
            spec.task
            for spec in gate.command_specs(
                include_benchmark=True, include_package_consumer=True
            )
            if spec.optional
        ]
        self.assertEqual(optional, ["workbench-benchmark", "package-consumer"])

    def test_report_uses_argument_paths_and_keeps_json_logs(self):
        with tempfile.TemporaryDirectory(prefix="moxi-gate-test-") as temp:
            root = Path(temp) / "repo"
            root.mkdir()
            evidence = Path(temp) / "evidence"
            runner = FakeRunner()
            report = gate.run_gate(
                repo=root,
                output_dir=evidence,
                pixi="/opt/pixi",
                include_benchmark=True,
                include_package_consumer=True,
                runner=runner,
                now=fixed_now,
                clock=lambda: 0.0,
            )

            self.assertEqual(report["status"], "passed")
            self.assertEqual(report["revision"], "abc123")
            self.assertTrue(report["dirty"])
            self.assertEqual(report["report"], str(evidence.resolve() / "report.json"))
            self.assertTrue((evidence / "report.json").is_file())
            self.assertEqual(
                [entry["identifier"] for entry in report["commands"]],
                [
                    "workbench-test",
                    "native-custom-paint-cache",
                    "native-accessibility-abi",
                    "data-workbench-build",
                    "workbench-artifact-check",
                    "workbench-benchmark",
                    "package-consumer",
                ],
            )
            for entry in report["commands"]:
                log = Path(entry["log"])
                self.assertTrue(log.is_file())
                payload = json.loads(log.read_text())
                self.assertIn("exit_code", payload)
                self.assertIn("stdout", payload)
                self.assertIn("stderr", payload)

            benchmark_call = next(
                kwargs
                for command, kwargs in runner.calls
                if command == ["/opt/pixi", "run", "workbench-benchmark"]
            )
            self.assertEqual(
                benchmark_call["env"]["MOXI_WORKBENCH_DIR"],
                str(evidence.resolve() / "benchmark"),
            )

    def test_failed_build_skips_artifact_validation_instead_of_using_stale_bundle(self):
        with tempfile.TemporaryDirectory(prefix="moxi-gate-failure-") as temp:
            root = Path(temp) / "repo"
            root.mkdir()
            evidence = Path(temp) / "evidence"
            runner = FakeRunner(failing_task="data-workbench-build")
            report = gate.run_gate(
                repo=root,
                output_dir=evidence,
                runner=runner,
                now=fixed_now,
                clock=lambda: 0.0,
            )

            self.assertEqual(report["status"], "failed")
            artifact = next(
                entry
                for entry in report["commands"]
                if entry["identifier"] == "workbench-artifact-check"
            )
            self.assertEqual(artifact["status"], "skipped")
            self.assertIn("data-workbench-build", artifact["skip_reason"])
            task_calls = [
                command[2]
                for command, _ in runner.calls
                if len(command) >= 3 and command[0] != "git"
            ]
            self.assertNotIn("workbench-artifact-check", task_calls)
            self.assertTrue(any("data-workbench-build" in reason for reason in report["failure_reasons"]))

    def test_existing_evidence_directory_is_not_overwritten(self):
        with tempfile.TemporaryDirectory(prefix="moxi-gate-existing-") as temp:
            root = Path(temp) / "repo"
            root.mkdir()
            evidence = Path(temp) / "evidence"
            evidence.mkdir()
            (evidence / "report.json").write_text("previous\n")
            with self.assertRaises(ValueError):
                gate.run_gate(
                    repo=root,
                    output_dir=evidence,
                    runner=FakeRunner(),
                    now=fixed_now,
                    clock=lambda: 0.0,
                )


if __name__ == "__main__":
    unittest.main()
