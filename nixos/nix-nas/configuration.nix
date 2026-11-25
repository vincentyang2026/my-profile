# NAS（192.168.3.9）NixOS 配置 · 单文件（独立仓库，不依赖 shared.nix）
# 目标形态：无头服务器；有线 eno1 静态 10.10.10.1（NFS 服务网段）；无线 NM/DHCP；
#           应用只经 Docker；每天 23:00 suspend，由 desktop(10.10.10.2) 开机 WOL 唤醒。
# 规划文档：~/download/nix规划/07-nas-初步方案.md（v2 定稿）
{ config, pkgs, ... }:
{
  imports = [ ./hardware-configuration.nix ];   # ★安装环境 nixos-generate-config 生成后替换

 networking.hostName = "nas";

  ############ UEFI + systemd-boot（单 NixOS，无 Windows） ############
  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;
  boot.loader.systemd-boot.configurationLimit = 5;  # 与其它 Nix 机器一致：最多保留 5 个启动项

  ############ 网络 ############
  networking.useDHCP = false;   # NM 自管 DHCP，显式关闭全局 dhcpcd 避免双客户端竞态
  # 有线 eno1 脱离 NM，NixOS 原生静态 IP；10.10.10.0/24 直连路由只随它产生
  networking.networkmanager = {
    enable = true;                              # 无线 wlan0 走 NM/DHCP（与其它机器一致）
    unmanaged = [ "eno1" ];
  };
  networking.interfaces.eno1.useDHCP = false;
  networking.interfaces.eno1.ipv4.addresses = [ { address = "10.10.10.1"; prefixLength = 24; } ];
  networking.interfaces.eno1.wakeOnLan.enable = true;   # suspend 后保持 wol g（硬件实测支持）

  ############ SSH ############
  services.openssh = {
    enable = true;
    settings.PasswordAuthentication = true;     # 无头无 IPMI：先密钥+密码并存，确认密钥可登后再改为 false
  };

  # mDNS：让局域网用 nas.local 访问（沿用现状 avahi）
  services.avahi = {
    enable = true;
    nssmdns4 = true;
    openFirewall = true;
    publish = { enable = true; addresses = true; };
  };

  ############ NFS server：只服务 desktop（10.10.10.2），只在有线网段 ############
  # 语义与 CachyOS 现状完全一致（导出三目录、仅限 10.10.10.2）
  services.nfs.server = {
    enable = true;
    exports = ''
      /mnt/nas/company 10.10.10.2/32(rw,sync,no_subtree_check)
      /mnt/nas/family   10.10.10.2/32(rw,sync,no_subtree_check)
      /mnt/nas/runtine  10.10.10.2/32(rw,sync,no_subtree_check)
    '';
  };

  ############ 防火墙（复刻 ufw 语义） ############
  networking.firewall = {
    enable = true;
    allowedTCPPorts = [ 22 ];   # ssh 全源放行（家庭内网可接受；需收紧可按接口/源限定）
    # NFS 2049 仅经直连有线网卡放行（eno1 为 10.10.10.1↔10.10.10.2 点对点，后端无关写法）
    interfaces.eno1.allowedTCPPorts = [ 2049 ];
    # docker 发布端口（immich 2283 等）经 FORWARD 链，默认可从局域网访问——与现状一致；
    # 如需收紧再配 DOCKER-USER 链规则
  };

  ############ Docker（应用只经 Docker） ############
  virtualisation.docker = {
    enable = true;
    autoPrune = { enable = true; dates = "weekly"; flags = [ "--all" ]; };
    daemon.settings.registry-mirrors = [
      "https://docker.m.daocloud.io"
      "https://docker.1ms.run"
    ];
  };

  ############ 基础工具（无头机器排障与容器管理） ############
  environment.systemPackages = with pkgs; [
    docker-compose
    helix
    git
    btop
    tmux
  ];

  ############ 磁盘挂载 ############
#  boot.supportedFilesystems = [ "ntfs" ];
  # sda2 NTFS 数据盘（原 ntfs-3g → ntfs3；属性沿用现状）
 # fileSystems."/mnt/Data_drv" = {
 #   device = "/dev/disk/by-uuid/46D4423E0B9547EF";
 #   fsType = "ntfs3";
 #   options = [ "defaults" "nofail" "noatime" "windows_names" "uid=1000" "gid=1000" "x-systemd.device-timeout=10" ];
#  };
  # sda1 ext4 → /mnt/nas（NFS 导出根，含 公司/个人/常用数据备份/immich 等）
  #   ★由 hardware-configuration.nix 生成；若安装时未扫到，手补：
     fileSystems."/mnt/nas" = {
       device = "/dev/disk/by-uuid/5e5f777d-f29e-4c29-94f8-3c265d4c0de0";
       fsType = "ext4";
       options = [ "defaults" "nofail" "noatime" "x-systemd.device-timeout=10" ];
     };
  # sda3/sda4（未挂载 ntfs）一律不声明、不挂载（NAS 单 NixOS，不保留 Windows 分区）

  ############ 每天 23:00 自动 suspend（保留现状行为） ############
  # 唤醒通道：desktop 每次开机经 enp131s0 直连发 WOL 魔术包（MAC 1c:69:7a:49:52:1c）
  systemd.services.nas-suspend = {
    description = "NAS nightly suspend at 23:00";
    serviceConfig = {
      Type = "oneshot";
      ExecStart = "${pkgs.systemd}/bin/systemctl suspend";
    };
  };
  systemd.timers.nas-suspend = {
    wantedBy = [ "timers.target" ];
    timerConfig = {
      OnCalendar = "*-*-* 23:00:00";
      AccuracySec = "30s";
      Persistent = false;
    };
  };

  ############ 每天 10:00 拉取 obsidian 库（desktop → NAS 数据盘） ############
  systemd.services.obsidian-pull = {
    description = "Pull obsidian-vault from desktop";
    unitConfig.RequiresMountsFor = "/mnt/nas";   # 数据盘 nofail：没挂上别跑，防导出空目录
    serviceConfig = {
      Type = "oneshot";
      User = "yang";
      ExecStart = "${pkgs.rsync}/bin/rsync -a --delete -e '${pkgs.openssh}/bin/ssh -o StrictHostKeyChecking=accept-new' yang2026@10.10.10.2:/home/yang2026/obsidian-vault/ /mnt/nas/obsidian-vault/";
    };
  };
  systemd.timers.obsidian-pull = {
    timerConfig = {
      OnCalendar = "*-*-* 10:00:00";
      AccuracySec = "30s";
      Persistent = true;      # 23:00 挂起错过 10 点，唤醒后自动补跑（与 nas-suspend 的 false 恰好相反）
      Unit = "obsidian-pull.service";
    };
    wantedBy = [ "timers.target" ];
  };


  ############ immich 备份 cron（脚本回迁后此段与脚本一起生效） ############
  # 现状：22:30 /home/yang/bin/immich-backup.sh + @reboot 180s 后补跑
  # systemd.services.immich-backup = { … }  # 迁完系统后按脚本实况填写
  # systemd.timers.immich-backup  = { OnCalendar = "*-*-* 22:30:00"; … }

  ############ 硬盘健康监控（沿用现状 smartd 的两块盘） ############
  services.smartd = {
    enable = true;
    devices = [
      { device = "/dev/disk/by-id/ata-WDC_WD10EZEX-08WN4A0_WD-WCC6Y4NPKYLP"; }
      { device = "/dev/disk/by-id/nvme-UMIS_RPJTJ256MEE1OWX_SS0L25189X1RC08R21XH"; }
    ];
  };

  ############ SSD/NVMe 定期 TRIM ############
  services.fstrim.enable = true;

  ############ zram（16G 内存，沿用现状） ############
  zramSwap.enable = true;

  ############ 本地化 ############
  time.timeZone = "Asia/Shanghai";
  i18n.defaultLocale = "zh_CN.UTF-8";

  ############ Nix 设置（与 wu/desktop 同款镜像，但独立声明） ############
  nix.settings.experimental-features = [ "nix-command" "flakes" ];
  nix.gc = { automatic = true; dates = "weekly"; options = "--delete-older-than 7d"; };
  nix.settings.substituters = [
    "https://mirror.tuna.tsinghua.edu.cn/nix-channels/store"
    "https://mirror.sjtu.edu.cn/nix-channels/store"
    "https://mirrors.ustc.edu.cn/nix-channels/store"
    "https://cache.nixos.org"
  ];

  ############ 用户 ############
  users.users.yang = {
    isNormalUser = true;
    description = "yang";
    uid = 1000;   # 固定 uid，与 /mnt/Data_drv 的 uid=1000/gid=1000 对齐，防未来漂移
    extraGroups = [ "wheel" "networkmanager" "docker" ];
    # openssh.authorizedKeys.keys = [ "ssh-ed25519 AAAA... yang@..." ];  # 装机前填入你的公钥
    initialPassword = "changeme";   # 装好后 passwd；密钥验证可登后再把 PasswordAuthentication 关掉
  };

  ############ 显式不装（对照 CachyOS 现状刻意取舍） ############
  # 无桌面/登录管理器/输入法/字体/CUPS/flatpak/firefox/bluetooth
  # 无 pgyvpn / easytier / 1panel / searxng / hindsight（2026-11-14 决定）

  # 与安装 ISO 版本一致，装好后不要随意修改（26.11 统一换装时核对）
  system.stateVersion = "26.05";
}

