#!/usr/bin/env python3
"""Check manual-job settings and local backend metadata without AWS calls."""

import argparse
import json
import os
from pathlib import Path
import re
import sys


REQUIRED_SETTINGS = (
    "AWS_ACCOUNT_ID",
    "AWS_REGION",
    "AWS_PLAN_ROLE_ARN",
    "AWS_APPLY_ROLE_ARN",
)
ROLE_ARN = re.compile(
    r"arn:aws:iam::([0-9]{12}):role/"
    r"(?:[A-Za-z0-9+=,.@_-]+/)*[A-Za-z0-9+=,.@_-]+"
)


def check_settings(environ):
    settings = {name: environ.get(name, "") for name in REQUIRED_SETTINGS}
    for name, value in settings.items():
        if not isinstance(value, str) or not value.strip():
            raise ValueError(f"Set the required GitHub variable {name}.")
    if not re.fullmatch(r"[0-9]{12}", settings["AWS_ACCOUNT_ID"]):
        raise ValueError("AWS_ACCOUNT_ID must contain exactly 12 digits.")
    region = settings["AWS_REGION"]
    if not re.fullmatch(r"[a-z]{2}(?:-[a-z]+)+-[0-9]+", region) or region.startswith(
        ("cn-", "us-gov-")
    ):
        raise ValueError("AWS_REGION must name a commercial AWS region, such as us-east-1.")
    for name in ("AWS_PLAN_ROLE_ARN", "AWS_APPLY_ROLE_ARN"):
        match = ROLE_ARN.fullmatch(settings[name])
        if not match or match.group(1) != settings["AWS_ACCOUNT_ID"]:
            raise ValueError(f"{name} must be an IAM role ARN in AWS_ACCOUNT_ID.")
    if settings["AWS_PLAN_ROLE_ARN"].lower() == settings["AWS_APPLY_ROLE_ARN"].lower():
        raise ValueError("Plan and apply must use different IAM roles.")
    if environ.get("TF_WORKSPACE", "default") != "default":
        raise ValueError("Manual cloud operations require TF_WORKSPACE=default.")
    return settings


def check_backend(metadata, settings):
    # Pinned Terraform 1.12.2 writes version 3, backend.type and backend.config:
    # https://github.com/hashicorp/terraform/blob/v1.12.2/internal/command/workdir/backend_state.go
    # S3 schema: internal/backend/remote-state/s3/backend.go at the same version.
    if not isinstance(metadata, dict) or type(metadata.get("version")) is not int or metadata["version"] != 3:
        raise ValueError("Expected Terraform backend metadata format 3; review REMOTE_STATE.md.")
    backend = metadata.get("backend")
    if not isinstance(backend, dict) or backend.get("type") != "s3":
        raise ValueError("Cloud operations require an initialized S3 backend; review REMOTE_STATE.md.")
    config = backend.get("config")
    if not isinstance(config, dict):
        raise ValueError("Initialized S3 backend configuration is missing.")
    for setting in ("use_lockfile", "encrypt"):
        if config.get(setting) is not True:
            raise ValueError(f"The initialized S3 backend requires {setting}=true.")
    if config.get("allowed_account_ids") != [settings["AWS_ACCOUNT_ID"]]:
        raise ValueError("Backend allowed_account_ids must contain only AWS_ACCOUNT_ID.")
    if config.get("region") != settings["AWS_REGION"]:
        raise ValueError("The initialized backend region must equal AWS_REGION.")
    for setting in ("bucket", "key"):
        value = config.get(setting)
        if not isinstance(value, str) or not value.strip():
            raise ValueError(f"The initialized S3 backend requires a non-empty {setting}.")


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--backend-metadata", type=Path, help="Initialized .terraform/terraform.tfstate to check.")
    args = parser.parse_args(argv)
    try:
        settings = check_settings(os.environ)
        if args.backend_metadata is not None:
            try:
                metadata = json.loads(args.backend_metadata.read_text(encoding="utf-8"))
            except (OSError, UnicodeError, json.JSONDecodeError):
                raise ValueError("Cannot read valid backend metadata; initialize the reviewed S3 backend first.") from None
            check_backend(metadata, settings)
    except ValueError as error:
        print(f"Cloud configuration check failed: {error}", file=sys.stderr)
        return 1
    print("Offline cloud configuration checks passed.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
