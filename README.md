[![Test](https://github.com/tomasz-walczyk/create-debian-iso/actions/workflows/test.yml/badge.svg)](https://github.com/tomasz-walczyk/create-debian-iso/actions/workflows/test.yml)
[![Release](https://github.com/tomasz-walczyk/create-debian-iso/actions/workflows/release.yml/badge.svg)](https://github.com/tomasz-walczyk/create-debian-iso/actions/workflows/release.yml)
___
Script for creating unattended Debian installer.
___
#### Linux
```bash
# Install dependencies:
sudo apt-get install --assume-yes xorriso

# Create Debian ISO:
bash create-debian-iso.bash
```
#### MacOS
```bash
# Install dependencies:
brew install xorriso

# Create Debian ISO:
bash create-debian-iso.bash
```
#### Windows
```powershell
# Change execution policy:
Set-ExecutionPolicy Bypass -Scope Process

# Create Debian ISO:
powershell .\CreateDebianISO.ps1
```
___
*Copyright (C) 2022 Tomasz Walczyk*<br><br>
*This software may be modified and distributed under the terms of the MIT license.*<br>
*See the [LICENSE](LICENSE) file for details.*<br>
