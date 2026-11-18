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

# Save the mock's pubspec.yaml and the package_config.json written for it by pub.
# Every exercise lists the same dependencies, so bin/run.sh reuses this
# package_config.json for any pubspec.yaml that matches this one apart from its
# name, and skips pub.
mkdir -p "${premade_path}/template"
cp -v pubspec.yaml .dart_tool/package_config.json "${premade_path}/template/"

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

# Train an app-jit snapshot of package:test's runner on the mock test. Pub's
# snapshot holds only kernel code, so the VM compiles the runner's code to
# machine code on every run. The app-jit snapshot also holds the machine code
# compiled during this training run, which saves about half a second per run.
# The training run needs the saved kernel back in place, so it takes the same
# path as a real run.
mkdir -p "${mock_test_path}/.dart_tool/test" "${premade_path}/jit"
cp "${premade_path}"/kernel/* "${mock_test_path}/.dart_tool/test/"
dart --snapshot-kind=app-jit --snapshot="${premade_path}/jit/test.snapshot" \
    "${premade_path}"/test.dart-*.snapshot --run-skipped

# remove mock-test and artifacts
rm "${mock_test_path}" -rf
