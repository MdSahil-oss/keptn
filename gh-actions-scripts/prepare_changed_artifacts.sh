#!/bin/bash

######################################################################################
#
# This script heavily uses Bash parameter expansion.
# To better understand what is going on here, you can read up on the topic here:
# https://www.gnu.org/software/bash/manual/html_node/Shell-Parameter-Expansion.html
#
######################################################################################

CHANGED_FILES=$1

if [ $# -ne 1 ]; then
  echo "Usage: $0 CHANGED_FILES"
  exit
fi

# initialize variables with false (make sure they are also set in needs.prepare_ci_run.outputs !!!)
BUILD_INSTALLER=false
BUILD_API=false
BUILD_CLI=false
BUILD_BRIDGE=false
BUILD_BRIDGE_UI_TEST=false
BUILD_BRIDGE_CODE_STYLE=false
BUILD_BRIDGE_SERVER=false
BUILD_APPROVAL_SVC=false
BUILD_DISTRIBUTOR=false
BUILD_SHIPYARD_CONTROLLER=false
BUILD_SECRET_SVC=false
BUILD_RESOURCE_SVC=false
BUILD_REMEDIATION_SVC=false
BUILD_LIGHTHOUSE_SVC=false
BUILD_MONGODB_DS=false
BUILD_STATISTICS_SVC=false
BUILD_WEBHOOK_SVC=false

# Set the list of artifacts corresponding to the build that's currently running
if [ "$RELEASE_BUILD" != 'true' ] && [ "$PRERELEASE_BUILD" != 'true' ] && [ "$BUILD_EVERYTHING" != 'true' ]; then
  # This is a normal build that needs to build and test the changed artifacts
  echo "Preparing for build of changed artifacts..."
  artifacts=(
    "$BRIDGE_ARTIFACT_PREFIX"
    "$BRIDGE_UI_TEST_ARTIFACT_PREFIX"
    "$BRIDGE_CODE_STYLE_ARTIFACT_PREFIX"
    "$BRIDGE_SERVER_ARTIFACT_PREFIX"
    "$API_ARTIFACT_PREFIX"
    "$APPROVAL_SVC_ARTIFACT_PREFIX"
    "$DISTRIBUTOR_ARTIFACT_PREFIX"
    "$SHIPYARD_CONTROLLER_ARTIFACT_PREFIX"
    "$SECRET_SVC_ARTIFACT_PREFIX"
    "$RESOURCE_SVC_ARTIFACT_PREFIX"
    "$REMEDIATION_SVC_ARTIFACT_PREFIX"
    "$LIGHTHOUSE_SVC_ARTIFACT_PREFIX"
    "$MONGODB_DS_ARTIFACT_PREFIX"
    "$STATISTICS_SVC_ARTIFACT_PREFIX"
    "$WEBHOOK_SVC_ARTIFACT_PREFIX"
  )
elif [ "$RELEASE_BUILD" != 'true' ] && [ "$PRERELEASE_BUILD" != 'true' ] && [ "$BUILD_EVERYTHING" == 'true' ] && [ "$GITHUB_REF_PROTECTED" == 'true' ]; then
  # This is a build-everything build from a protected branch, i.e. master or a maintenance branch, we should run bridge tests in this case
  echo "Preparing for master/maintenance branch build..."
  artifacts=(
    "$BRIDGE_ARTIFACT_PREFIX"
    "$BRIDGE_UI_TEST_ARTIFACT_PREFIX"
    "$BRIDGE_CODE_STYLE_ARTIFACT_PREFIX"
    "$BRIDGE_SERVER_ARTIFACT_PREFIX"
    "$API_ARTIFACT_PREFIX"
    "$APPROVAL_SVC_ARTIFACT_PREFIX"
    "$DISTRIBUTOR_ARTIFACT_PREFIX"
    "$SHIPYARD_CONTROLLER_ARTIFACT_PREFIX"
    "$SECRET_SVC_ARTIFACT_PREFIX"
    "$RESOURCE_SVC_ARTIFACT_PREFIX"
    "$REMEDIATION_SVC_ARTIFACT_PREFIX"
    "$LIGHTHOUSE_SVC_ARTIFACT_PREFIX"
    "$MONGODB_DS_ARTIFACT_PREFIX"
    "$STATISTICS_SVC_ARTIFACT_PREFIX"
    "$WEBHOOK_SVC_ARTIFACT_PREFIX"
  )
elif [ "$RELEASE_BUILD" != 'true' ] && [ "$PRERELEASE_BUILD" != 'true' ] && [ "$BUILD_EVERYTHING" == 'true' ] && [ "$GITHUB_REF_PROTECTED" != 'true' ]; then
  # This is a build-everything build for integration tests, which skips bridge code style and UI tests
  echo "Preparing for build-everything build..."
  artifacts=(
    "$BRIDGE_ARTIFACT_PREFIX"
    "$BRIDGE_SERVER_ARTIFACT_PREFIX"
    "$API_ARTIFACT_PREFIX"
    "$APPROVAL_SVC_ARTIFACT_PREFIX"
    "$DISTRIBUTOR_ARTIFACT_PREFIX"
    "$SHIPYARD_CONTROLLER_ARTIFACT_PREFIX"
    "$SECRET_SVC_ARTIFACT_PREFIX"
    "$RESOURCE_SVC_ARTIFACT_PREFIX"
    "$REMEDIATION_SVC_ARTIFACT_PREFIX"
    "$LIGHTHOUSE_SVC_ARTIFACT_PREFIX"
    "$MONGODB_DS_ARTIFACT_PREFIX"
    "$STATISTICS_SVC_ARTIFACT_PREFIX"
    "$WEBHOOK_SVC_ARTIFACT_PREFIX"
  )
else
  # This is a release build
  echo "Preparing for release build..."
  artifacts=(
    "$BRIDGE_ARTIFACT_PREFIX"
    "$API_ARTIFACT_PREFIX"
    "$APPROVAL_SVC_ARTIFACT_PREFIX"
    "$DISTRIBUTOR_ARTIFACT_PREFIX"
    "$SHIPYARD_CONTROLLER_ARTIFACT_PREFIX"
    "$SECRET_SVC_ARTIFACT_PREFIX"
    "$RESOURCE_SVC_ARTIFACT_PREFIX"
    "$REMEDIATION_SVC_ARTIFACT_PREFIX"
    "$LIGHTHOUSE_SVC_ARTIFACT_PREFIX"
    "$MONGODB_DS_ARTIFACT_PREFIX"
    "$STATISTICS_SVC_ARTIFACT_PREFIX"
    "$WEBHOOK_SVC_ARTIFACT_PREFIX"
  )
fi

echo "Changed files:"
echo "$CHANGED_FILES"
matrix_config='{"config":['
# shellcheck disable=SC2016
build_artifact_template='{"artifact":$artifact,"working-dir":$working_dir,"should-run":$should_run,"docker-test-target":$docker_test_target,"should-push-image":$should_push_image}'

# Add all changed artifacts to the build matrix
echo "Checking changed files against artifacts now"
echo "::group::Check output"
for changed_file in $CHANGED_FILES; do
  echo "Checking if $changed_file leads to a build..."

  if [[ $changed_file == "${INSTALLER_FOLDER}"* ]]; then
    echo "Found changes in Installer"
    BUILD_INSTALLER=true
    continue
  fi

  if [[ $changed_file == "${CLI_FOLDER}"* ]]; then
    echo "Found changes in CLI"
    BUILD_CLI=true
    continue
  fi

  for artifact in "${artifacts[@]}"; do
    # Prepare variables
    artifact_fullname="${artifact}_ARTIFACT"
    artifact_folder="${artifact}_FOLDER"
    should_build_artifact="BUILD_${artifact}"
    docker_test_target="${artifact}_DOCKER_TEST_TARGET"
    should_push_image="${artifact}_SHOULD_PUSH_IMAGE"

    # Check if this artifact needs an image to be pushed
    if [ "${!should_push_image}" != "false" ]; then
      should_push_image="true"
    else
      should_push_image="false"
    fi

    if [[ ( $changed_file == ${!artifact_folder}* ) && ( "${!should_build_artifact}" != 'true' ) ]]; then
      echo "Found changes in $artifact"
      # Set the artifact's should-build variable to true
      IFS= read -r "${should_build_artifact?}" <<< "true"

      # Render build matrix string for the current artifact
      artifact_config=$(jq -j -n \
        --arg artifact "${!artifact_fullname}" \
        --arg working_dir "${!artifact_folder}" \
        --arg should_run "${!should_build_artifact}" \
        --arg docker_test_target "${!docker_test_target}" \
        --arg should_push_image "${should_push_image}" \
        "$build_artifact_template"
      )

      # Add rendered string to matrix
      matrix_config="$matrix_config$artifact_config,"
    fi
  done
done

echo "Done checking changed files"
echo "Checking for build-everything build"

# If this is a build-everything build, also add all other unchanged artifacts to the build matrix
if [[ $BUILD_EVERYTHING == 'true' ]]; then
  for artifact in "${artifacts[@]}"; do
    # Prepare variables
    artifact_fullname="${artifact}_ARTIFACT"
    artifact_folder="${artifact}_FOLDER"
    should_build_artifact="BUILD_${artifact}"
    docker_test_target="${artifact}_DOCKER_TEST_TARGET"
    should_push_image="${artifact}_SHOULD_PUSH_IMAGE"

    # Check if this artifact needs an image to be pushed
    if [ "${!should_push_image}" != "false" ]; then
      should_push_image="true"
    else
      should_push_image="false"
    fi

    if [[ "${!should_build_artifact}" != 'true' ]]; then
      # Render build matrix string for the current artifact
      echo "Adding unchanged artifact $artifact to build matrix since build everything was requested"
      artifact_config=$(jq -j -n \
        --arg artifact "${!artifact_fullname}" \
        --arg working_dir "${!artifact_folder}" \
        --arg should_run "false" \
        --arg docker_test_target "${!docker_test_target}" \
        --arg should_push_image "${should_push_image}" \
        "$build_artifact_template"
      )

      # Add rendered string to matrix
      matrix_config="$matrix_config$artifact_config,"
    fi
  done
fi
echo "::endgroup::"


# Terminate matrix JSON config and remove trailing comma
matrix_config="${matrix_config%,}]}"

# Escape newlines for multiline string support in GH actions
# Reference: https://github.community/t/set-output-truncates-multiline-strings/16852
matrix_config="${matrix_config//'%'/''}"
matrix_config="${matrix_config//$'\n'/''}"
matrix_config="${matrix_config//$'\r'/''}"
matrix_config="${matrix_config//$' '/''}"

echo "::group::Build Matrix"
echo "$matrix_config"
echo "::endgroup::"

# print job outputs (make sure they are also set in needs.prepare_ci_run.outputs !!!)
# shellcheck disable=SC2129
echo "BUILD_INSTALLER=$BUILD_INSTALLER" >> "$GITHUB_OUTPUT"
echo "BUILD_CLI=$BUILD_CLI" >> "$GITHUB_OUTPUT"
echo "BUILD_MATRIX=$matrix_config" >> "$GITHUB_OUTPUT"
echo ""
echo "The following artifacts have changes and will be built fresh:"
echo "BUILD_INSTALLER: $BUILD_INSTALLER"
echo "BUILD_API: $BUILD_API"
echo "BUILD_CLI: $BUILD_CLI"
echo "BUILD_BRIDGE: $BUILD_BRIDGE"
echo "BUILD_BRIDGE_UI_TEST: $BUILD_BRIDGE_UI_TEST"
echo "BUILD_BRIDGE_CODE_STYLE: $BUILD_BRIDGE_CODE_STYLE"
echo "BUILD_BRIDGE_SERVER: $BUILD_BRIDGE_SERVER"
echo "BUILD_APPROVAL_SVC: $BUILD_APPROVAL_SVC"
echo "BUILD_DISTRIBUTOR: $BUILD_DISTRIBUTOR"
echo "BUILD_SHIPYARD_CONTROLLER: $BUILD_SHIPYARD_CONTROLLER"
echo "BUILD_SECRET_SVC: $BUILD_SECRET_SVC"
echo "BUILD_RESOURCE_SVC: $BUILD_RESOURCE_SVC"
echo "BUILD_REMEDIATION_SVC: $BUILD_REMEDIATION_SVC"
echo "BUILD_LIGHTHOUSE_SVC: $BUILD_LIGHTHOUSE_SVC"
echo "BUILD_MONGODB_DS: $BUILD_MONGODB_DS"
echo "BUILD_STATISTICS_SVC: $BUILD_STATISTICS_SVC"
echo "BUILD_WEBHOOK_SVC: $BUILD_WEBHOOK_SVC"

if [[ "$matrix_config" == '{"config":[]}' ]]; then
  echo "Build matrix is emtpy, setting output..."
  echo "BUILD_MATRIX_EMPTY=true" >> "$GITHUB_OUTPUT"
else
  echo "Build matrix is NOT emtpy, setting output..."
  echo "BUILD_MATRIX_EMPTY=false" >> "$GITHUB_OUTPUT"
fi
