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

# --- Install Zen Browser (official binary release, no repo/COPR needed) ---

ZEN_VERSION=$(curl -s https://api.github.com/repos/zen-browser/desktop/releases/latest | grep '"tag_name"' | cut -d '"' -f4)

if [ -z "$ZEN_VERSION" ]; then
  echo "ERROR: Failed to resolve latest Zen Browser version (GitHub API rate-limited or unreachable)"
  exit 1
fi

curl -Lfo /tmp/zen.tar.bz2 "https://github.com/zen-browser/desktop/releases/download/${ZEN_VERSION}/zen.linux-x86_64.tar.bz2"

mkdir -p /opt/zen-browser
tar -xjf /tmp/zen.tar.bz2 -C /opt/zen-browser --strip-components=1
rm /tmp/zen.tar.bz2

ln -sf /opt/zen-browser/zen /usr/bin/zen

cat <<'EOF' > /usr/share/applications/zen-browser.desktop
[Desktop Entry]
Name=Zen Browser
Comment=Experience tranquillity while browsing the internet
Exec=/opt/zen-browser/zen %u
Icon=/opt/zen-browser/browser/chrome/icons/default/default128.png
Terminal=false
Type=Application
MimeType=text/html;text/xml;application/xhtml+xml;x-scheme-handler/http;x-scheme-handler/https;
Categories=Network;WebBrowser;
StartupNotify=true
StartupWMClass=zen
EOF

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

NERD_FONT_VERSION=$(curl -s https://api.github.com/repos/ryanoasis/nerd-fonts/releases/latest | grep '"tag_name"' | cut -d '"' -f4)

if [ -z "$NERD_FONT_VERSION" ]; then
  echo "ERROR: Failed to resolve latest Nerd Fonts version (GitHub API rate-limited or unreachable)"
  exit 1
fi

curl -Lfo /tmp/JetBrainsMono.zip "https://github.com/ryanoasis/nerd-fonts/releases/download/${NERD_FONT_VERSION}/JetBrainsMono.zip"

mkdir -p /usr/share/fonts/jetbrainsmono-nerd-font
unzip -o /tmp/JetBrainsMono.zip -d /usr/share/fonts/jetbrainsmono-nerd-font
rm /tmp/JetBrainsMono.zip

find /usr/share/fonts/jetbrainsmono-nerd-font -iname "*Windows Compatible*" -delete

fc-cache -f

# Multimedia Codecs
# --- Multimedia codecs (RPM Fusion) ---

# Swap Fedora's patent-restricted ffmpeg-free for RPM Fusion's full ffmpeg
dnf5 swap -y ffmpeg-free ffmpeg --allowerasing

# Upgrade multimedia group to pull in full codec support (excludes GStreamer's
# own limited plugin sets that ship in the base group)
dnf5 group upgrade -y multimedia --setopt="install_weak_deps=False" \
  --exclude="PackageKit-gstreamer-plugin" --exclude="gstreamer1-plugins-bad-free-gtk" --exclude="gstreamer1-plugins-bad-free-fluidsynth"

# Full GStreamer plugin sets (good/bad/ugly + libav) for broad format support
dnf5 install -y \
  gstreamer1-plugins-{bad-\*,good-\*,base} \
  gstreamer1-plugin-openh264 \
  gstreamer1-libav \
  --exclude=gstreamer1-plugins-bad-free-devel

# Sound group upgrade (same pattern, for audio codec completeness)
dnf5 group upgrade -y sound-and-video

#### Example for enabling a System Unit File

systemctl enable podman.socket
