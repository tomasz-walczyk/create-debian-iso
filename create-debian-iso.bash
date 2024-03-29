#!/usr/bin/env bash
#
# shellcheck disable=SC2317
#
# Copyright (C) 2022 Tomasz Walczyk
#
# This software may be modified and distributed under the terms
# of the MIT license. See the LICENSE file for details.
#
############################################################

set -o errexit -o nounset -o pipefail -o noclobber

############################################################

# Name of the platform.
Platform=$(uname -s | tr '[:upper:]' '[:lower:]')
declare -r Platform

# Path to the directory containing this script.
ScriptRoot=$(cd "$(dirname "${0}")" && pwd)
declare -r ScriptRoot

# Path to the newly created temporary directory.
TemporaryDir=$(mktemp -q -d '/tmp/create-debian-iso.bash.XXXXXXXXXXXXXXXX')
declare -r TemporaryDir

############################################################

# Regular expression used for selecting correct Debian ISO file.
declare -r SourceISOPattern='(debian-)[0-9\.]+(-).+(-netinst.iso)'

# URL pointing to the directory from which Debian ISO should be downloaded.
declare -r SourceISOURL='https://cdimage.debian.org/debian-cd/current/amd64/iso-cd/'

############################################################

declare -r SourceISOFile="${TemporaryDir}/source.iso"
declare -r CustomISOFile="${TemporaryDir}/custom.iso"
declare -r CustomISOData="${TemporaryDir}/custom"

############################################################

pushd() {
  command pushd "$@" > /dev/null
}

#-----------------------------------------------------------

popd() {
  command popd > /dev/null
}

#-----------------------------------------------------------

Failure() {
  if [[ $# -ne 0 ]]; then
    echo -e "$@" >&2
  fi
  exit 1
}

#-----------------------------------------------------------

Success() {
  if [[ $# -ne 0 ]]; then
    echo -e "$@"
  fi
  exit 0
}

#-----------------------------------------------------------

Clean() {
  if [[ -d "${TemporaryDir}" ]]; then
    chmod -R u+w "${TemporaryDir}"
    rm -R "${TemporaryDir}"
  fi
}

#-----------------------------------------------------------

ValidateInputFile() {
  [[ -z "${2}" ]] && Failure "Invalid argument: \"${1}\" : Empty value!"
  if [[ "${2:0:1}" != '/' ]]; then
    declare -r Path="${PWD}/${2}"
  else
    declare -r Path="${2}"
  fi
  [[ ! -f "${Path}" ]] && Failure "Invalid argument: \"${1}\" : File \"${Path}\" does not exists!"
  [[ ! -r "${Path}" ]] && Failure "Invalid argument: \"${1}\" : File \"${Path}\" is not readable!"
  echo -n "${Path}"
}

#-----------------------------------------------------------

ValidatOutputFile() {
  [[ -z "${2}" ]] && Failure "Invalid argument: \"${1}\" : Empty value!"
  if [[ "${2:0:1}" != '/' ]]; then
    declare -r Path="${PWD}/${2}"
  else
    declare -r Path="${2}"
  fi
  [[ -e "${Path}" ]] && Failure "Invalid argument: \"${1}\" : File \"${Path}\" already exists!"
  [[ ! -e "$(dirname "${Path}")" ]] && Failure "Invalid argument: \"${1}\" : Directory \"$(dirname "${Path}")\" does not exists!"
  [[ ! -w "$(dirname "${Path}")" ]] && Failure "Invalid argument: \"${1}\" : Directory \"$(dirname "${Path}")\" is not writable!"
  echo -n "${Path}"
}

#-----------------------------------------------------------

Help() {
cat << EndOfHelp
Synopsis:
  Script for creating unattended Debian installer.

Usage:
  $(basename "$0") [OPTIONS]...

Description:
  Script will create Debian installer from the latest minimal CD available.
  If --seed-file argument was not specified then default seed file will be used.
  If --data-file argument was not specified then default data file will be used.
  ISO will be saved to the script directory unless --output-file was provided.

Options:
  --seed-file <path>   : Path to the seed file.
  --data-file <path>   : Path to the data file.
  --output-file <path> : Path to the output file.
  --test               : Test if platform is setup correctly and exit.
  --help               : Display this help and exit.
EndOfHelp
}

############################################################
###                       START                          ###
############################################################

trap Clean EXIT
trap Failure HUP INT QUIT TERM

#-----------------------------------------------------------
# Parse command line arguments.
#-----------------------------------------------------------

while [[ $# -gt 0 ]]
do
case "${1}" in
  --help) Help; Success;;
  --test) declare -r Test=1;;
  --seed-file=*) SeedFile=${1#*=}; ValidateInputFile "${1%%=*}" "${SeedFile}";;
  --seed-file) SeedFile=${2-''}; ValidateInputFile "${1}" "${SeedFile}"; shift;;
  --data-file=*) DataFile=${1#*=}; ValidateInputFile "${1%%=*}" "${DataFile}";;
  --data-file) DataFile=${2-''}; ValidateInputFile "${1}" "${DataFile}"; shift;;
  --output-file=*) OutputFile=${1#*=}; ValidatOutputFile "${1%%=*}" "${OutputFile}";;
  --output-file) OutputFile=${2-''}; ValidatOutputFile "${1}" "${OutputFile}"; shift;;
  *) Failure "Invalid argument: \"${1}\" : Not supported!";;
esac
shift
done

declare -r SeedFile=${SeedFile:-"${ScriptRoot}/data/iso/auto-seed"}
declare -r DataFile=${DataFile:-"${ScriptRoot}/data/iso/auto-data"}
declare -r OutputFile=${OutputFile:-"${PWD}/$(date '+auto-debian-%s.iso')"}

