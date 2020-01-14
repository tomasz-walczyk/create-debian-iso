#!/usr/bin/env bash
#
# Copyright (C) 2020 Tomasz Walczyk
#
# This software may be modified and distributed under the terms
# of the MIT license. See the LICENSE file for details.
#
###########################################################

set -o errexit -o nounset -o pipefail

###########################################################

# Regular expression used for selecting correct Debian ISO file.
readonly SourceISOPattern='(debian-)[0-9\.]+(-).+(-netinst.iso)'

# URL pointing to the directory from which Debian ISO should be downloaded.
readonly SourceISOURL='https://cdimage.debian.org/debian-cd/current/amd64/iso-cd/'

###########################################################

readonly ScriptRoot="$(cd "$(dirname "${0}")" && pwd)"
readonly TemporaryDir=$(mktemp -q -d '/tmp/create-debian-iso.bash.XXXXXXXXXXXXXXXX')
readonly SourceISOFile="${TemporaryDir}/source.iso"
readonly SourceISOData="${TemporaryDir}/source"
readonly CustomISOFile="${TemporaryDir}/custom.iso"
readonly CustomISOData="${TemporaryDir}/custom"
readonly MacOSDeviceID="${TemporaryDir}/device"
readonly Platform=$(uname -s)

###########################################################

pushd() {
  command pushd "$@" > /dev/null
}

#----------------------------------------------------------

popd() {
  command popd "$@" > /dev/null
}

#----------------------------------------------------------

Failure() {
  if [[ $# -ne 0 ]]; then
    echo -e "$@" >&2
  fi
  exit 1
}

#----------------------------------------------------------

Success() {
  if [[ $# -ne 0 ]]; then
    echo -e "$@"
  fi
  exit 0
}

#----------------------------------------------------------

Clean() {
  if [[ -d "${TemporaryDir}" ]]; then
    if mount | grep -q "${SourceISOData}"; then
      umount "${SourceISOData}"
    fi
    if [[ "${Platform}" == 'Darwin' ]] && [[ -e "${MacOSDeviceID}" ]]; then
      hdiutil detach -quiet "$(cat "${MacOSDeviceID}")"
    fi
    rm -R "${TemporaryDir}"
  fi
}

#----------------------------------------------------------

ValidateInputFile() {
  [[ -z "${2}" ]] && Failure "Invalid argument: \"${1}\" : Empty value!"
  [[ "${2:0:1}" != '/' ]] && { local -r Path="${PWD}/${2}"; } || { local -r Path="${2}"; }
  [[ ! -f "${Path}" ]] && Failure "Invalid argument: \"${1}\" : File \"${Path}\" does not exists!"
  [[ ! -r "${Path}" ]] && Failure "Invalid argument: \"${1}\" : File \"${Path}\" is not readable!"
  echo -n "${Path}"
}

#----------------------------------------------------------

ValidatOutputFile() {
  [[ -z "${2}" ]] && Failure "Invalid argument: \"${1}\" : Empty value!"
  [[ "${2:0:1}" != '/' ]] && { local -r Path="${PWD}/${2}"; } || { local -r Path="${2}"; }
  [[ -e "${Path}" ]] && Failure "Invalid argument: \"${1}\" : File \"${Path}\" already exists!"
  [[ ! -e "$(dirname "${Path}")" ]] && Failure "Invalid argument: \"${1}\" : Directory \"$(dirname "${Path}")\" does not exists!"
  [[ ! -w "$(dirname "${Path}")" ]] && Failure "Invalid argument: \"${1}\" : Directory \"$(dirname "${Path}")\" is not writable!"
  echo -n "${Path}"
}

#----------------------------------------------------------

Help() {
cat << EndOfHelp
Synopsis:
  Script for creating unattended Debian installer.

Usage:
  create-debian-iso.bash [OPTION]...

Description:
  Script will create Debian installer from the latest minimal CD available.
  If --seed-file argument was not specified then default seed file will be used.
  If --data-file argument was not specified then default data file will be used.
  ISO will be saved to the script directory unless --output-file was provided.

Options:
  --seed-file    <path> : Path to the seed file.
  --data-file    <path> : Path to the data file.
  --output-file  <path> : Path to the output file.
  --help                : Display this help and exit.
EndOfHelp
}

###########################################################
###                       START                         ###
###########################################################

trap Clean EXIT
trap Failure HUP INT QUIT TERM

#----------------------------------------------------------
# Parse command line arguments.
#----------------------------------------------------------

while [[ $# -gt 0 ]]
do
case "${1}" in
  --help) Help; Success;;
  --seed-file=*) SeedFile=$(ValidateInputFile "${1%%=*}" "${1#*=}");;
  --seed-file) Failure "Invalid argument: \"${1}\" : Empty value!";;
  --data-file=*) DataFile=$(ValidateInputFile "${1%%=*}" "${1#*=}");;
  --data-file) Failure "Invalid argument: \"${1}\" : Empty value!";;
  --output-file=*) OutputFile=$(ValidatOutputFile "${1%%=*}" "${1#*=}");;
  --output-file) Failure "Invalid argument: \"${1}\" : Empty value!";;
  *) Failure "Invalid argument: \"${1}\" : Not supported!";;
esac
shift
done

readonly SeedFile=${SeedFile:-"${ScriptRoot}/data/iso/auto-seed"}
readonly DataFile=${DataFile:-"${ScriptRoot}/data/iso/auto-data"}
readonly OutputFile=${OutputFile:-"${PWD}/$(date '+debian_%Y-%m-%d_%H-%M-%S.iso')"}

