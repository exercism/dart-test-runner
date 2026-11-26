#!/usr/bin/env bash

# Synopsis:
# Run the test runner on a solution.

# Arguments:
# $1: exercise slug
# $2: absolute path to solution folder
# $3: absolute path to output directory

# Output:
# Writes the test results to a results.json file in the passed-in output directory.
# The test results are formatted according to the specifications at https://github.com/exercism/docs/blob/main/building/tooling/test-runners/interface.md

# Example:
# ./bin/run.sh two-fer /absolute/path/to/two-fer/solution/folder/ /absolute/path/to/output/directory/

# If any required arguments is missing, print the usage and exit
if [ -z "$1" ] || [ -z "$2" ] || [ -z "$3" ]; then
    echo "usage: ./bin/run.sh exercise-slug /absolute/path/to/two-fer/solution/folder/ /absolute/path/to/output/directory/"
    exit 1
fi

slug="$1"
input_dir="${2%/}"
output_dir="${3%/}"
exercise="${slug//-/_}"
results_file="${output_dir}/results.json"
build_log_file="${output_dir}/build.log"
premade_path=/opt/test-runner/premade

# The test runner relies on files that are only built into the Docker image
if [ ! -d "${premade_path}" ]; then
    echo "warning: ${premade_path} not found. bin/run.sh only works inside the Docker image." >&2
    echo "Use bin/run-in-docker.sh instead (or bin/run-tests-in-docker.sh to run the tests)." >&2
    exit 1
fi

# Create the output directory if it doesn't exist
mkdir -p "${output_dir}"

echo "${slug}: testing..."

pushd "${input_dir}" > /dev/null || exit

# Every exercise's pubspec.yaml lists the same dependencies, so `dart pub upgrade`
# would resolve the same packages on every run, which takes about a second. If
# this pubspec.yaml matches the one saved at image build apart from its name
# (see bin/create-dart-snapshot.sh), we write the saved package_config.json with
# this package's name instead. Otherwise we run pub as before.
template_path="${premade_path}/template"
package_name=$(sed -n -E "s/^name:[[:space:]]*['\"]?([a-z0-9_]+)['\"]?[[:space:]]*$/\1/p" pubspec.yaml)

if [ -n "${package_name}" ] &&
   cmp -s <(grep -v '^name:' pubspec.yaml) <(grep -v '^name:' "${template_path}/pubspec.yaml"); then
    mkdir -p "${input_dir}"/.dart_tool
    jq --arg name "${package_name}" '(.packages[] | select(.rootUri == "../") | .name) = $name' \
        "${template_path}/package_config.json" > "${input_dir}/.dart_tool/package_config.json"
    use_snapshot=true
else
    dart pub upgrade --offline > "${build_log_file}"
    use_snapshot=false
fi

# Copy the precompiled package:test kernel, so `dart test` only compiles the
# solution and its tests (see bin/create-dart-snapshot.sh). `dart test`
# overwrites this file when it finishes, so each run gets its own copy.
mkdir -p "${input_dir}"/.dart_tool/test/
cp "${premade_path}"/kernel/* "${input_dir}/.dart_tool/test/"

# Run the tests for the provided implementation file and redirect stdout and
# stderr to capture it. Because the output is captured, package:test would default
# to its plain "expanded" reporter, so we ask for the coloured "compact" one, which
# only lists the failing tests.
if [ "${use_snapshot}" = true ]; then
    # `dart test` starts the dart command-line tool, which asks pub to check
    # that the packages are up to date and to find package:test's precompiled
    # snapshot. It then runs that snapshot with the project's package_config.json.
    # We already know both, so we run the snapshot directly, which saves about
    # 0.4 seconds. We run the app-jit snapshot trained at image build, which
    # already holds the runner's machine code (see bin/create-dart-snapshot.sh).
    test_output=$(dart --packages=.dart_tool/package_config.json "${premade_path}"/jit/test.snapshot --run-skipped --reporter=compact --color 2>&1)
else
    # copy prenade assets to speed up testing:
    mkdir -p "${input_dir}"/.dart_tool/pub/bin/test/
    find "${premade_path}" -maxdepth 1 -type f -execdir ln -sf "${premade_path}/{}" "${input_dir}/.dart_tool/pub/bin/test/{}" \;

    test_output=$(dart test --run-skipped --reporter=compact --color 2>&1)
fi
exit_code=$?

popd > /dev/null || exit

# Write the results.json file based on the exit code of the command that was 
# just executed that tested the implementation file
if [ $exit_code -eq 0 ]; then
    jq -n '{version: 1, status: "pass"}' > "${results_file}"
else
    # Sanitize the output
    sanitized_test_output=$(printf "${test_output}" | sed -E -e 's/[0-9]+:[0-9]+.*: //g')

    jq -n --arg output "${sanitized_test_output}" '{version: 1, status: "fail", message: $output}' > "${results_file}"
fi

echo "${slug}: done"
