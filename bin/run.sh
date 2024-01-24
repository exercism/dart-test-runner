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

# Create the output directory if it doesn't exist
mkdir -p "${output_dir}"

echo "${slug}: testing..."

pushd "${input_dir}" > /dev/null || exit

dart pub upgrade --offline > "${build_log_file}"

# copy prenade assets to speed up testing:
mkdir -p "${input_dir}"/.dart_tool/pub/bin/test/
find "${premade_path}" -maxdepth 1 -type f -execdir ln -s "${premade_path}/{}" "${input_dir}/.dart_tool/pub/bin/test/{}" \;

# Run the tests for the provided implementation file and redirect stdout and
# stderr to capture it
test_output=$(dart test --run-skipped 2>&1)
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
