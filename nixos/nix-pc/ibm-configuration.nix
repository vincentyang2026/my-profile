# ibm（192.168.3.12）主机配置 · 最终可用版
# 说明：ibm 现为 wu 旧结构配置的副本（26.05 已安装运行）。
# 本文件与 wu/desktop 同属 nix-pc配置 共享目录，平铺放置；flake.nix 通过 nixosConfigurations.ibm 引用本文件。
# 部署：把 nix-pc配置 下全部文件拷到 ibm 的 /etc/nixos/，直接执行 nixos-rebuild switch --flake .#ibm（无需改名/建子目录）。
{ config, pkgs, ... }:
{
  imports = [
    ./ibm-hardware-configuration.nix # 本机硬件扫描结果（p5 ESP F9D6-17B0 / p6 btrfs e0112cc5…，无磁盘 swap）
    ./shared.nix # 多机共享配置
  ];

  networking.hostName = "ibm";

  ############ UEFI + systemd-boot ############
  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;
  boot.loader.systemd-boot.configurationLimit = 5; # 最多保留 5 个启动项
  boot.loader.systemd-boot.consoleMode = "0"; # 0 / 1 / 2 / auto / max / keep

  ############ zram ############
  # 内存 8G：zram 作 OOM 兜底保留（原配置注释"内存较小(4G)"系从 wu 拷贝的遗留，已修正）
  zramSwap.enable = true;

  ############ 数据盘挂载（本机 nvme0n1p4，卷标"数据盘"，与 wu 的 /mnt/Data2 同款做法） ############
  # p3（win10系统）是 Windows C:，不挂载；只挂数据盘。挂载点沿 wu 命名风格，可按喜好改。
  boot.supportedFilesystems = [ "ntfs" ];
  fileSystems."/mnt/Data" = {
    device = "/dev/disk/by-uuid/1AC205FAC205DAC1";
    fsType = "ntfs3";
    options = [
      "defaults"
      "nofail"
      "noatime"
      "windows_names"
      "uid=1000"
    ];
  };
  # 有线 enp0s31f6 闲置不用，无静态 IP/NFS 需求（shared.nix 的 NM 管无线即可）。

  ############ 显卡 ############
  # Intel HD 620 集显：无需声明，i915 自动加载。如需视频硬解可加：
  # hardware.graphics.extraPackages = [ pkgs.intel-media-driver ];

  # 本机已在 26.05 安装；26.11 统一升级时改为 "26.11"，安装代数不变原则
  system.stateVersion = "26.05";

  ############ Docker（daemon + 国内镜像加速 + 每周自动清理；自 shared.nix 下放至各主机，desktop 不启用） ############
  virtualisation.docker = {
    enable = true;
    autoPrune = {
      enable = true;
      dates = "weekly";
      flags = [ "--all" ];
    };
    daemon.settings = {
      registry-mirrors = [
        "https://docker.m.daocloud.io"
        "https://docker.1ms.run"
      ];
    };
  };
}
