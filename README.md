![](https://github.com/tomasz-walczyk/create-debian-iso/workflows/CI/badge.svg?event=push)

Script for creating unattended Debian installer.
___
#### Linux
```bash
# Clone Git repository:
git clone 'https://github.com/tomasz-walczyk/create-debian-iso.git'
cd create-debian-iso

# Install dependencies:
sudo apt-get install --assume-yes xorriso

# Create Debian ISO:
bash create-debian-iso.bash
```
#### MacOS
```bash
# Clone Git repository:
git clone 'https://github.com/tomasz-walczyk/create-debian-iso.git'
cd create-debian-iso

# Install dependencies:
brew install xorriso

# Create Debian ISO:
bash create-debian-iso.bash
```
#### Windows
```powershell
# Clone Git repository:
git clone 'https://github.com/tomasz-walczyk/create-debian-iso.git'
Set-Location create-debian-iso

# Change execution policy:
Set-ExecutionPolicy Bypass -Scope Process

# Create Debian ISO:
powershell .\CreateDebianISO.ps1
```
___
*Copyright (C) 2022 Tomasz Walczyk*<br><br>
*This software may be modified and distributed under the terms of the MIT license.*<br>
*See the [LICENSE](LICENSE) file for details.*<br>
