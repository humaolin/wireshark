#!/usr/bin/env bash
set -euo pipefail
export DEBIAN_FRONTEND=noninteractive

# change this to the wireshark tag you want
WIRESHARK_TAG="refs/heads/master"   # 或 "v4.0.0" 之类的稳定 tag

# install build deps (Qt5 可选 — 如果只是 tshark 可以省掉 qt5)
apt-get update
apt-get install -y --no-install-recommends \
  build-essential cmake ninja-build pkg-config git python3 \
  flex bison libglib2.0-dev libpcap-dev libgcrypt20-dev libxml2-dev \
  libzstd-dev liblz4-dev libssl-dev libcap-dev \
  qtbase5-dev qttools5-dev qttools5-dev-tools \
  ca-certificates wget dh-make devscripts lintian sudo

# optional: if you want headless build (no X) for Qt, ensure qmake is present.
# create build dir
mkdir -p build-wireshark
cd build-wireshark

# get source (shallow)
if [ ! -d wireshark ]; then
  git clone --depth 1 https://gitlab.com/wireshark/wireshark.git wireshark
  cd wireshark
  # checkout specific commit/tag if needed:
  # git fetch --tags
  # git checkout tags/v4.0.0 -b build-v4
else
  cd wireshark
  git fetch --depth=1 origin
  git checkout ${WIRESHARK_TAG} || true
fi

# Use CMake + Ninja
mkdir -p build && cd build

# If you only need tshark (CLI), disable GUI to reduce deps:
# cmake .. -G Ninja -DENABLE_GUI=OFF -DCMAKE_BUILD_TYPE=Release -DCMAKE_INSTALL_PREFIX=/usr
cmake .. -G Ninja -DCMAKE_BUILD_TYPE=Release -DCMAKE_INSTALL_PREFIX=/usr

ninja -j$(nproc)

# Install to a temporary dir, then package
DESTDIR=/work/out/wireshark-arm64-buster-root ninja install

# Create a simple tarball of installed files
cd /work/out
tar czf wireshark-arm64-buster-$(date +%Y%m%d%H%M).tar.gz wireshark-arm64-buster-root

# Optionally build a .deb (simple dpkg-deb packaging)
PKGDIR=/work/out/wireshark-deb
mkdir -p ${PKGDIR}/DEBIAN
cat > ${PKGDIR}/DEBIAN/control <<'EOF'
Package: wireshark-custom
Version: 1.0
Section: net
Priority: optional
Architecture: arm64
Maintainer: CI <ci@example.com>
Description: Wireshark custom build (arm64, built on Debian Buster - glibc 2.28)
EOF

# Put installed files into package tree
mkdir -p ${PKGDIR}/usr
cp -a /work/out/wireshark-arm64-buster-root/usr/* ${PKGDIR}/usr/

# fix permissions and build .deb
dpkg-deb --build ${PKGDIR} /work/out/wireshark-arm64-buster.deb || true

# print glibc version for verification
echo "Target glibc version:"
/lib/aarch64-linux-gnu/libc.so.6 || true

echo "build finished. artifacts in /work/out"
