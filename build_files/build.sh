#!/bin/bash

set -ouex pipefail

# Copy the contents of system_files/ of the git repo to /
cp -avf "/ctx/system_files"/. /

### Install packages

# Packages can be installed from any enabled yum repo on the image.
# RPMfusion repos are available by default in ublue main images
# List of rpmfusion packages can be found here:
# https://mirrors.rpmfusion.org/mirrorlist?path=free/fedora/updates/43/x86_64/repoview/index.html&protocol=https&redirect=1

### Install minimal KDE Plasma

dnf5 install -y \
  plasma-desktop \
  plasma-workspace \
  sddm \
  kwin \
  konsole \
  dolphin \
  plasma-nm \
  plasma-pa \
  xdg-desktop-portal-kde

# Enable the display manager so it boots to KDE login
systemctl enable sddm.service

# Visual Studio Code

# Import Microsoft's GPG key
rpm --import https://packages.microsoft.com/keys/microsoft.asc

# Add the VS Code repo
cat <<'EOF' > /etc/yum.repos.d/vscode.repo
[code]
name=Visual Studio Code
baseurl=https://packages.microsoft.com/yumrepos/vscode
enabled=1
gpgcheck=1
gpgkey=https://packages.microsoft.com/keys/microsoft.asc
EOF

# Brave

# --- Add Brave repo ---
rpm --import https://brave-browser-rpm-release.s3.brave.com/brave-core.asc

cat <<'EOF' > /etc/yum.repos.d/brave-browser.repo
[brave-browser]
name=Brave Browser
baseurl=https://brave-browser-rpm-release.s3.brave.com/x86_64/
enabled=1
gpgcheck=1
gpgkey=https://brave-browser-rpm-release.s3.brave.com/brave-core.asc
EOF

# --- Add Google Chrome repo ---

# Import Google's GPG key (was missing — required since gpgcheck=1 below,
# otherwise dnf5 either hangs on a prompt or fails signature verification
# in a non-interactive build)
rpm --import https://dl.google.com/linux/linux_signing_key.pub

cat <<'EOF' > /etc/yum.repos.d/google-chrome.repo
[google-chrome]
name=google-chrome
baseurl=https://dl.google.com/linux/chrome/rpm/stable/x86_64
enabled=1
gpgcheck=1
gpgkey=https://dl.google.com/linux/linux_signing_key.pub
EOF

# Install browsers + fedora-repo packages in one dnf5 call
# (fixed: brave-origin -> brave-browser; dnf -> dnf5 for consistency)
dnf5 install -y \
  mpv fastfetch zsh unzip \
  code \
  brave-origin \
  google-chrome-stable

# Ghostty (COPR — not yet in Fedora main repos on this release)
# fixed: dnf -> dnf5, and disable the COPR after install
dnf5 -y copr enable scottames/ghostty
dnf5 install -y ghostty
dnf5 -y copr disable scottames/ghostty

# GCC / build tools
dnf5 install -y \
  gcc \
  gcc-c++ \
  make \
  automake \
  autoconf \
  binutils \
  bison \
  flex \
  gdb \
  glibc-devel \
  libtool \
  pkgconf \
  pkgconf-pkg-config \
  redhat-rpm-config \
  rpm-build \
  patch \
  ccache

# LLVM (fixed: dnf -> dnf5)
dnf5 install -y llvm clang lld lldb compiler-rt libomp libomp-devel llvm-devel clang-devel

#Flatpak
# Ensure Flathub remote is configured system-wide (for first-boot Zen install)
flatpak remote-add --if-not-exists --system flathub https://flathub.org/repo/flathub.flatpakrepo

# --- Install JetBrains Toolbox (official binary, no repo available) ---

curl -Lfo /tmp/jetbrains-toolbox.tar.gz "https://data.services.jetbrains.com/products/download?platform=linux&code=TBA"

mkdir -p /opt/jetbrains-toolbox
tar -xzf /tmp/jetbrains-toolbox.tar.gz -C /opt/jetbrains-toolbox --strip-components=1
rm /tmp/jetbrains-toolbox.tar.gz

ln -sf /opt/jetbrains-toolbox/jetbrains-toolbox /usr/bin/jetbrains-toolbox

cat <<'EOF' > /usr/share/applications/jetbrains-toolbox.desktop
[Desktop Entry]
Name=JetBrains Toolbox
Comment=Manage your JetBrains IDEs
Exec=/opt/jetbrains-toolbox/jetbrains-toolbox
Icon=/opt/jetbrains-toolbox/toolbox.svg
Terminal=false
Type=Application
Categories=Development;
StartupNotify=true
EOF

# Python (fixed: removed unnecessary/risky 'sudo' — build.sh already runs as root)
dnf5 install -y python3 python3-devel python3-pip python3-tkinter

# Distrobox
dnf5 install -y distrobox

# Doom Emacs
# --- Install Emacs + Doom Emacs dependencies ---
# Doom itself is a git-cloned config framework, not a package — installed
# at first boot below. This just gets Emacs + the tools Doom needs onto the image.
dnf5 install -y emacs git ripgrep fd-find

# --- Install JetBrainsMono Nerd Font ---
curl -fsSL https://github.com/terrapkg/subatomic-repos/raw/main/terra.repo -o /etc/yum.repos.d/terra.repo

dnf5 install -y terra-release

dnf5 install -y jetbrainsmono-nerd-fonts

# RPM-Fusion
dnf install \
 https://download1.rpmfusion.org/free/fedora/rpmfusion-free-release-$(rpm -E %fedora).noarch.rpm

 dnf install \
 https://download1.rpmfusion.org/nonfree/fedora/rpmfusion-nonfree-release-$(rpm -E %fedora).noarch.rpm

# Multimedia Codecs
dnf install @multimedia --setopt="install_weak_deps=False" --exclude=PackageKit-gstreamer-plugin

dnf install gstreamer1-plugin-openh264 mozilla-openh264

dnf swap ffmpeg-free ffmpeg --allowerasing

dnf install intel-media-driver

#### Example for enabling a System Unit File

systemctl enable podman.socket
