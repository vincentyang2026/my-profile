# wu/desktop/ibm 三台桌面机的 NixOS flake 入口
# 输入源说明：
#   - nixpkgs / nixpkgs-unstable：USTC 镜像 tarball，flake.lock 钉住修订号
#   - home-manager：gh-proxy.com 加速的 github release-26.05 tarball（前缀失效时换 ghfast.top 等可达镜像）
# 想升级 nixpkgs-unstable 时：如果改回github则改回：“github:nix-community/home-manager/release-26.05";
#   cd /etc/nixos && sudo -i nix flake update nixpkgs-unstable && nixos-rebuild switch --flake .#wu
{
  description = "wu/desktop/ibm: NixOS + niri + noctalia + fcitx5/rime-wubi";

  inputs = {
    nixpkgs.url = "tarball+https://mirrors.ustc.edu.cn/nix-channels/nixos-26.05/nixexprs.tar.xz";
    home-manager.url = "tarball+https://gh-proxy.com/https://github.com/nix-community/home-manager/archive/release-26.05.tar.gz";
    home-manager.inputs.nixpkgs.follows = "nixpkgs";
    # 仅用于个别新包（当前：noctalia、wechat、wpsoffice-cn、obsidian、opencode）
    nixpkgs-unstable.url = "tarball+https://mirrors.ustc.edu.cn/nix-channels/nixpkgs-unstable/nixexprs.tar.xz";
    # wechat 专用：钉死修订（其钉定的安装包指纹与腾讯 CDN 现挂内容一致，可 CDN 直拉；
    # 不随 nixpkgs-unstable 更新，避免 wechat 堵住整次 switch）
    nixpkgs-wechat.url = "tarball+https://gh-proxy.com/https://github.com/NixOS/nixpkgs/archive/master.tar.gz";
    # Noctalia Greeter（登录界面）：26.05 stable 无此包/模块，故用官方项目 flake；
    # 其 nixpkgs 跟随我们已有的 USTC unstable（wlroots_0_20 等构建依赖都在），不新增下载源
    noctalia-greeter.url = "github:noctalia-dev/noctalia-greeter";
    noctalia-greeter.inputs.nixpkgs.follows = "nixpkgs-unstable";
  };

  outputs = { self, nixpkgs, nixpkgs-unstable, nixpkgs-wechat, home-manager, noctalia-greeter }:
    let
      system = "x86_64-linux";
      # 单包借用 unstable 的 pkgs（只给需要新版本的包用）
      pkgs-unstable = import nixpkgs-unstable {
        inherit system;
        config.allowUnfree = true;
      };
      # wechat 专用 pkgs（钉死修订 → 哈希永不变化，命中本地 store 或腾讯 CDN 直拉）
      pkgs-wechat = import nixpkgs-wechat {
        inherit system;
        config.allowUnfree = true;
      };

      # 三台桌面机共用的 nixosSystem 构造逻辑。
      # 主机差异只体现在 hostModule 指向的文件；home-manager / greeter / specialArgs
      # 等公共部分只在这里写一次，新增机器时加一行 mkHost 调用即可。
      mkHost = hostModule: nixpkgs.lib.nixosSystem {
        system = system;
        specialArgs = { inherit pkgs-unstable pkgs-wechat; };
        modules = [
          hostModule
          noctalia-greeter.nixosModules.default
          home-manager.nixosModules.home-manager
          {
            home-manager.useGlobalPkgs = true;
            home-manager.useUserPackages = true;
            # 既有用户文件冲突时自动改名保留（.hm-bak 后缀）
            home-manager.backupFileExtension = "hm-bak";
            home-manager.users.yang = import ./home.nix;
          }
        ];
      };
    in
    {
      nixosConfigurations = {
        ############ 当前主机：笔记本 wu ############
        wu = mkHost ./wu-configuration.nix;

        ############ 第三台桌面机 ibm（192.168.3.12，ThinkPad i5-7200U/8G/HD620） ############
        # 部署：本目录全部文件拷到 ibm 的 /etc/nixos/，直接执行 nixos-rebuild switch --flake .#ibm
        # 注意：并入后 shared.nix 里的 Noctalia Greeter 会取代 ibm 现在的 tuigreet（属预期变化）
        ibm = mkHost ./ibm-configuration.nix;

        ############ 台式机 desktop（换装 NixOS 后取消下面注释并启用） ############
        # 前提：在该机安装环境生成 desktop-hardware-configuration.nix 并放入本目录后，
        # desktop-configuration.nix（已备好 NVIDIA/静态IP/NFS/WOL 配置）才可求值。
        # 参考规划文档：~/download/nix规划/04-hosts-desktop.md
        #
        # desktop = mkHost ./desktop-configuration.nix;
      };
    };
}
