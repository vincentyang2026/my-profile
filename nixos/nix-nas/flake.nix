# NAS（192.168.3.9）独立 NixOS 配置 · flake 入口
# 本目录自成一套配置，与 wu/desktop 的 /etc/nixos 完全独立（不 import shared.nix/home.nix）。
# 输入源：USTC 镜像 tarball（26.11 发布后把 URL 换成 nixos-26.11）。
# 无 home-manager：NAS 无头运行，无用户态配置需求。
{
  description = "nas: NixOS headless NAS (NFS server + docker)";

  inputs = {
    nixpkgs.url = "tarball+https://mirrors.ustc.edu.cn/nix-channels/nixos-26.05/nixexprs.tar.xz";
    # 26.11 发布后换为：
    # nixpkgs.url = "tarball+https://mirrors.ustc.edu.cn/nix-channels/nixos-26.11/nixexprs.tar.xz";
  };

  outputs = { self, nixpkgs }: {
    nixosConfigurations.nas = nixpkgs.lib.nixosSystem {
      system = "x86_64-linux";
      modules = [ ./configuration.nix ];
    };
  };
}
