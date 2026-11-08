#!/usr/bin/env bash
# Requirements: install real KDE Plasma X11 into a proven Armbian Bookworm ARM64
# s905x3-2101 / kernel 6.12.116 disk image for X96 MAX+ 2101W 4GB/64GB.
# Unknowns: exact 2101W DTB, HDMI, acceleration, USB, JL2101, W522A and
# eMMC remain untested; this is an external-boot candidate only.
# Research: image's original partition table, apt availability, actual USB
# boot and SDDM once a separately authorized hardware test is approved.
# Risks: old first-boot credentials, chroot package hooks, mount cleanup,
# insufficient disk, or GUI unsupported by kernel graphics drivers.
# Verification: source gzip, DOS partition structure, native arm64 dpkg,
# real KDE packages and SDDM, rootfs fsck, output gzip. No device writes.
set -euo pipefail

if (( EUID != 0 )) || [[ "$(uname -m)" != aarch64 ]]; then
  echo "Requires an isolated ARM64 GitHub runner with root access." >&2
  exit 1
fi
if (( $# != 3 )) || [[ "$3" != 42480891440 ]]; then
  echo "Usage: $0 ORIGINAL.img.gz OUTPUT_DIR 42480891440" >&2
  exit 2
fi
case "$(basename -- "$1")" in
  Armbian_26.11.0_amlogic_s905x3-2101_bookworm_6.12.116_server_*.img.gz) ;;
  *) echo "Unexpected stock-derived Armbian source filename." >&2; exit 1 ;;
esac

readonly INPUT="$(realpath "$1")"
readonly OUTPUT="$(realpath -m "$2")"
readonly WORK="$(mktemp -d "${RUNNER_TEMP:-/tmp}/armbian-kde.XXXXXXXX")"
readonly RAW="${WORK}/Armbian_26.11.0_amlogic_s905x3-2101_bookworm_6.12.116_kde-plasma_x11.img"
readonly ROOT="${WORK}/rootfs"
LOOP=""
ROOT_MOUNTED=0
RESOLV_SAVED=0
POLICY_SAVED=0

restore_guest_files() {
  if (( ROOT_MOUNTED == 0 )); then return; fi
  rm -f "${ROOT}/usr/sbin/policy-rc.d"
  if (( POLICY_SAVED )); then
    mv -f "${ROOT}/usr/sbin/policy-rc.d.original-kde" "${ROOT}/usr/sbin/policy-rc.d"
    POLICY_SAVED=0
  fi
  rm -f "${ROOT}/etc/resolv.conf"
  if (( RESOLV_SAVED )); then
    mv -f "${ROOT}/etc/resolv.conf.original-kde" "${ROOT}/etc/resolv.conf"
    RESOLV_SAVED=0
  fi
}
cleanup() {
  local rc="$?"
  trap - EXIT
  set +e
  if (( ROOT_MOUNTED )); then
    restore_guest_files
    for dir in run sys proc dev; do
      mountpoint -q "${ROOT}/${dir}" && umount -R "${ROOT}/${dir}"
    done
    umount "${ROOT}"
  fi
  [[ -n "${LOOP}" ]] && losetup -d "${LOOP}"
  if (( rc == 0 )); then
    rm -rf -- "${WORK}"
  else
    echo "KDE image job failed with exit ${rc}; retained workspace: ${WORK}" >&2
  fi
  exit "${rc}"
}
trap cleanup EXIT

mkdir -p "${OUTPUT}" "${ROOT}"
gzip -t "${INPUT}"
available="$(df -Pk "${WORK}" | awk 'END {print $4}')"
if (( available < 16 * 1024 * 1024 )); then
  echo "Require at least 16 GiB free for rootfs expansion and KDE." >&2
  exit 1
