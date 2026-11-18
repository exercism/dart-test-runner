#!/usr/bin/env sh

# Synopsis:
# Run a mock test in the 'regular' way to obtain a binary snapshot of the dart version in use.
# The snapshot can be used to speed up testing.
# This is done once during the build step of the docker container.
# The generated files will be deleted from the test folder afterwards.

premade_path=/opt/test-runner/premade
mock_test_name=mock-test-to-generate-binary
mock_test_path="${premade_path}/${mock_test_name}"

cd "${mock_test_path}"
dart pub upgrade --offline
dart test --run-skipped

# save binary, '' to prevent gobling
mv -v "${mock_test_path}/.dart_tool/pub/bin/test"/* "${premade_path}/"

# Save the kernel file that `dart test` compiled for the mock test. It holds
# package:test and everything it imports, already compiled. `dart test` looks for
# it in `.dart_tool/test/` and, if it's there, compiles only the files that are
# new (the solution and its tests). Without it, every run compiles package:test
# from source, which takes about a second.
#
# `dart test` will only reuse this kernel in another project if two things hold:
# - Every `package:` library in it must point to the same file in that project.
#   The mock test imports its own code by a relative path, so the kernel holds
#   only packages from the pub cache, which every exercise shares.
# - The project's language version must match, because it's part of the file
#   name. The mock's SDK constraint (>=3.2.0) matches the exercises'.
mkdir -p "${premade_path}/kernel"
mv -v "${mock_test_path}/.dart_tool/test"/incremental_kernel.* "${premade_path}/kernel/"

# remove mock-test and artifacts
rm "${mock_test_path}" -rf
