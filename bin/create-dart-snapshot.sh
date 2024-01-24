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

# remove mock-test and artifacts
rm "${mock_test_path}" -rf