fi
gzip -dc "${INPUT}" > "${RAW}"
python3 - "${RAW}" <<'PY'
import json
import subprocess
import sys
layout = json.loads(subprocess.check_output(["sfdisk", "--json", sys.argv[1]], text=True))
table = layout["partitiontable"]
parts = table["partitions"]
if table.get("label") != "dos" or len(parts) != 2:
    raise SystemExit("Expected original MBR with exactly boot and root partitions")
if str(parts[1].get("type", "")).lower().removeprefix("0x") != "83":
    raise SystemExit("Expected Linux second partition; refusing to modify image")
if parts[1]["start"] <= parts[0]["start"] + parts[0]["size"] - 1:
    raise SystemExit("Overlapping original partition ranges")
print("Original partition layout:", parts)
PY

# A 10-GiB *sparse file* supports Plasma; it is not the 64-GiB device eMMC.
truncate -s 10G "${RAW}"
parted -s "${RAW}" resizepart 2 100%
LOOP="$(losetup --find --show --partscan "${RAW}")"
udevadm settle
ROOT_PART="${LOOP}p2"
[[ -b "${ROOT_PART}" ]] || { echo "Missing loop root partition" >&2; exit 1; }
e2fsck -pf "${ROOT_PART}" || {
  rc=$?
  (( rc == 1 )) || exit "${rc}"
}
resize2fs "${ROOT_PART}"
mount "${ROOT_PART}" "${ROOT}"
ROOT_MOUNTED=1

grep -q '^VERSION_CODENAME=bookworm' "${ROOT}/etc/os-release" ||
  { echo "Not Debian Bookworm" >&2; exit 1; }
[[ "$(chroot "${ROOT}" dpkg --print-architecture)" == arm64 ]] ||
  { echo "Source rootfs is not ARM64" >&2; exit 1; }
[[ -f "${ROOT}/etc/armbian-release" ]] ||
  { echo "Not an Armbian rootfs" >&2; exit 1; }

for d in dev proc sys run; do mkdir -p "${ROOT}/${d}"; done
mount --rbind /dev "${ROOT}/dev"
mount --make-rslave "${ROOT}/dev"
mount -t proc proc "${ROOT}/proc"
mount --rbind /sys "${ROOT}/sys"
mount --make-rslave "${ROOT}/sys"
mount -t tmpfs -o mode=0755,nosuid,nodev tmpfs "${ROOT}/run"

if [[ -e "${ROOT}/etc/resolv.conf" || -L "${ROOT}/etc/resolv.conf" ]]; then
  mv "${ROOT}/etc/resolv.conf" "${ROOT}/etc/resolv.conf.original-kde"
  RESOLV_SAVED=1
fi
cp -L /etc/resolv.conf "${ROOT}/etc/resolv.conf"
if [[ -e "${ROOT}/usr/sbin/policy-rc.d" ]]; then
  mv "${ROOT}/usr/sbin/policy-rc.d" "${ROOT}/usr/sbin/policy-rc.d.original-kde"
  POLICY_SAVED=1
fi
printf '#!/bin/sh\nexit 101\n' > "${ROOT}/usr/sbin/policy-rc.d"
chmod 0755 "${ROOT}/usr/sbin/policy-rc.d"

# Install packages for the guest system; prohibit starting guest daemons
# during build. Use X11 to avoid assuming Wayland GPU/DRM support.
chroot "${ROOT}" /bin/sh -c \
  'printf "sddm shared/default-x-display-manager select sddm\n" | debconf-set-selections'
chroot "${ROOT}" env DEBIAN_FRONTEND=noninteractive APT_LISTCHANGES_FRONTEND=none \
  apt-get update
chroot "${ROOT}" env DEBIAN_FRONTEND=noninteractive APT_LISTCHANGES_FRONTEND=none \
  apt-get install -y --no-install-recommends \
  kde-plasma-desktop sddm xserver-xorg xserver-xorg-video-fbdev xinit \
  plasma-nm konsole dolphin dbus-x11 fonts-noto-core fonts-noto-cjk \
  libgl1-mesa-dri network-manager

