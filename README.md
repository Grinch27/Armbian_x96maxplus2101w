# Armbian · X96 MAX+ 2101W

Experimental Armbian build for **X96 MAX+ 2101W (S905X3, 4 GiB RAM, 64 GiB eMMC)**. **Not boot-tested, not a factory ROM, and not ready for eMMC installation.**

## Upstream-first build strategy

The repository intentionally keeps no forked OpenWrt or Armbian source tree. Each build follows the current upstream **`main`**:

| Purpose | Upstream | How it is used |
| --- | --- | --- |
| 2101/JL2101 hardware mapping and regression reference | [ophub/amlogic-s9xxx-openwrt](https://github.com/ophub/amlogic-s9xxx-openwrt) | Read live `model_database.conf`; fail if the 2101 entry changes unexpectedly |
| Armbian image construction and board mapping | [ophub/amlogic-s9xxx-armbian](https://github.com/ophub/amlogic-s9xxx-armbian) | Use its current `main` composite action and independent model database |
| Kernel and DTB packages | [ophub/kernel](https://github.com/ophub/kernel) | Resolve the latest available version in the selected series |
| Base OS image | [ophub/amlogic-s9xxx-armbian Releases](https://github.com/ophub/amlogic-s9xxx-armbian/releases) | Resolve the latest published Bookworm Server ARM64 `-trunk_` base image |

The current upstream OpenWrt and Armbian databases both describe board **ID 506 / `s905x3-2101`**, with `meson-sm1-x96-max-plus-2101.dtb` and `u-boot-x96maxplus.bin`. Their descriptions refer to a **4 GiB/32 GiB** 2101 configuration, *not* a confirmed 2101W 4 GiB/64 GiB profile. The build checks both repositories at runtime and records their resolved commit SHAs. Upstream changes are *not* silently ported into a custom DTB.

**OpenWrt provides the shared hardware profile and historical diagnostics, not the Armbian root filesystem or build system.** OpenWrt `remake` produces an OpenWrt image and must not substitute for Armbian `rebuild`.

## GitHub Actions

[**Build Armbian 2101W candidate**](https://github.com/Grinch27/Armbian_x96maxplus2101w/actions/workflows/build_armbian.yml)

- **Manual (`workflow_dispatch`)**: one experimental Debian Bookworm Server, ext4, `s905x3-2101` image. The default kernel is **6.12.y**, with 6.18.y, 6.6.y, 5.15.y and 5.10.y available as comparison/diagnostic series.
- **On updates to the workflow**: execute a full experimental build using the default kernel.
- **Daily UTC 06:32 (`schedule`)**: check the latest OpenWrt and Armbian device-profile consistency; no large image is built on the scheduled run.
- **Build result**: validate the compressed target image and upload a **seven-day GitHub Actions artifact only**. **No public Release, Android flash package, bootloader write or hardware operation.**
- **Provenance**: record both upstream commit SHAs and the base-image URL as workflow artifacts/logs. The live `main` refs are deliberately unpinned to track upstream closely, so builds are not intrinsically bit-for-bit reproducible.

Compilation/packaging success means only that an archive with the target board name was generated and gzip-tested. It **does not** mean the 2101W boots or that its network functions correctly.

## Hardware diagnostics: do not assume compatibility

| Component | Community findings | Remaining risk |
| --- | --- | --- |
| S905X3/SM1 | Reported in [Armbian issue #929](https://github.com/ophub/amlogic-s9xxx-armbian/issues/929) | PCB revisions may differ |
| JL2101 1 Gb Ethernet | [OpenWrt issue #333](https://github.com/ophub/amlogic-s9xxx-openwrt/issues/333) describes 100 Mb negotiation/DHCP failures, despite 5.10 or adjusted-U-Boot 5.15 booting | PHY driver, reset, RGMII clock/delays and link partner need hardware tests |
| W522A / Fn-Link K255B-SR Wi-Fi | Community CoreELEC driver `w1-aml` | Not proven available for mainline Armbian; do not confuse with RTL8822CS or QCA9377 |
| AiP1628 display | Identified in issue #929 | No validated display support |
| 64 GiB eMMC | User-reported capacity | Board database lists 32 GiB; eMMC installation is out of scope |

See also the [historical 2101 DTS](https://github.com/unifreq/linux-5.15.y/blob/main/arch/arm64/boot/dts/amlogic/meson-sm1-x96-max-plus-2101.dts), which contains an explicit JL2101 PHY ID comment and RGMII configuration. Its existence does not establish correctness for the actual 2101W PCB.

## Before any physical testing

1. Compare the actual board revision and a read-only stock firmware extraction with the candidate DTB/U-Boot, including MDIO PHY ID, GPIO reset polarity, RGMII mode/timings, SDIO Wi-Fi and MMC layout.
2. Verify recovery access, full backup and a rollback path.
3. Only after explicit separate approval, consider a reversible **SD/USB boot test** with UART logs, Ethernet link/DHCP tests and storage enumeration.
4. Do **not** run `armbian-install`, replace the internal U-Boot, write eMMC, erase partitions or describe the output as device-validated.

**Status:** Actions workflow added; upstream and hardware conclusions documented. A new Actions run is required to establish whether the current upstream image can actually be repackaged successfully.
