# Docker-Local Installation

## Linux

Tested on Ubuntu 22.04+, Debian 12+, Fedora 38+, and Arch Linux.

```bash
# 1. Install Docker (if not already installed)
curl -fsSL https://get.docker.com | sh
sudo usermod -aG docker $USER
newgrp docker

# 2. Install PHP and Composer (Ubuntu/Debian)
sudo apt update
sudo apt install php8.3 php8.3-{cli,curl,mbstring,xml,zip} unzip
curl -sS https://getcomposer.org/installer | php
sudo mv composer.phar /usr/local/bin/composer

# 3. Install docker-local
composer global require mwguerra/docker-local

# 4. Add Composer bin to PATH (add to ~/.bashrc or ~/.zshrc)
export PATH="$HOME/.composer/vendor/bin:$PATH"

# 5. Reload shell and run setup
source ~/.bashrc  # or source ~/.zshrc
docker-local init

# 6. (Optional) Configure DNS for *.test domains
sudo docker-local setup:dns
```

## macOS

Tested on macOS 12 (Monterey) and later.

```bash
# 1. Install Homebrew (if not already installed)
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"

# 2. Install Docker Desktop
brew install --cask docker
# Launch Docker Desktop from Applications

# 3. Install PHP and Composer
brew install php composer

# 4. Install docker-local
composer global require mwguerra/docker-local

# 5. Add Composer bin to PATH (add to ~/.zshrc)
export PATH="$HOME/.composer/vendor/bin:$PATH"

# 6. Reload shell and run setup
source ~/.zshrc
docker-local init

# 7. (Optional) Configure DNS for *.test domains
sudo docker-local setup:dns
```

## Windows (WSL2)

**Important:** docker-local requires WSL2 on Windows. Native Windows is not supported.

### Step 1: Install WSL2

```powershell
# Run in PowerShell as Administrator
wsl --install -d Ubuntu
```

Restart your computer when prompted.

### Step 2: Install Docker Desktop

1. Download [Docker Desktop for Windows](https://www.docker.com/products/docker-desktop/)
2. During installation, ensure "Use WSL 2 based engine" is checked
3. After installation, go to Settings > Resources > WSL Integration
4. Enable integration with your Ubuntu distribution

### Step 3: Install docker-local (in WSL2 Ubuntu)

```bash
# Open Ubuntu from Start Menu, then run:

# Install PHP and Composer
sudo apt update
sudo apt install php8.3 php8.3-{cli,curl,mbstring,xml,zip} unzip
curl -sS https://getcomposer.org/installer | php
sudo mv composer.phar /usr/local/bin/composer

# Install docker-local
composer global require mwguerra/docker-local

# Add to PATH (add to ~/.bashrc)
echo 'export PATH="$HOME/.composer/vendor/bin:$PATH"' >> ~/.bashrc
source ~/.bashrc

# Run setup
docker-local init

# (Optional) Configure DNS
sudo docker-local setup:dns
```

### Accessing Projects from Windows

Your WSL2 projects are accessible in Windows Explorer at:
```
\\wsl$\Ubuntu\home\<username>\projects
```

Or in VS Code:
```bash
# From WSL2 terminal
code ~/projects/my-project
```

## Updating Docker-Local

```bash
# Update CLI
composer global update mwguerra/docker-local

# Update Docker images
docker-local update

# Or combined
docker-local self-update
```
