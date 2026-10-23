"""Regression cases for the local guard; no AWS credentials or network calls."""

from copy import deepcopy
import importlib.util
import json
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest


SCRIPT = Path(__file__).resolve().parents[1] / "check-cloud-config.py"
SPEC = importlib.util.spec_from_file_location("check_cloud_config", SCRIPT)
GUARD = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(GUARD)

SETTINGS = {
    "AWS_ACCOUNT_ID": "123456789012",
    "AWS_REGION": "eu-west-1",
    "AWS_PLAN_ROLE_ARN": "arn:aws:iam::123456789012:role/cloudkube/plan",
    "AWS_APPLY_ROLE_ARN": "arn:aws:iam::123456789012:role/cloudkube/apply",
    "TF_WORKSPACE": "default",
}
# Synthetic subset of Terraform 1.12.2's serialized backend metadata. This is
# not a Terraform state snapshot and does not represent an existing S3 bucket.
METADATA = {
    "version": 3,
    "terraform_version": "1.12.2",
    "backend": {
        "type": "s3",
        "config": {
            "bucket": "mock-cloudkube-state",
            "key": "eks/terraform.tfstate",
            "region": "eu-west-1",
            "use_lockfile": True,
            "encrypt": True,
            "allowed_account_ids": ["123456789012"],
        },
        "hash": 0,
    },
}


class CloudSettingsTests(unittest.TestCase):
    def test_valid_roles_and_non_default_region(self):
        self.assertEqual(GUARD.check_settings(SETTINGS)["AWS_REGION"], "eu-west-1")

    def test_missing_settings_fail(self):
        for name in GUARD.REQUIRED_SETTINGS:
            with self.subTest(name=name):
                settings = SETTINGS.copy()
                del settings[name]
                with self.assertRaises(ValueError):
                    GUARD.check_settings(settings)

    def test_malformed_account_and_region_fail(self):
        for name, value in (
            ("AWS_ACCOUNT_ID", "12345678901"),
            ("AWS_ACCOUNT_ID", "123456789012\n"),
            ("AWS_REGION", ""),
            ("AWS_REGION", "us-east-1\n"),
            ("AWS_REGION", "cn-north-1"),
            ("AWS_REGION", "us-gov-west-1"),
        ):
            with self.subTest(name=name, value=value), self.assertRaises(ValueError):
                GUARD.check_settings({**SETTINGS, name: value})

    def test_role_must_belong_to_expected_account(self):
        for name in ("AWS_PLAN_ROLE_ARN", "AWS_APPLY_ROLE_ARN"):
            with self.subTest(name=name), self.assertRaises(ValueError):
                GUARD.check_settings({**SETTINGS, name: "arn:aws:iam::999999999999:role/other"})

    def test_invalid_or_non_role_arns_fail(self):
        for arn in (
            "arn:aws:iam::123456789012:user/plan",
            "arn:aws:sts::123456789012:assumed-role/plan/session",
            "arn:aws:iam::123456789012:role/*",
            "arn:aws:iam::123456789012:role/plan\n",
            "arn:aws-cn:iam::123456789012:role/plan",
        ):
            with self.subTest(arn=arn), self.assertRaises(ValueError):
                GUARD.check_settings({**SETTINGS, "AWS_PLAN_ROLE_ARN": arn})

    def test_shared_role_fails_even_with_case_difference(self):
        for arn in (SETTINGS["AWS_PLAN_ROLE_ARN"], SETTINGS["AWS_PLAN_ROLE_ARN"].replace("/plan", "/PLAN")):
            with self.subTest(arn=arn), self.assertRaises(ValueError):
                GUARD.check_settings({**SETTINGS, "AWS_APPLY_ROLE_ARN": arn})

    def test_non_default_workspace_fails(self):
        with self.assertRaises(ValueError):
            GUARD.check_settings({**SETTINGS, "TF_WORKSPACE": "production"})


class BackendMetadataTests(unittest.TestCase):
    def test_valid_s3_metadata_passes(self):
        GUARD.check_backend(METADATA, SETTINGS)

    def test_missing_malformed_or_local_backend_fails(self):
        for metadata in (
            None, [], {}, {"version": 4}, {"version": 3},
            {"version": 3, "backend": None},
            {"version": 3, "backend": {"type": "local", "config": {}}},
            {"version": 3, "backend": {"type": "s3", "config": None}},
        ):
            with self.subTest(metadata=metadata), self.assertRaises(ValueError):
                GUARD.check_backend(metadata, SETTINGS)

    def test_locking_and_encryption_require_boolean_true(self):
        for field in ("use_lockfile", "encrypt"):
            for value in (False, None, "true", 1):
                metadata = deepcopy(METADATA)
                metadata["backend"]["config"][field] = value
                with self.subTest(field=field, value=value), self.assertRaises(ValueError):
                    GUARD.check_backend(metadata, SETTINGS)

    def test_account_allowlist_cannot_be_missing_or_broadened(self):
        for allowed in (None, [], "123456789012", ["999999999999"], ["123456789012", "999999999999"]):
            metadata = deepcopy(METADATA)
            metadata["backend"]["config"]["allowed_account_ids"] = allowed
            with self.subTest(allowed=allowed), self.assertRaises(ValueError):
                GUARD.check_backend(metadata, SETTINGS)

    def test_backend_region_must_match_job_region(self):
        metadata = deepcopy(METADATA)
        metadata["backend"]["config"]["region"] = "us-east-1"
        with self.assertRaises(ValueError):
            GUARD.check_backend(metadata, SETTINGS)

    def test_bucket_and_key_must_be_non_empty_strings(self):
        for field in ("bucket", "key"):
            for value in (None, "", " \n", 123):
                metadata = deepcopy(METADATA)
                metadata["backend"]["config"][field] = value
                with self.subTest(field=field, value=value), self.assertRaises(ValueError):
                    GUARD.check_backend(metadata, SETTINGS)


class CommandLineTests(unittest.TestCase):
    def run_guard(self, *args, settings=None):
        return subprocess.run(
            [sys.executable, str(SCRIPT), *args],
            env=SETTINGS if settings is None else settings,
            text=True, capture_output=True, check=False,
        )

    def test_missing_job_settings_exit_nonzero(self):
        result = self.run_guard(settings={})
        self.assertEqual(result.returncode, 1)
        self.assertIn("AWS_ACCOUNT_ID", result.stderr)

    def test_unreadable_or_invalid_metadata_exits_without_dumping_content(self):
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / "metadata.json"
            result = self.run_guard("--backend-metadata", str(path))
            self.assertEqual(result.returncode, 1)
            path.write_text('{"secret": "synthetic-do-not-print",', encoding="utf-8")
            result = self.run_guard("--backend-metadata", str(path))
            self.assertEqual(result.returncode, 1)
            self.assertNotIn("synthetic-do-not-print", result.stdout + result.stderr)
            self.assertNotIn("Traceback", result.stderr)

    def test_valid_config_and_metadata_exit_zero(self):
        self.assertEqual(self.run_guard().returncode, 0)
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / "metadata.json"
            path.write_text(json.dumps(METADATA), encoding="utf-8")
            result = self.run_guard("--backend-metadata", str(path))
            self.assertEqual(result.returncode, 0, result.stderr)


if __name__ == "__main__":
    unittest.main()
