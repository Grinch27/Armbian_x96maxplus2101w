# Armbian for X96 MAX+ 2101W

Experimental, **not device-validated**, Armbian image builds for the **X96 MAX+ 2101W** (Amlogic S905X3, 4 GiB RAM, 64 GiB eMMC).

## Hardware and compatibility

The device profile is based on [ophub/amlogic-s9xxx-armbian#929](https://github.com/ophub/amlogic-s9xxx-armbian/issues/929), not a dump from this particular unit:

| Component | Reported 2101W hardware | Validation status |
| --- | --- | --- |
| SoC | S905X3 / SM1 | Community report |
| Board | Q5X3_141 V4.1 20112 | Actual board revision unknown |
| RAM / storage | 4 GiB / 64 GiB eMMC | User-reported capacity |
| Ethernet | JLSemi JL2101, gigabit RGMII | Link negotiation remains a known risk |
| Wireless | W522A / Fn-Link K255B-SR (w1-aml on CoreELEC) | **Not supported/validated by this build** |
| Display | AiP1628 | Not supported/validated by this build |

**Important:** The upstream `s905x3-2101` profile describes a **4 GiB + 32 GiB** device. It selects `meson-sm1-x96-max-plus-2101.dtb`. This profile is a starting point for *offline testing only*, not proof that its DTB, PHY wiring, U-Boot, Wi-Fi or eMMC layout matches the 2101W.

[OpenWrt issue #333](https://github.com/ophub/amlogic-s9xxx-openwrt/issues/333) reports that Linux 5.10 can boot with the generic X96 Max Plus DTB but a JL2101-connected router can negotiate down to 100 Mbit/s or fail at DHCP; Linux 5.15 needed a U-Boot adjustment to boot. Delay-parameter sweeps did not establish a repair. [Armbian issue #929](https://github.com/ophub/amlogic-s9xxx-armbian/issues/929) reports different boot/network results on similar 2101W PCBs and missing W522A Wi-Fi support.

## Build

Go to [Actions → Armbian 2101W candidate](https://github.com/Grinch27/Armbian_x96maxplus2101w/actions/workflows/build_armbian.yml) and run `workflow_dispatch` with the kernel series you want.

- Default: **Debian Bookworm Server**, upstream `s905x3-2101`, `ext4`, Linux `5.10.y` (historical diagnostic baseline).
- Alternative kernel series: `5.15.y`, `6.6.y`, `6.12.y`. Modern kernels require independent hardware verification.
- Input source: a specific 2026-11 upstream Armbian Bookworm ARM64 base image; the reusable upstream rebuild action is pinned to a verified git commit.
- Output: *temporary GitHub Actions artifact only*. **No Release**, flash, bootloader replacement or writing to eMMC is performed.
- Image name: contains `s905x3-2101` and is an **experimental 2101W candidate**, not a stock Android image and not a confirmed 2101W boot image.

The workflow checks that it produced a target-named, non-empty and gzip-valid candidate. This is *packaging validation*, **not** a boot, PHY, Wi-Fi or USB test. Retention of Actions artifacts is finite.

## Safe follow-up validation

1. Extract the device-specific DTB/bootloader from the archived 2101W stock image as reference, without writing anything to hardware.
2. Compare MDIO PHY ID, RGMII timing, GPIO resets, DTB compatible strings, SDIO Wi-Fi and bootloader overrides against the candidate.
3. Only after a separate approval, conduct a reversible SD/USB boot test (preferably with UART logs), checking serial console, block devices, 1000BASE-T negotiation, DHCP/static-IP routing, Wi-Fi and LED.
4. Do **not** run `armbian-install`, change the onboard bootloader, erase or repartition eMMC until rollback and data backup are verified.

Source: [ophub/amlogic-s9xxx-armbian](https://github.com/ophub/amlogic-s9xxx-armbian) (GPL-2.0), including its `model_database.conf`, rebuild action and kernel packages. The build action and image are third-party inputs; no claim of official Armbian support is made.