#-----------------------------------------------------------
# Check preconditions.
#-----------------------------------------------------------

if [[ "${Platform}" == 'darwin' ]] || [[ "${Platform}" == 'linux' ]]; then
  command -v 'xorriso' >/dev/null 2>&1  \
    || Failure 'Program "xorriso" is not installed!'
else
  Failure 'Platform is not supported!'
fi

if [[ "${Test:-0}" != 0 ]]; then
  Success 'Platform is setup correctly!'
fi

#-----------------------------------------------------------
echo '[1/5] Downloading ISO file.'
#-----------------------------------------------------------

if [[ "${Platform}" == 'darwin' ]]; then
  SourceISOInfo=$(curl -s -f -L "${SourceISOURL}SHA512SUMS") \
    || Failure 'Cannot find ISO file!' \
  declare -r SourceISOInfo
else
  SourceISOInfo=$(wget -q -O- "${SourceISOURL}SHA512SUMS") \
    || Failure 'Cannot find ISO file!'
  declare -r SourceISOInfo
fi

SourceISOHash=$(echo -n "${SourceISOInfo}" | grep -E "${SourceISOPattern}" | awk '{print $1}')
declare -r SourceISOHash

SourceISOName=$(echo -n "${SourceISOInfo}" | grep -E "${SourceISOPattern}" | awk '{print $2}')
declare -r SourceISOName

if [[ "${Platform}" == 'darwin' ]]; then
  if curl -s -f -L -o "${SourceISOFile}" "${SourceISOURL}${SourceISOName}"; then
    chmod 400 "${SourceISOFile}"
  else
    Failure 'ISO download failed!'
  fi
  DownloadedISOHash=$(shasum -a 512 "${SourceISOFile}" | awk '{print $1}')
  declare -r DownloadedISOHash
else
  if wget -q -O "${SourceISOFile}" "${SourceISOURL}${SourceISOName}"; then
    chmod 400 "${SourceISOFile}"
  else
    Failure 'ISO download failed!'
  fi
  DownloadedISOHash=$(sha512sum "${SourceISOFile}" | awk '{print $1}')
  declare -r DownloadedISOHash
fi

if [[ "${SourceISOHash}" != "${DownloadedISOHash}" ]]; then
  Failure 'Downloaded ISO is corrupted!'
fi

echo " - Source ISO File : ${SourceISOURL}${SourceISOName}"
echo " - Source ISO Hash : ${SourceISOHash}"

#-----------------------------------------------------------
echo '[2/5] Extracting ISO content.'
#-----------------------------------------------------------

mkdir -p "${CustomISOData}" && chmod 700 "${CustomISOData}"
xorriso -osirrox on -indev "${SourceISOFile}" -extract / "${CustomISOData}" >/dev/null 2>&1

#-----------------------------------------------------------
echo '[3/5] Updating ISO content.'
#-----------------------------------------------------------

declare -r ScriptISOData="${ScriptRoot}/data/iso"
declare -r BootFlags='auto=true file=/cdrom/auto-seed'

pushd "${CustomISOData}"
cp "${SeedFile}" 'auto-seed' && chmod 444 'auto-seed'
cp "${DataFile}" 'auto-data' && chmod 444 'auto-data'
popd

pushd "${CustomISOData}/boot/grub"
chmod u+w 'grub.cfg'
sed "s:{{FLAGS}}:${BootFlags}:g" "${ScriptISOData}/boot/grub/grub.cfg" >| 'grub.cfg'
chmod u-w 'grub.cfg'
popd

pushd "${CustomISOData}/isolinux"
chmod u+w 'isolinux.cfg'
sed "s:{{FLAGS}}:${BootFlags}:g" "${ScriptISOData}/isolinux/isolinux.cfg" >| 'isolinux.cfg'
chmod u-w 'isolinux.cfg'
popd

pushd "${CustomISOData}"
chmod u+w 'md5sum.txt'
rm 'debian' 'md5sum.txt'
find . -type f -follow | while IFS='' read -r File
do
  if [[ "${Platform}" == 'darwin' ]]; then
    md5 -r "${File}" >> 'md5sum.txt'
  else
    md5sum "${File}" >> 'md5sum.txt'
  fi
done
chmod u-w 'md5sum.txt'
ln -s '.' 'debian'
popd

#-----------------------------------------------------------
echo '[4/5] Recreating ISO file.'
#-----------------------------------------------------------

pushd "${CustomISOData}"
xorriso -as mkisofs \
  -joliet \
  -rational-rock \
  -no-emul-boot \
  -boot-info-table \
  -boot-load-size 4 \
  -eltorito-catalog 'isolinux/boot.cat' \
  -eltorito-boot 'isolinux/isolinux.bin' \
  -volid "$(basename "${CustomISOFile}")" \
  -output "${CustomISOFile}" '.' >/dev/null 2>&1 \
    || Failure 'Cannot recreate ISO file!'
popd

#-----------------------------------------------------------
echo '[5/5] Saving ISO file.'
#-----------------------------------------------------------

mv "${CustomISOFile}" "${OutputFile}"
if [[ "${Platform}" == 'darwin' ]]; then
  OutputHash=$(shasum -a 512 "${OutputFile}" | awk '{print $1}')
  declare -r OutputHash
else
  OutputHash=$(sha512sum "${OutputFile}" | awk '{print $1}')
  declare -r OutputHash
fi

echo " - Output ISO File : ${OutputFile}"
echo " - Output ISO Hash : ${OutputHash}"
Success 'Done!'
