#!/bin/bash

# Update and upgrade system packages
sudo apt update && sudo apt upgrade -y

# Install Ubuntu desktop environment
sudo apt install -y ubuntu-desktop

# Install and configure xRDP for remote desktop access
sudo apt install -y xrdp

sudo chown xrdp:xrdp /etc/xrdp/key.pem
sudo chmod 600 /etc/xrdp/key.pem

sudo systemctl enable --now xrdp

# Set a password for the user (modify as needed)
USERNAME="ubuntu"
PASSWORD="testpassword2025"
echo "$USERNAME:$PASSWORD" | sudo chpasswd

# Confirm xRDP status
sudo systemctl status xrdp --no-pager



# https://docs.docker.com/engine/install/ubuntu/

# Add Docker's official GPG key:
sudo apt-get update
sudo apt-get install ca-certificates curl
sudo install -m 0755 -d /etc/apt/keyrings
sudo curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc
sudo chmod a+r /etc/apt/keyrings/docker.asc

# Add the repository to Apt sources:
echo \
  "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/ubuntu \
  $(. /etc/os-release && echo "${UBUNTU_CODENAME:-$VERSION_CODENAME}") stable" | \
  sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
sudo apt-get update

sudo apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
