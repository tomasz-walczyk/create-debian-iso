#
# Copyright (C) 2020 Tomasz Walczyk
#
# This software may be modified and distributed under the terms
# of the MIT license. See the LICENSE file for details.
#
###########################################################

<#
.SYNOPSIS
  Script for creating unattended Debian installer.
.DESCRIPTION
  Script will create Debian installer from the latest minimal CD available.
  If -SeedFile argument was not specified then default seed file will be used.
  If -DataFile argument was not specified then default data file will be used.
  ISO will be saved to the script directory unless -OutputFile was provided.
.INPUTS
  None.
.OUTPUTS
  None.
#>
[CmdletBinding(PositionalBinding=$False)]
param (
  # Path to the seed file.
  [Parameter()]
  [ValidateScript({
    $Path=$ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($_)
    return Test-Path $Path -PathType Leaf
  })]
  [String]
  $SeedFile=$(Join-Path $PSScriptRoot 'data/iso/auto-seed'),

  # Path to the data file.
  [Parameter()]
  [ValidateScript({
    $Path=$ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($_)
    return Test-Path $Path -PathType Leaf
  })]
  [String]
  $DataFile=$(Join-Path $PSScriptRoot 'data/iso/auto-data'),

  # Path to the output file.
  [Parameter()]
  [ValidateScript({
    $Path=$ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($_)
    return (Split-Path $Path | Test-Path -PathType Container) -and !(Test-Path $Path)
  })]
  [String]
  $OutputFile=$(Join-Path $PWD $(Get-Date -UFormat "auto-debian-%s.iso"))
)

###########################################################

Set-StrictMode -Version Latest

###########################################################

# Regular expression used for selecting correct Debian ISO file.
$SourceISOPattern='(debian-)[0-9\.]+(-).+(-netinst.iso)'

# URL pointing to the directory from which Debian ISO should be downloaded.
$SourceISOURL='https://cdimage.debian.org/debian-cd/current/amd64/iso-cd/'

###########################################################

$TemporaryDir=New-Item -Type Directory -Path $(Join-Path $ENV:TEMP $(New-Guid))
$SourceISOFile=Join-Path ${TemporaryDir} 'source.iso'
$CustomISOFile=Join-Path ${TemporaryDir} 'custom.iso'
$CustomISOData=Join-Path ${TemporaryDir} 'custom'

###########################################################

try
{
  #------------------------------------------------------
  Write-Host '[1/5] Downloading ISO file.'
  #------------------------------------------------------

  $SourceISOInfo=$(New-Object System.Net.WebClient).DownloadString($SourceISOURL + 'SHA512SUMS')
  $SourceISOInfo=$SourceISOInfo.Split("`n") | Where-Object { $_ -Match $SourceISOPattern } | Select-Object -First 1

  $SourceISOHash=$SourceISOInfo | ForEach-Object { $_.Split(' ') } | Select-Object -First 1
  $SourceISOName=$SourceISOInfo | ForEach-Object { $_.Split(' ') } | Select-Object -Last 1

  $(New-Object System.Net.WebClient).DownloadFile($SourceISOURL + $SourceISOName, $SourceISOFile)
  if ($(Get-FileHash $SourceISOFile -Algorithm SHA512).Hash.ToLower() -ne $SourceISOHash) {
    throw 'Downloaded ISO is corrupted!'
  }

  Write-Host " - Source ISO File : $SourceISOURL$SourceISOName"
  Write-Host " - Source ISO Hash : $SourceISOHash"

  #------------------------------------------------------
  Write-Host '[2/5] Extracting ISO content.'
  #------------------------------------------------------

  $SourceISOData=$(Mount-DiskImage $SourceISOFile -PassThru | Get-Volume).DriveLetter
  & xcopy $($SourceISOData + ':\*.*') $CustomISOData /EI 2>&1 > $Null
  if ($LastExitCode -ne 0) {
    throw 'Cannot extract ISO content!'
  }
  Dismount-DiskImage $SourceISOFile | Out-Null

  #------------------------------------------------------
  Write-Host '[3/5] Updating ISO content.'
  #------------------------------------------------------

  $ScriptISOData=Join-Path $PSScriptRoot 'data/iso'
  $BootFlags='auto=true priority=critical file=/cdrom/auto-seed'

  Copy-Item $SeedFile $(Join-Path $CustomISOData 'auto-seed')
  Copy-Item $DataFile $(Join-Path $CustomISOData 'auto-data')

  $(Get-Content $(Join-Path $ScriptISOData 'boot/grub/grub.cfg')).replace('{{FLAGS}}', $BootFlags) `
    | Set-Content $(Join-Path $CustomISOData 'boot/grub/grub.cfg')
  $(Get-Content $(Join-Path $ScriptISOData 'isolinux/isolinux.cfg')).replace('{{FLAGS}}', $BootFlags) `
    | Set-Content $(Join-Path $CustomISOData 'isolinux/isolinux.cfg')

  Remove-Item $(Join-Path $CustomISOData 'md5sum.txt')
  $CustomISODataHash=Get-ChildItem $CustomISOData -Recurse `
    | Where-Object { Test-Path $_.FullName -PathType Leaf } | Get-FileHash -Algorithm MD5
  foreach ($Hash in $CustomISODataHash) {
    $Hash.Hash.ToLower() + '  .' + $Hash.Path.Replace($CustomISOData, '').Replace('\', '/') `
      | Out-File $(Join-Path $CustomISOData 'md5sum.txt') -Append
  }

  #------------------------------------------------------
  Write-Host '[4/5] Recreating ISO file.'
  #------------------------------------------------------

  Push-Location $CustomISOData
  $mkisofs=Join-Path $PSScriptRoot 'data/mkisofs/mkisofs.exe'
  & $mkisofs -J -r -no-emul-boot -boot-info-table -boot-load-size 4 -c 'isolinux/boot.cat' -b 'isolinux/isolinux.bin' -o $CustomISOFile '.' 2>&1 > $Null
  if ($LastExitCode -ne 0) {
    throw 'Cannot recreate ISO file!'
  }
  Pop-Location

  #------------------------------------------------------
  Write-Host '[5/5] Saving ISO file.'
  #------------------------------------------------------

  if (-not $(Move-Item $CustomISOFile $OutputFile -PassThru)) {
    throw 'Cannot save ISO file!'
  }

  $OutputHash=$(Get-FileHash $OutputFile -Algorithm SHA512).Hash.ToLower()
  Write-Host " - Output ISO File : $OutputFile"
  Write-Host " - Output ISO Hash : $OutputHash"
  Write-Host 'Done!'
}
catch
{
  Write-Error $_.Exception.Message
}
finally
{
  if (Test-Path $TemporaryDir) {
    if (Test-Path $SourceISOFile) {
      if (Get-DiskImage $SourceISOFile | Get-Volume) {
        Dismount-DiskImage $SourceISOFile
      }
    }
    Remove-Item $TemporaryDir -Recurse
  }
}
