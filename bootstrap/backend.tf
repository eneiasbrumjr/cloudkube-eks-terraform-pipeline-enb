# This root intentionally starts with LOCAL state so it can create the backend.
# Protect that local state and keep an encrypted backup outside the working copy.
# No backend is activated, no state is migrated and no AWS operation is performed
# merely by checking out this configuration.
#
# Only after the bucket/key exist and the operator has reviewed migration:
# terraform {
#   backend "s3" {
#     encrypt      = true
#     use_lockfile = true
#   }
# }
#
# Copy the non-secret fields from output.backend_config.bootstrap into an
# operator-owned .s3.tfbackend file outside Git, then deliberately initialize with
# -migrate-state and -backend-config=/secure/path/bootstrap.s3.tfbackend.
# Supply credentials through the AWS credential chain, never in backend settings.
# Do not use the workload state key for this root or run this migration in CI.