#----------------------------------------------------------
# Check preconditions.
#----------------------------------------------------------

if [[ "${EUID}" != 0 ]]; then
  Failure 'You need to run this script as root!'
fi

if [[ "${Platform}" == 'Darwin' ]]; then
  command -v 'mkisofs' >/dev/null 2>&1 \
    || Failure 'Package "cdrtools" is not installed!'
elif [[ "${Platform}" == 'Linux' ]]; then
  command -v 'genisoimage' >/dev/null 2>&1 \
    || Failure 'Package "genisoimage" is not installed!'
else
  Failure 'Platform is not supported!'
fi

#----------------------------------------------------------
echo '[1/5] Downloading ISO file.'
#----------------------------------------------------------

if [[ "${Platform}" == 'Darwin' ]]; then
  readonly SourceISOInfo=$(curl -s -L "${SourceISOURL}SHA512SUMS") \
    || Failure 'Cannot find ISO file!'
else
  readonly SourceISOInfo=$(wget -q -O- "${SourceISOURL}SHA512SUMS") \
    || Failure 'Cannot find ISO file!'
fi

readonly SourceISOHash=$(echo -n "${SourceISOInfo}" | grep -E "${SourceISOPattern}" | awk '{print $1}')
readonly SourceISOName=$(echo -n "${SourceISOInfo}" | grep -E "${SourceISOPattern}" | awk '{print $2}')

if [[ "${Platform}" == 'Darwin' ]]; then
  curl -s -L -o "${SourceISOFile}" "${SourceISOURL}${SourceISOName}" \
    || Failure 'ISO download failed!'

  if [[ "${SourceISOHash}" != "$(shasum -a 512 "${SourceISOFile}" | awk '{print $1}')" ]]; then
    Failure 'Downloaded ISO is corrupted!'
  fi
else
  wget -q -O "${SourceISOFile}" "${SourceISOURL}${SourceISOName}" \
    || Failure 'ISO download failed!'

  if [[ "${SourceISOHash}" != "$(sha512sum "${SourceISOFile}" | awk '{print $1}')" ]]; then
    Failure 'Downloaded ISO is corrupted!'
  fi
fi

echo " - Source ISO File : ${SourceISOURL}${SourceISOName}"
echo " - Source ISO Hash : ${SourceISOHash}"

#----------------------------------------------------------
echo '[2/5] Extracting ISO content.'
#----------------------------------------------------------

mkdir -p "${SourceISOData}" "${CustomISOData}"
if [[ "${Platform}" == 'Darwin' ]]; then
  hdiutil attach -readonly -nomount "${SourceISOFile}" \
    | grep 'Apple_partition_scheme' | awk '{print $1}' > "${MacOSDeviceID}"
  mount -o rdonly -t cd9660 "$(cat "${MacOSDeviceID}")" "${SourceISOData}"
else
  mount -r -o 'loop' "${SourceISOFile}" "${SourceISOData}"
fi
cp -p -R "${SourceISOData}/"* "${CustomISOData}"

#----------------------------------------------------------
echo '[3/5] Updating ISO content.'
#----------------------------------------------------------

readonly ScriptISOData="${ScriptRoot}/data/iso"
readonly BootFlags='auto=true file=/cdrom/auto-seed'

cp "${SeedFile}" "${CustomISOData}/auto-seed"
cp "${DataFile}" "${CustomISOData}/auto-data"

sed "s:{{FLAGS}}:${BootFlags}:g" "${ScriptISOData}/boot/grub/grub.cfg" \
  > "${CustomISOData}/boot/grub/grub.cfg"
sed "s:{{FLAGS}}:${BootFlags}:g" "${ScriptISOData}/isolinux/isolinux.cfg" \
  > "${CustomISOData}/isolinux/isolinux.cfg"

pushd "${CustomISOData}"
rm 'debian'
if [[ "${Platform}" == 'Darwin' ]]; then
  md5 -r $(find . -type f -follow) > 'md5sum.txt'
else
  md5sum $(find . -type f -follow) > 'md5sum.txt'
fi
ln -s '.' 'debian'
popd

#----------------------------------------------------------
echo '[4/5] Recreating ISO file.'
#----------------------------------------------------------

pushd "${CustomISOData}"
if [[ "${Platform}" == 'Darwin' ]]; then
  mkisofs \
    -quiet \
    -joliet \
    -rational-rock \
    -no-emul-boot \
    -boot-info-table \
    -boot-load-size 4 \
    -eltorito-catalog 'isolinux/boot.cat' \
    -eltorito-boot 'isolinux/isolinux.bin' \
    -output "${CustomISOFile}" \
    '.'
else
  genisoimage \
    -quiet \
    -joliet \
    -rational-rock \
    -no-emul-boot \
    -boot-info-table \
    -boot-load-size 4 \
    -eltorito-catalog 'isolinux/boot.cat' \
    -eltorito-boot 'isolinux/isolinux.bin' \
    -output "${CustomISOFile}" \
    '.'
fi
popd

#----------------------------------------------------------
echo '[5/5] Saving ISO file.'
#----------------------------------------------------------

mv "${CustomISOFile}" "${OutputFile}"
if [[ "${Platform}" == 'Darwin' ]]; then
  readonly OutputHash="$(shasum -a 512 "${OutputFile}" | awk '{print $1}')"
else
  readonly OutputHash="$(sha512sum "${OutputFile}" | awk '{print $1}')"
fi

echo " - Output ISO File : ${OutputFile}"
echo " - Output ISO Hash : ${OutputHash}"
Success 'Done!'
