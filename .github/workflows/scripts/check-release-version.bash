#!/usr/bin/env bash
#
# Copyright (C) 2022 Tomasz Walczyk
#
# This software may be modified and distributed under the terms
# of the GNU LESSER GENERAL PUBLIC LICENSE VERSION 3.0.
# See the LICENSE file for details.
#
############################################################

set -o errexit -o nounset -o pipefail -o noclobber

############################################################

PLATFORM=$(uname -s)
declare -r PLATFORM

############################################################

declare -r RELEASE_TAG_REGEX='^v(0|[1-9]\d*)\.(0|[1-9]\d*)\.(0|[1-9]\d*)$'

############################################################

Failure() {
  if [[ $# -ne 0 ]]; then
    echo -e "$@" >&2
  fi
  exit 1
}

############################################################
###                       START                          ###
############################################################

trap Failure HUP INT QUIT TERM

#-----------------------------------------------------------
# Check preconditions.
#-----------------------------------------------------------

if [[ "${PLATFORM}" == 'Linux' ]]; then
	for REQUIRED_COMMAND in 'jq' 'curl' 'git'; do
		command -v "${REQUIRED_COMMAND}" >/dev/null 2>&1 \
			|| Failure "Program \"${REQUIRED_COMMAND}\" is not installed!"
	done
else
  Failure 'Platform is not supported!'
fi

[[ -z ${GITHUB_ACTOR+x} ]] && Failure 'Environment variable is not set: GITHUB_ACTOR'
[[ -z ${GITHUB_TOKEN+x} ]] && Failure 'Environment variable is not set: GITHUB_TOKEN'
[[ -z ${GITHUB_API_URL+x} ]] && Failure 'Environment variable is not set: GITHUB_API_URL'
[[ -z ${GITHUB_REF_NAME+x} ]] && Failure 'Environment variable is not set: GITHUB_REF_NAME'
[[ -z ${GITHUB_WORKSPACE+x} ]] && Failure 'Environment variable is not set: GITHUB_WORKSPACE'
[[ -z ${GITHUB_REPOSITORY+x} ]] && Failure 'Environment variable is not set: GITHUB_REPOSITORY'

#-----------------------------------------------------------
# Check if release tag is valid.
#-----------------------------------------------------------

declare -r RELEASE_TAG="${GITHUB_REF_NAME}"
declare -r RELEASE_VERSION="${RELEASE_TAG#v}"
declare -r RELEASE_NAME="sha512-crypt-${RELEASE_VERSION}"
declare -r RELEASE_NOTES_FILE_NAME="${RELEASE_NAME}-release-notes.md"
declare -r RELEASE_NOTES_FILE_PATH="${GITHUB_WORKSPACE}/${RELEASE_NOTES_FILE_NAME}"

if ! echo "${RELEASE_TAG}" | grep -E "${RELEASE_TAG_REGEX}" &> /dev/null; then
  Failure 'Release tag is invalid!'
fi

#-----------------------------------------------------------
# Check if release already exist.
#-----------------------------------------------------------

declare -r EXISTING_RELEASE_URL="${GITHUB_API_URL}/repos/${GITHUB_REPOSITORY}/releases/tags/${RELEASE_TAG}"
EXISTING_RELEASE_TAG=$(curl -s -u "${GITHUB_ACTOR}:${GITHUB_TOKEN}" "${EXISTING_RELEASE_URL}" | jq -r '.tag_name')
declare -r EXISTING_RELEASE_TAG

if [[ "${EXISTING_RELEASE_TAG}" != 'null' ]]; then
  Failure 'Release already exist!'
fi

#-----------------------------------------------------------
# Generate release notes.
#-----------------------------------------------------------

declare -r PREVIOUS_RELEASE_URL="${GITHUB_API_URL}/repos/${GITHUB_REPOSITORY}/releases/latest"
PREVIOUS_RELEASE_TAG=$(curl -s -u "${GITHUB_ACTOR}:${GITHUB_TOKEN}" "${PREVIOUS_RELEASE_URL}" | jq -r '.tag_name')
declare -r PREVIOUS_RELEASE_TAG

echo "### Changes in this release:" > "${RELEASE_NOTES_FILE_PATH}"
if [[ "${PREVIOUS_RELEASE_TAG}" != 'null' ]]; then
  if ! echo "${PREVIOUS_RELEASE_TAG}" | grep -E "${RELEASE_TAG_REGEX}" &> /dev/null; then
    Failure 'Previous release tag is invalid!'
  fi
  if [[ "${RELEASE_TAG}" != "$(echo -e "${PREVIOUS_RELEASE_TAG}\n${RELEASE_TAG}" | sort -rV | head -n 1 || true)" ]]; then
    Failure 'Release tag must be newer than previous release tag!'
  fi
  git log "${PREVIOUS_RELEASE_TAG}..${RELEASE_TAG}" --no-merges --pretty='format:- %H %s' >> "${RELEASE_NOTES_FILE_PATH}"
else
  git log --no-merges --pretty='format:- %H %s' >> "${RELEASE_NOTES_FILE_PATH}"
fi

#-----------------------------------------------------------
# Set output variables.
#-----------------------------------------------------------

echo "::set-output name=release_name::${RELEASE_NAME}"
echo "::set-output name=release_version::${RELEASE_VERSION}"
echo "::set-output name=release_notes_file_name::${RELEASE_NOTES_FILE_NAME}"
echo "::set-output name=release_notes_file_path::${RELEASE_NOTES_FILE_PATH}"
