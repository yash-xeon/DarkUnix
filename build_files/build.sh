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

# # Nvidea
# # --- Install NVIDIA (nvidia-open) drivers via ublue's prebuilt akmods ---
#
# # Kernel modules were pulled in from ghcr.io/ublue-os/akmods-nvidia-open
# # in the Containerfile build stage and copied to /tmp/akmods-rpms
# dnf5 install -y /tmp/akmods-rpms/kmods/*.rpm
#
# # Enable negativo17's nvidia repo for the matching userspace driver packages
# # (akmods only ships the kernel module; userspace libs come from here)
# cat <<'EOF' > /etc/yum.repos.d/negativo17-nvidia.repo
# [negativo17-nvidia]
# name=negativo17 - nvidia
# baseurl=https://negativo17.org/repos/fedora-nvidia/
# enabled=1
# gpgcheck=1
# gpgkey=https://negativo17.org/repos/RPM-GPG-KEY-slaanesh
# EOF

# dnf5 install -y nvidia-driver nvidia-driver-libs nvidia-driver-cuda nvidia-settings
#
# rm /etc/yum.repos.d/negativo17-nvidia.repo
# rm -rf /tmp/akmods-rpms
#
# # Blacklist nouveau and enable DRM modesetting via bootc kargs
# # (this is the bootc-native way to set kernel args baked into the image,
# # replacing the old grubby/kernelopts approach)
# mkdir -p /usr/lib/bootc/kargs.d
# cat <<'EOF' > /usr/lib/bootc/kargs.d/00-nvidia.toml
# kargs = [
#   "rd.driver.blacklist=nouveau",
#   "modprobe.blacklist=nouveau",
#   "nvidia-drm.modeset=1",
# ]
# EOF

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
cat <<'EOF' > /etc/yum.repos.d/google-chrome.repo
[google-chrome]
name=google-chrome
baseurl=https://dl.google.com/linux/chrome/rpm/stable/x86_64
enabled=1
gpgcheck=1
gpgkey=https://dl.google.com/linux/linux_signing_key.pub
EOF

# this installs a package from fedora repos
dnf5 install -y ghostty mpv code brave-origin google-chrome-stable fastfetch zsh

#GCC
dnf groupinstall "Development Tools"

#LLVM
dnf install llvm clang lld lldb compiler-rt libomp libomp-devel llvm-devel clang-devel

# --- Install Zen Browser (official binary release, no repo/COPR needed) ---

# Zen doesn't publish an RPM repo, so we fetch the latest release tag
# directly from GitHub's API instead of hardcoding a version number
ZEN_VERSION=$(curl -s https://api.github.com/repos/zen-browser/desktop/releases/latest | grep '"tag_name"' | cut -d '"' -f4)

# Download the official prebuilt tarball for that version
curl -Lo /tmp/zen.tar.bz2 "https://github.com/zen-browser/desktop/releases/download/${ZEN_VERSION}/zen.linux-x86_64.tar.bz2"

# Extract into /opt (standard location for self-contained third-party apps)
# --strip-components=1 drops the top-level folder from the tarball
mkdir -p /opt/zen-browser
tar -xjf /tmp/zen.tar.bz2 -C /opt/zen-browser --strip-components=1
rm /tmp/zen.tar.bz2

# Symlink the binary onto PATH so 'zen' works from a terminal
ln -sf /opt/zen-browser/zen /usr/bin/zen

# Desktop entry so it shows up in the KDE app launcher with an icon,
# and registers as a handler for http/https links
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

# JetBrains doesn't publish an RPM for Toolbox. This URL always redirects
# to the latest Linux build, so no version number needs to be hardcoded
curl -Lo /tmp/jetbrains-toolbox.tar.gz "https://data.services.jetbrains.com/products/download?platform=linux&code=TBA"

# Extract into /opt (standard location for self-contained third-party apps)
# --strip-components=1 drops the versioned top-level folder from the tarball
mkdir -p /opt/jetbrains-toolbox
tar -xzf /tmp/jetbrains-toolbox.tar.gz -C /opt/jetbrains-toolbox --strip-components=1
rm /tmp/jetbrains-toolbox.tar.gz

# Symlink the binary onto PATH so 'jetbrains-toolbox' works from a terminal
ln -sf /opt/jetbrains-toolbox/jetbrains-toolbox /usr/bin/jetbrains-toolbox

# Desktop entry so it shows up in the KDE app launcher
# Note: Toolbox normally self-registers a .desktop file in ~/.local/share/applications
# on first run, but since this is a system image (not a live user session),
# we provide one system-wide instead so it's visible immediately after boot
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

# Python
sudo dnf install python3 python3-devel python3-pip python3-tkinter

# Distrobox
dnf5 install -y distrobox

# Homebrew
# --- Enable Homebrew (installed on first boot via ublue's brew-setup.service) ---
# Actual installation happens at first boot, not build time — see Bluefin's
# ghcr.io/ublue-os/brew image, copied in via the Containerfile
systemctl enable brew-setup.service

# Doom Emacs
# --- Install Emacs + Doom Emacs dependencies ---
# Doom itself is a git-cloned config framework, not a package — installed
# at first boot below. This just gets Emacs + the tools Doom needs onto the image.
dnf5 install -y emacs git ripgrep fd-find

# Fonts
# --- Install JetBrainsMono Nerd Font ---

NERD_FONT_VERSION=$(curl -s https://api.github.com/repos/ryanoasis/nerd-fonts/releases/latest | grep '"tag_name"' | cut -d '"' -f4)

curl -Lo /tmp/JetBrainsMono.zip "https://github.com/ryanoasis/nerd-fonts/releases/download/${NERD_FONT_VERSION}/JetBrainsMono.zip"

# Unzip into a system-wide fonts directory (not /usr/share/fonts/truetype,
# which is Debian convention — Fedora just uses /usr/share/fonts/<name>)
mkdir -p /usr/share/fonts/jetbrainsmono-nerd-font
unzip -o /tmp/JetBrainsMono.zip -d /usr/share/fonts/jetbrainsmono-nerd-font
rm /tmp/JetBrainsMono.zip

# Drop the .otf variants (keep .ttf only) to avoid duplicate font entries
find /usr/share/fonts/jetbrainsmono-nerd-font -iname "*Windows Compatible*" -delete

# Rebuild the font cache so the fonts are immediately available
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

# Use a COPR Example:
#
# dnf5 -y copr enable ublue-os/staging
# dnf5 -y install package
# Disable COPRs so they don't end up enabled on the final image:
# dnf5 -y copr disable ublue-os/staging

#### Example for enabling a System Unit File

systemctl enable podman.socket
