# X96 MAX+ 2101W · KDE Plasma Armbian 镜像

## 范围与基础

目标设备 **Amlogic S905X3/SM1、4 GiB RAM、64 GiB eMMC**，运行 **Armbian Debian Bookworm ARM64 + KDE Plasma X11**。制作的是适合外部 SD/USB 介质的候选映像，**不写内部 64 GiB eMMC**。镜像文件并非 64 GiB；临时设置为 **10 GiB** 虚拟磁盘，便于容纳完整桌面及后续使用，写入外部介质时应保证容量大于映像文件。

直接来源是已经成功打包并通过 gzip 检查的 [Armbian server Run #42480891440](https://github.com/Grinch27/Armbian_x96maxplus2101w/actions/runs/42480891440) 的 [源 Artifact](https://github.com/Grinch27/Armbian_x96maxplus2101w/actions/runs/42480891440/artifacts/13617138867)。原始系统是 `s905x3-2101`、6.12.116、Bookworm ARM64。这是继承上游通用 2101 板级配置的候选系统，**还不是专为 2101W 4G+64G 硬件验证的 DTS**。

## 实际桌面安装（非首次启动联网安装）

- 工作流：[Build Armbian 2101W KDE Plasma](../.github/workflows/build_kde.yml)
- 离线镜像处理：[scripts/build_kde_image.sh](../scripts/build_kde_image.sh)
- 运行环境：独立 `ubuntu-26.04-arm` GitHub Runner，执行原生 arm64 chroot，而非在 x86 上安装错误的用户态库。
- 解压已核验的服务器固件映像，检查 MBR 分区表并仅扩展**映像文件内部的第二个 ext4 分区**，第一个 FAT 启动分区保持不变。
- `apt-get update`，安装 `kde-plasma-desktop`、`sddm`、`xserver-xorg`、`plasma-nm`、`konsole`、`dolphin`、`dbus-x11`、Noto 字体和软件渲染 Mesa 库。
- 显示会话优先采用 **X11**，启用 `graphical.target` + SDDM；不假定 Mali GPU/DRM 已通过实机驱动验收。
- 在 chroot 内使用 `policy-rc.d` 临时拒绝启动服务，安装结束后恢复原始文件，卸载宿主模拟文件系统，运行 ext4 检查、gzip 完整性检查并保存 provenance JSON。
- 构建成功时输出 `*.img.gz` 与 `kde-image-manifest.json` 至有效期七天的 **GitHub Actions Artifact**。不会创建正式 Release。

## 外部介质与账户准备

正式实机验证尚未授权。后续需要明确同意后，才能把镜像写到**独立外部 SD/USB**，借助 UART 日志验证启动。切勿运行 `armbian-install` 或覆写内部 eMMC/U-Boot；回退路径必须可用。

上游 Armbian 服务器映像具有初始账户初始化流程。图形登录的普通用户须在首次启动时按上游提示创建；如 SDDM 在初始化之前显示登录界面，需要切到系统文本终端完成初始化。**不要假设 SDDM 支持直接以 root 登录**，也不要向公开 Artifact 注入通用密码或私有凭据。初始镜像如保留上游默认 root 密码，应在第一次安全登录时立即更改，防止网络暴露。

## 不能通过 Actions 证明的硬件能力

| 验收项 | 当前状态 |
| --- | --- |
| S905X3 / U-Boot 从外部启动 | 未实机验证 |
| 4 GiB RAM 全量正确识别和稳定性 | 未实机验证 |
| 64 GiB eMMC 正确枚举且 Android 原有分区不受损 | 未实机验证；构建本身无内部写入 |
| JL2101 与交换机协商 1000 Mbps、DHCP、持续传输 | 未实机验证 |
| W522A 2.4 GHz/5 GHz STA 双频分别连接与双向传输 | 未实机验证；驱动尚未集成 |
| KDE SDDM 显示、X11 会话、USB 键鼠 | 只验证 rootfs 软件包和配置；实机未验证 |
| W522A Bluetooth / AiP1628 LED | P2，不阻止未来硬件 P0 以外的初步候选 |

`Aexe-Software/W522A-Driver-Linux` 只在 W100 / 6.12.81 上有报告的实机证据，不可直接将其 SDIO GPIO、UART 以及驱动成功状态套到 2101W / 6.12.116。本轮 KDE 构建不移植该驱动。

## 验收口径

只有当 GitHub Run 正式显示 Success、真实 arm64 chroot 的 `dpkg-query` 证实 KDE/SDDM 已安装、X11 会话文件存在、display-manager symlink 生效、ext4/gzip 文件系统检查通过、最后 Artifact 实际存在时，才称其为**已构建的 KDE 候选镜像**。任何时候均不得称其已经在 2101W 上正常启动。
