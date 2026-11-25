{ config, pkgs, ... }:
{
  imports = [
    ./wu-hardware-configuration.nix # 本机硬件扫描结果（nixos-generate-config 生成）
    ./shared.nix # 多机共享配置
  ];

  networking.hostName = "wu";

  ############ UEFI + systemd-boot ############
  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;
  boot.loader.systemd-boot.configurationLimit = 10; # 最多保留 10 个启动项
  boot.loader.systemd-boot.consoleMode = "0"; # 0 / 1 / 2 / auto / max / keep

  ############ 内存较小(4G)，启用 zram 交换 ############
  zramSwap.enable = true;

  ############ 数据盘挂载（本机 sda2，NTFS） ############
  boot.supportedFilesystems = [ "ntfs" ];
  fileSystems."/mnt/Data2" = {
    device = "/dev/disk/by-uuid/2BC0359441F3FA49";
    fsType = "ntfs3";
    options = [
      "defaults"
      "nofail"
      "noatime"
      "windows_names"
      "uid=1000"
    ];
  };

  ############ 显卡 ############
  # Intel 集显（HD 5500）：无需任何声明，内核 i915 自动加载。
  # 如需视频硬件解码可加：
  # hardware.graphics.extraPackages = [ pkgs.intel-media-driver ];

  ############ 截图标注：satty（仅本机试运行） ############
  # Noctalia 内置标注器不注册 text-input，中文无法输入（上游 issue #5072 未修），
  # 截图后管道交给 satty 标注（声明配置在 home.nix：config 通道 screenshot.toml
  # + state 覆盖层 activation 补丁）。
  # 放系统包而非 home.packages：pipe_command 经 /bin/sh -lc 解析命令，系统 PATH 必中。
  environment.systemPackages = [ pkgs.satty ];

  # 与安装时使用的 NixOS 版本一致（ISO: nixos-graphical-26.05.13936... → "26.05"），
  # 安装后不要随意修改！
  system.stateVersion = "26.05";
}
