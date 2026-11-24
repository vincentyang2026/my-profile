{ config, pkgs, ... }:
{
  imports = [
    ./desktop-hardware-configuration.nix # 安装环境 nixos-generate-config 生成后补入（勿手抄）
    ./shared.nix
  ];

  networking.hostName = "desktop";

  ############ UEFI + systemd-boot（Windows 双系统共存；p5 作 NixOS 的 ESP，不碰 p1） ############
  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;
  boot.loader.systemd-boot.configurationLimit = 10; # 最多保留 10 个启动项

  # 24G 内存：不启用 zram（zram 属于各主机文件，shared 中无此项）

  ############ 有线网卡 enp131s0：固定 10.10.10.2 ############
  # 有线接口脱离 NM 管理，用 NixOS 原生静态地址；NM 继续管理无线（与其它机器一致）。
  # 10.10.10.0/24 的直连路由只随有线静态 IP 产生 → 去往 NAS 的流量（NFS）只走有线，
  # 无线网上永远不存在这条路由；有线断开时 NFS 挂载失败（nofail），不漂移到无线。
  networking.networkmanager.unmanaged = [ "enp131s0" ];
  networking.interfaces.enp131s0.useDHCP = false;
  networking.interfaces.enp131s0.ipv4.addresses = [
    {
      address = "10.10.10.2";
      prefixLength = 24;
    }
  ];

  ############ NFS 自动挂载（NAS 10.10.10.1；仅本机启用） ############
  boot.supportedFilesystems = [ "nfs" ];
  fileSystems."/mnt/致卓" = {
    device = "10.10.10.1:/mnt/nas/公司/致卓";
    fsType = "nfs";
    options = [
      "_netdev"
      "nofail"
      "noatime"
      "x-systemd.automount"
      "x-systemd.idle-timeout=600"
      "x-systemd.mount-timeout=15"
      "vers=4.2"
    ];
  };
  fileSystems."/mnt/个人" = {
    device = "10.10.10.1:/mnt/nas/个人";
    fsType = "nfs";
    options = [
      "_netdev"
      "nofail"
      "noatime"
      "x-systemd.automount"
      "x-systemd.idle-timeout=600"
      "x-systemd.mount-timeout=15"
      "vers=4.2"
    ];
  };
  fileSystems."/mnt/常用数据备份" = {
    device = "10.10.10.1:/mnt/nas/常用数据备份";
    fsType = "nfs";
    options = [
      "_netdev"
      "nofail"
      "noatime"
      "x-systemd.automount"
      "x-systemd.idle-timeout=600"
      "x-systemd.mount-timeout=15"
      "vers=4.2"
    ];
  };

  ############ NVIDIA RTX 5060 Ti（Blackwell，纯独显台式机） ############
  services.xserver.videoDrivers = [ "nvidia" ];
  hardware.nvidia = {
    modesetting.enable = true; # Wayland/niri 必需
    open = true; # Blackwell 必须（专有内核模块不支持 RTX 50 系）
    nvidiaSettings = true;
    package = config.boot.kernelPackages.nvidiaPackages.stable; # 需 570+；若需最新 CUDA 再评估 beta
    powerManagement.enable = true; # Wayland 下休眠/唤醒黑屏的常见对策
    powerManagement.finegrained = false; # 纯独显台式机
  };
  # 可选退路：specialisation 一个 nouveau/无驱动 项，驱动翻车时从启动菜单进入救援

  ############ 本地大模型 ollama（RTX 5060 Ti 8G，CUDA 推理） ############
  # ollama-cuda：CUDA 运行库（cudart/libcublas/cccl…）随服务闭包整套而入，无全局 cuda、无 nvcc；
  # NVIDIA 内核模块与 libcuda 由上方 hardware.nvidia 段提供——二者缺一则 ollama 静默回退 CPU。
  # 驱动/内核/ollama/CUDA 全部被 flake.lock 锁定为一张闭包，升级原子、可回滚。
  # 模型目录为服务数据 /var/lib/ollama（换装时把旧 ~/.ollama/models rsync 过去即可）。
  services.ollama = {
    enable = true;
    package = pkgs.ollama-cuda;
  };

  ############ 开机自动唤醒 NAS（10.10.10.1，仅 desktop 承担此职责） ############
  # NAS（192.168.3.9，有线 eno1 MAC 1c:69:7a:49:52:1c）每天 23:00 自动 suspend；
  # desktop 每次开机经 enp131s0 直连发 WOL 魔术包唤醒它。直连不经过路由/交换机，包必达。
  # 仅 desktop 配置此项（wu 不参与唤醒）。etherwake 需 root 权限，服务以 root 跑即可。
  environment.systemPackages = with pkgs; [ etherwake ];
  systemd.services.wake-nas = {
    description = "Send WOL magic packet to NAS at boot";
    wantedBy = [ "multi-user.target" ];
    after = [ "network-online.target" ];
    wants = [ "network-online.target" ];
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
      ExecStart = "${pkgs.etherwake}/bin/etherwake -i enp131s0 1c:69:7a:49:52:1c";
    };
  };

  system.stateVersion = "26.05"; # 以该机安装 ISO 的版本为准（26.11 统一换装时改为 "26.11"）
}
