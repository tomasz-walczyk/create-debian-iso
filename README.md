Script for creating unattended Debian installer.
___
#### Linux
```bash
# Clone Git repository:
git clone 'https://github.com/tomasz-walczyk/create-debian-iso.git'
cd create-debian-iso

# Install required dependencies:
sudo apt-get install genisoimage

# Get help:
bash create-debian-iso.bash --help

# Create Debian ISO using default settings:
sudo bash create-debian-iso.bash
```
#### MacOS
```bash
# Clone Git repository:
git clone 'https://github.com/tomasz-walczyk/create-debian-iso.git'
cd create-debian-iso

# Install required dependencies:
brew install cdrtools

# Get help:
bash create-debian-iso.bash --help

# Create Debian ISO using default settings:
sudo bash create-debian-iso.bash
```
#### Windows
```powershell
# Clone Git repository:
git clone 'https://github.com/tomasz-walczyk/create-debian-iso.git'
Set-Location create-debian-iso

# Allow scripts execution:
Set-ExecutionPolicy Bypass -Scope Process

# Get help:
Get-Help .\CreateDebianISO.ps1 -Full

# Create Debian ISO using default settings:
.\CreateDebianISO.ps1
```
___
*Copyright (C) 2020 Tomasz Walczyk*<br><br>
*This software may be modified and distributed under the terms of the MIT license.*<br>
*See the [LICENSE](LICENSE) file for details.*<br>
