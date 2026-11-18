# yang 的 home-manager 配置
# 记家目录内以声明管理的文件；本例：
#   - fcitx5/rime 五笔拼音方案文件（nixpkgs rime-data 不含 wubi，无法作为系统包安装）
#   - default.custom.yaml 启用 schema：wubi_pinyin（五笔拼音混输）+ luna_pinyin（朙月拼音）
#   - niri 会话配置（niri/ 目录）
#   - Helix 编辑器配置 + 文件管理器双击打开文本/代码文件的 MIME 关联
# Rime 自己运行时写入的 build/、userdb/、user.yaml 不在此管理，互不冲突。
# 注意：本文件引用 ./rime/ ./niri/ 相对路径，必须保持在仓库根目录。
{ pkgs, ... }:

# Helix(.desktop) 关联的全部 MIME 类型：文件管理器双击文本/代码文件直接用 Helix 打开。
# desktopEntries 与 mimeApps 共用此列表；增删类型后需 nixos-rebuild switch 生效。
let
  helixMimeTypes = [
    # 通用文本
    "text/plain" "text/x-log" "text/csv" "text/tab-separated-values"
    "text/org" "text/x-ini" "application/x-desktop"
    "text/x-diff" "text/x-patch" "text/x-makefile" "text/x-cmake"
    # 标记/配置
    "text/markdown" "text/x-toml" "text/yaml" "application/x-yaml"
    "text/x-tex" "text/xml" "application/xml" "application/json"
    "text/css"
    # Web / 脚本
    "text/javascript" "application/javascript" "text/x-typescript"
    "text/x-shellscript" "application/x-shellscript"
    "text/x-perl" "application/x-perl"
    # 编程语言
    "text/x-python" "text/x-python3" "text/x-go" "text/x-rust"
    "text/x-c" "text/x-csrc" "text/x-chdr" "text/x-c++src" "text/x-c++hdr"
    "text/x-java" "text/x-ruby" "text/x-php" "text/x-lua"
    "text/x-haskell" "text/x-sql" "application/sql"
  ];
in

{
  home.stateVersion = "26.05";

  # 启用 xdg 模块：desktopEntries / mimeApps 依赖此项，否则声明会被静默忽略
  xdg.enable = true;

  home.file.".local/share/fcitx5/rime/wubi_pinyin.schema.yaml".source =
    ./rime/wubi_pinyin.schema.yaml;

  home.file.".local/share/fcitx5/rime/wubi86.dict.yaml".source =
    ./rime/wubi86.dict.yaml;

  home.file.".local/share/fcitx5/rime/default.custom.yaml".text = ''
    patch:
      schema_list:
        - schema: wubi_pinyin
        - schema: luna_pinyin
  '';

  # niri + noctalia 会话集成：确保 autostart / 启动器绑定 / noctalia.kdl 始终存在
  # 源文件位于 /etc/nixos/niri/，修改后需 nixos-rebuild switch 生效
  xdg.configFile."niri/config.kdl".source = ./niri/config.kdl;

  # Thunar「在此处打开终端」的首选终端设置。
  # 系统未装 xfce4-settings，exo 4.20 走回退模式：
  # TerminalEmulator 的值按 PATH 中的可执行程序名查找，故写二进制名而非 .desktop 文件。
  xdg.configFile."xfce4/helpers.rc".text = ''
    [Default]
    TerminalEmulator=alacritty
  '';

  # 文件管理器双击文本/代码文件时，在 Alacritty 里运行 Helix 打开。
  # Helix 是终端编辑器，不能直接作为 GUI 程序启动，须经终端；
  # Exec 中 %F 支持一次打开多个选中文件。
  # （生成 ~/.local/share/applications/helix.desktop）
  xdg.desktopEntries.helix = {
    type = "Application";
    name = "Helix";
    genericName = "Text Editor";
    comment = "Edit text and code in the Helix editor";
    exec = "alacritty -e hx %F";
    terminal = false;
    startupNotify = true;
    categories = [ "Utility" "TextEditor" ];
    mimeType = helixMimeTypes;
  };

  # 各 MIME 类型的默认打开方式 → 上面的 helix.desktop
  # （生成 ~/.config/mimeapps.list 的 [Default Applications] 段）
  # 注意：mimeApps 有独立开关，默认关闭，必须显式启用
  xdg.mimeApps.enable = true;
  xdg.mimeApps.defaultApplications =
    builtins.listToAttrs (map (m: {
      name = m;
      value = [ "helix.desktop" ];
    }) helixMimeTypes);

  # helix配置
  programs.helix = {
    enable = true;
    defaultEditor = true;

    # 语言服务器 / 格式化 / Wayland 剪贴板工具
    extraPackages = with pkgs; [
      nil              # Nix 语言服务器（按需由 Helix 启动）
      nixfmt           # Nix 自动格式化
      wl-clipboard     # Wayland 下与系统剪贴板同步（niri）
    ];

    settings = {
      theme = "autumn_night";

      editor = {
        line-number = "relative";
        cursorline = true;
        color-modes = true;
        true-color = true;
        bufferline = "multiple";
        mouse = false;              # 适合 niri 平铺下的键盘工作流
        auto-format = true;         # 保存时自动格式化
        default-yank-register = "+"; # y 直接复制到系统剪贴板
        completion-trigger-len = 1; # 更灵敏的智能补全
        idle-timeout = 200;

        cursor-shape = {
          insert = "bar";
          normal = "block";
          select = "underline";
        };

        lsp = {
          display-messages = true;
          display-inlay-hints = true;
        };

        indent-guides = {
          render = true;
          character = "│";
        };

        soft-wrap = {
          enable = false;
        };

        statusline = {
          left = [ "mode" "spinner" "file-name" "read-only-indicator" "file-modification-indicator" ];
          center = [ ];
          right = [ "diagnostics" "selections" "register" "position" "file-encoding" "file-line-ending" "file-type" ];
        };
      };

    };

    languages = {
      language-server.nil = {
        command = "nil";
      };

      language = [
        {
          name = "nix";
          auto-format = true;
          formatter = { command = "nixfmt"; };
          language-servers = [ "nil" ]; # 跳转定义/补全/诊断由 nil 提供，按需启动
        }
      ];
    };
  };
}
