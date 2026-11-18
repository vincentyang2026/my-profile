# PC 共享 NixOS 配置快照 · 文件索引

生成：2026-11-14，已更新为**平铺结构**（可直接部署，无需改名/建子目录）。
覆盖：wu（本机）、ibm（192.168.3.12）、desktop（192.168.3.72 预备）。NAS 独立于 `~/Downloads/nix-nas配置/`。

## 部署方式（每台机器相同）

1. **把本目录下全部文件拷贝到目标机器的 `/etc/nixos/`**（覆盖/清空旧内容均可，按需）
2. 在目标机器执行：`cd /etc/nixos && sudo nixos-rebuild switch --flake .#<主机名>`
   - wu 机：`--flake .#wu`
   - ibm 机：`--flake .#ibm`
   - desktop 机：换装 NixOS 后先生成 `desktop-hardware-configuration.nix` 并放入本目录/`/etc/nixos`，再在 flake.nix 里解除 desktop entry 注释，然后 `--flake .#desktop`

**不需要**改文件名、不需要建 `hosts/` 子目录。三台机器用的是同一份 `flake.nix`，靠 `#<主机名>` 区分。

> 说明：目录里同时存在 `wu-*`、`ibm-*`、`desktop-*` 前缀文件是正常的——它们是各自机器的专属配置，互不干扰；rebuild `#ibm` 时不会用到 wu 的文件。

## 文件清单

| 文件 | 类型 | 说明 |
|---|---|---|
| `flake.nix` | 共享 | 三机入口（wu、ibm 已启用；desktop 注释待启用）。`#主机名` 选择目标 |
| `shared.nix` | 共享 | 公共配置（niri/noctalia greeter/fcitx5/字体/docker/镜像/用户 yang 等） |
| `home.nix` | 共享 | home-manager：helix 双击打开、niri/rime 部署 |
| `niri/config.kdl`, `niri/noctalia.kdl` | 共享 | niri 会话与窗口规则 |
| `rime/wubi_pinyin.schema.yaml`, `rime/wubi86.dict.yaml` | 共享 | 五笔方案与词库 |
| `wu-configuration.nix` | wu 专属 | 主机名/bootloader/zram(4G)/NTFS `/mnt/Data2`/stateVersion |
| `wu-hardware-configuration.nix` | wu 专属 | 硬件扫描（UUID/分区/swap，勿手改） |
| `ibm-configuration.nix` | ibm 专属 | **最终可用版（已实测 dry-build）**：主机名/bootloader/zram(8G)/NTFS `/mnt/Data`(p4 卷标"数据盘")；并入后获得 Noctalia Greeter（取代现 tuigreet）与 helix 双击功能 |
| `ibm-hardware-configuration.nix` | ibm 专属 | 硬件扫描（p5 ESP `F9D6-17B0` / p6 btrfs `e0112cc5…`，无磁盘 swap；与原机 md5 一致） |
| `desktop-configuration.nix` | desktop 专属 | 主机名/bootloader/静态 IP/NFS/NVIDIA/**开机 WOL 唤醒 NAS**；含 wakonlan 逻辑 |

## 注意事项

1. `desktop-hardware-configuration.nix` 暂缺——**不能手抄**，须在台式机 NixOS 安装环境里 `nixos-generate-config` 生成后放入本目录（文件名保持此前缀形式）
2. NAS 配置独立存放于 `~/Downloads/nix-nas配置/`，不在本目录
3. 规划文档（00–07）在 `~/download/nix规划/`（小写 download）
4. **ibm 并入变化摘要**：旧结构 → 本平铺结构；tuigreet → Noctalia Greeter；获得 helix 双击/最新 shared；新增 `/mnt/Data` 数据盘挂载
5. flat layout 已用 flake.lock 实测：`dry-build .#ibm` 与 `.#wu` 均可求值通过
