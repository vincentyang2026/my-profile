# NAS 独立 NixOS 配置 · 说明与文件索引

生成：2026-11-14。本目录是 NAS（192.168.3.9，主机名 `nas`）换装 NixOS 的**完整独立配置**，
与 wu/desktop 的 `/etc/nixos`（shared.nix 体系）互不参与、互不 import。
规划依据：`~/download/nix规划/07-nas-初步方案.md`（v2 定稿）。

## 目录结构

```
~/Downloads/nix-nas配置/
├── flake.nix                    # 入口：单 entry nas，无 home-manager
├── configuration.nix            # NAS 全部配置（单文件，见文内分节注释）
├── docker/
│   ├── immich/
│   │   ├── docker-compose.yml   # ★真实文件：2026-11-14 从 NAS /home/yang/immich/ 拷取
│   │   └── .env                 # ★真实文件：同上（含 DB_PASSWORD，注意保密）
│   └── octop/
│       └── docker-compose.yml   # 由容器定义反推重建（原 1panel 部署，改 compose 管理）
└── README.md                    # 本文件
```

## 缺一个文件：hardware-configuration.nix

**不能预先手抄**——p7 将在换装时被格式化（btrfs UUID 会变）。换装当天在该机的 NixOS 安装环境里：

```bash
nixos-generate-config --dir /etc/nixos   # 生成 hardware-configuration.nix
```

生成后核对/补入两条数据盘挂载（模板已写在 configuration.nix 的注释里）：
- `/mnt/nas` → sda1 ext4（UUID `5e5f777d-f29e-4c29-94f8-3c265d4c0de0`）
- `/mnt/Data_drv` → sda2 ntfs（已声明在 configuration.nix）

## 换装时的数据回迁清单（对应 07 文档第五节）

| 现位置（CachyOS） | 去向 |
|---|---|
| `/home/yang/immich/`（compose+.env+**postgres 数据**） | `docker/immich/` 归仓 + postgres 数据回 `/home/yang/immich/postgres` |
| `~/.octop` | 原位（octop 容器数据） |
| `~/bin/`（immich-backup.sh 等）、`~/.local/bin/cron-reminder.sh` | 原位，configuration.nix 里对应定时器注释段填实 |
| crontab 全文 | 已在 07 文档留档条款；逐条迁成 NixOS timer |

## 验收要点（换装后）

1. desktop 三挂载照常（`vers=4.2`，仅 10.10.10.2 可连 2049）
2. immich :2283 / octop :8088 正常
3. 23:00 suspend 生效；desktop 开机 WOL 唤醒（desktop 端配置已备好在 `~/Downloads/nix规划/desktop-configuration.nix`）
4. `nixos-rebuild switch --flake .#nas` 在 NAS 本机执行（远端 SSH 也可，注意 suspend 前收尾）
