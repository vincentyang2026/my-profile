{
  config,
  pkgs,
  pkgs-unstable,
  pkgs-wechat,
  pi-pkg,
  ...
}:
{
  ############ 主机无关网络：NetworkManager（无线由 NM/DHCP 管理） ############
  # 注意：有线静态 IP 的机器通过其 hosts/*/configuration.nix 中
  #   networking.networkmanager.unmanaged 把对应接口排除出 NM。
  networking.networkmanager.enable = true;

  ############ 局域网访问：SSH + mDNS ############
  # 允许局域网内其它机器 ssh/scp/rsync 访问本机（openssh 模块默认自动放行 22 端口）
  services.openssh = {
    enable = true;
    settings.PasswordAuthentication = true; # 更安全的做法是改用密钥登录
  };

  # 让其它机器能用 <主机名>.local 这样的主机名访问本机（mDNS）
  services.avahi = {
    enable = true;
    nssmdns4 = true;
    openFirewall = true;
    publish = {
      enable = true;
      addresses = true;
      workstation = true;
    };
  };

  ############ 打印：CUPS（支持局域网打印机） ############
  services.printing.enable = true;
  services.printing.drivers = with pkgs; [
    gutenprint
  ];

  ############ 时区与本地化 ############
  time.timeZone = "Asia/Shanghai";
  i18n.defaultLocale = "zh_CN.UTF-8";

  ############ 桌面：niri ############
  programs.niri.enable = true;

  # 登录管理器：greetd + Noctalia Greeter（官方版式登录界面，风格与桌面 noctalia 一致）
  # 模块自动完成：启用 greetd、创建 greeter 用户与状态目录、AccountsService(头像)、polkit；
  # greeter 包由 noctalia-greeter flake 自带构建（flake.nix 中已加该输入）。
  # 注意：不能同时保留 services.greetd.settings.default_session.command（会覆盖本 greeter），
  #       也不能留 tuigreet/gtkgreet 等其它 greeter——一台机器只应启用一个 greeter。
  services.displayManager.noctalia-greeter = {
    enable = true;
    # 可选：允许 yang 在 noctalia shell 里同步壁纸/光标外观到登录界面时免密授权
    # passwordless-sync-users = [ "yang" ];
  };
  # 见官方 Wiki：避免默认 PATH 注入影响 niri 会话
  systemd.user.services.niri.enableDefaultPath = false;

  # 备选：GDM（如 greetd 有问题可换用下面这行，二选一）
  # services.displayManager.gdm.enable = true;

  ############ 输入法：fcitx5 ############
  i18n.inputMethod = {
    enable = true;
    type = "fcitx5";
    fcitx5.addons = with pkgs; [
      fcitx5-rime
      fcitx5-gtk
      qt6Packages.fcitx5-configtool
    ];
  };
  # Wayland 原生应用走输入法协议，无需 GTK_IM_MODULE/QT_IM_MODULE；
  # XMODIFIERS 供 XWayland 应用使用
  environment.variables.XMODIFIERS = "@im=fcitx";
  # Qt 应用跟随桌面配色：qt6ct 先试（Qt6 应用），回落 qt5ct（Qt5 应用）
  environment.variables.QT_QPA_PLATFORMTHEME = "qt6ct:qt5ct";

  ############ 浏览器 ############
  programs.firefox.enable = true;

  ############ 中文字体 ############
  fonts.packages = with pkgs; [
    noto-fonts-cjk-sans
    noto-fonts-cjk-serif
    source-han-sans #思源思体
    source-han-serif #思源宋体
    lxgw-wenkai     #霞鹜文楷
    noto-fonts-color-emoji
  ];

  ############ 基础工具 ############
  environment.systemPackages = with pkgs; [
    git
    btop
    wget
    pciutils
    usbutils
    xwayland-satellite # niri 的 XWayland 兼容层
    alacritty # niri 默认 Super+T 打开的终端；也是 helix.desktop 的启动终端
    fuzzel # niri 默认 Super+D 应用启动器兜底
    # docker-compose # docker compose 插件/独立 go 版（PC 三机已弃 docker，见下方 Docker 块注释）
    adw-gtk3 # GTK3 暗色基础主题（noctalia App Theming GTK 模板前置）
    adwaita-icon-theme # GTK 图标主题（缺失时回退 hicolor）
    glib # 提供 gsettings，用于应用 GTK 主题设置
    libsForQt5.qt5ct # Qt5 平台主题插件：应用 noctalia 生成的 ~/.config/qt5ct/colors 配色
    qt6Packages.qt6ct # Qt6 平台主题插件：应用 ~/.config/qt6ct/colors 配色（fcitx5-configtool 等 Qt 应用）
    # 借 nixpkgs-unstable（版本新于 26.05 stable）
    pkgs-unstable.noctalia
    pkgs-wechat.wechat # 微信 Linux 官方客户端 (unfree)，追踪 master，升级只动本 input
    pkgs-unstable.wpsoffice-cn # WPS Office 中文版 (unfree)
    pkgs-unstable.obsidian # Obsidian（unstable 最新版，unfree）
    pkgs-unstable.opencode
    pi-pkg # pi coding agent（官方 flake earendil-works/pi stable 分支；升级只动 flake.lock 的 pi 节点）

    ############ 压缩/解压 ############
    unar # 解压：自动识别 Windows zip 的 GBK 文件名，零乱码（含 RAR 支持）
    zip # Windows 互传压缩
    p7zip # .7z 格式命令行
    zstd # 本地备份打包（tar -I zstd）
    (writeShellScriptBin "zip-here" ''
      # Thunar「压缩为 zip」后端：cd 到选中文件目录，用 basename 打包（正确处理空格/多选/目录）
      dir=$(dirname "$1"); cd "$dir" || exit 1
      base=$(basename "$1"); base="''${base%.*}"   # 归档名取第一个文件的主名
      files=(); for f in "$@"; do files+=("$(basename "$f")"); done
      exec zip -r "$base.zip" "''${files[@]}"
    '') # 右键「压缩为 zip」，与 home.nix 的 uca.xml 自定义动作配套
    (writeShellScriptBin "terminal-here" ''
      # Thunar「在此处打开终端」（Thunar 4.20 已移除内置项，改由 uca.xml 动作承担）：
      # $1 = %d（首文件目录 / 空白处右键时为当前目录），$2... = %F（选中文件）
      target=$1
      if [ $# -ge 2 ] && [ -d "$2" ]; then target=$2; fi   # 右键目录时打开该目录本身
      exec alacritty --working-directory "$target"
    '') # 右键「在此处打开终端」，与 home.nix 的 uca.xml 自定义动作配套
  ];

  ############ 文件管理器：Thunar + U 盘/可移动设备支持 ############
  programs.thunar.enable = true;
  programs.thunar.plugins = with pkgs; [
    thunar-volman # 可移动设备自动管理（插入 U 盘时挂载/弹出）
    # thunar-archive-plugin 已移除（2026-11-25）：其右键功能依赖 .tap wrapper，官方仅带
    # ark/engrampa/file-roller/peazip，xarchiver/file-roller 方案要么不支持要么多拖 943MB 依赖。
    # 压缩/解压改由 uca.xml 自定义动作承担（zip-here 压缩 + unar 解压），零额外依赖。
  ];
  services.gvfs.enable = true;     # 回收站、挂载集成（Thunar 依赖）
  services.tumbler.enable = true;  # 缩略图服务
  services.udisks2.enable = true;  # 磁盘/U 盘挂载后端

  ############ Noctalia 功能依赖（wifi/蓝牙/电池/电源插件） ############
  services.upower.enable = true;
  services.power-profiles-daemon.enable = true;
  hardware.bluetooth.enable = true; # 无蓝牙/电池的机器开着也无害；介意可挪到主机文件关闭

  # 授权弹窗（polkit）与密钥环（secret service）
  security.polkit.enable = true;
  services.gnome.gnome-keyring.enable = true;

  ############ Flatpak ############
  services.flatpak.enable = true;
  # packages = [ "org.example.App" ];   # 需声明式预装时在此列包 id

  ############ AppImage(binfmt 注册,直接 ./xxx.AppImage 运行) ############
  #programs.appimage = {
  #  enable = true;
  #  binfmt = true;
  #};

  ############ Docker（daemon + 国内镜像加速 + 每周自动清理） ############
#  virtualisation.docker = {
 #   enable = true;
 #   autoPrune = {
 #     enable = true;
 #     dates = "weekly";
 #     flags = [ "--all" ];
  #  };
  #  daemon.settings = {
   #   registry-mirrors = [
    #    "https://docker.m.daocloud.io"
    #    "https://docker.1ms.run"
    #  ];
    #};
  #};

  ############ Flake 支持（Noctalia 需要用到） ############
  nix.settings.experimental-features = [
    "nix-command"
    "flakes"
  ];

  # 允许安装专有软件（如 wechat）
  nixpkgs.config.allowUnfree = true;

  ############ Nix gc 与国内镜像加速二进制缓存 ############
  nix.gc = {
    automatic = true;
    dates = "weekly";
    options = "--delete-older-than 7d";
  };
  # SJTU / USTC 镜像与官方缓存使用相同签名，默认受信密钥即可
  nix.settings.substituters = [
    "https://mirror.tuna.tsinghua.edu.cn/nix-channels/store"
    "https://mirror.sjtu.edu.cn/nix-channels/store"
    "https://mirrors.ustc.edu.cn/nix-channels/store"
    "https://cache.nixos.org"
    # noctalia 官方二进制缓存（unstable 版对应包优先从这里拉，免本地编译）
    "https://noctalia.cachix.org"
  ];
  nix.settings.extra-trusted-public-keys = [
    "noctalia.cachix.org-1:pCOR47nnMEo5thcxNDtzWpOxNFQsBRglJzxWPp3dkU4="
  ];

  ############ 用户（多机统一用户名 yang） ############
  # fish：CachyOS 时期的终端体验（灰字自动建议/智能 Tab 补全/语法高亮）来自它，换 NixOS 后显式声明回来
  programs.fish.enable = true;
  users.users.yang = {
    isNormalUser = true;
    shell = pkgs.fish;
    description = "yang";
    extraGroups = [
      "wheel"
      "networkmanager"
      # "docker" # docker daemon 停用后组不存在，恢复 Docker 时一并解开
    ];
    # 初始密码（首次登录后建议执行 passwd 修改）
    initialPassword = "changeme";
  };
  # 允许 wheel 组使用 sudo（默认 true，显式写出便于理解）
  security.sudo.wheelNeedsPassword = true;

  ############ 备忘注释 ############
  #      且必须伴随该机有线网卡静态/同网段 IP，保证 NFS 只走有线。
  # zram：按内存大小放各主机文件。
  # system.stateVersion：属主机文件（标记该机安装代数），不进本文件。
}