printf '%s\n' /usr/bin/sddm > "${ROOT}/etc/X11/default-display-manager"
systemctl --root="${ROOT}" set-default graphical.target
systemctl --root="${ROOT}" enable sddm.service

for pkg in kde-plasma-desktop sddm xserver-xorg plasma-nm konsole dolphin; do
  status="$(chroot "${ROOT}" dpkg-query -W -f='${Status}' "${pkg}")"
  [[ "${status}" == 'install ok installed' ]] ||
    { echo "KDE package missing: ${pkg} (${status})" >&2; exit 1; }
done
[[ -f "${ROOT}/usr/share/xsessions/plasma.desktop" ]] ||
  { echo "Plasma X11 session missing" >&2; exit 1; }
[[ -x "${ROOT}/usr/bin/sddm" ]] ||
  { echo "SDDM executable missing" >&2; exit 1; }
[[ "$(systemctl --root="${ROOT}" get-default)" == graphical.target ]] ||
  { echo "graphical.target not selected" >&2; exit 1; }
[[ -L "${ROOT}/etc/systemd/system/display-manager.service" ]] ||
  { echo "SDDM not enabled" >&2; exit 1; }

mkdir -p "${ROOT}/usr/local/share/x96-2101w"
cat > "${ROOT}/usr/local/share/x96-2101w/KDE-BUILD-NOTES.txt" <<'EOF'
KDE Plasma X11 on Armbian Bookworm ARM64, kernel 6.12.116.
Experimental S905X3 / s905x3-2101 candidate for X96 MAX+ 2101W
(4 GiB RAM / 64 GiB internal eMMC).
Original server image: GitHub Actions Run 42480891440.
KDE was installed within the ARM64 image before compression.
Factory Android eMMC is NOT modified by this build.
HDMI, graphics acceleration, JL2101 1000Mbps, W522A, USB HID and
2101W-specific Device Tree are not hardware validated.
Create the initial non-root account using Armbian first-login
provisioning on a console before expecting SDDM user login.
EOF
chroot "${ROOT}" apt-get clean
rm -rf "${ROOT}/var/lib/apt/lists/"*
sync
restore_guest_files
for d in run sys proc dev; do umount -R "${ROOT}/${d}"; done
umount "${ROOT}"
ROOT_MOUNTED=0
# Read-only fsck after complete shutdown of all image runtime mounts.
e2fsck -fn "${ROOT_PART}"
losetup -d "${LOOP}"
LOOP=""

DEST="${OUTPUT}/$(basename "${RAW}").gz"
[[ ! -e "${DEST}" ]] || { echo "Refusing overwrite" >&2; exit 1; }
pigz -6 -p 4 -c "${RAW}" > "${DEST}"
gzip -t "${DEST}"
python3 - "${RAW}" "${OUTPUT}/kde-image-manifest.json" <<'PY'
import json
import subprocess
import sys
from pathlib import Path
image, dest = Path(sys.argv[1]), Path(sys.argv[2])
parts = json.loads(subprocess.check_output(["sfdisk", "--json", str(image)], text=True))["partitiontable"]["partitions"]
payload = {
 "state": "KDE installed and statically validated; hardware not tested",
 "source_run": 42480891440,
 "device": "X96 MAX+ 2101W, 4GiB RAM/64GiB eMMC",
 "board": "ophub s905x3-2101 (2101W custom DTB not yet validated)",
 "kernel": "6.12.116",
 "os": "Debian Bookworm ARM64",
 "desktop": "KDE Plasma X11, SDDM, Konsole, Dolphin",
 "image_bytes": image.stat().st_size,
 "partitions": parts,
 "hardware_boot_validated": False,
 "emmc_written": False,
}
dest.write_text(json.dumps(payload, ensure_ascii=False, indent=2) + "\n")
print(json.dumps(payload, ensure_ascii=False, indent=2))
PY
ls -lh "${DEST}" "${OUTPUT}/kde-image-manifest.json"
