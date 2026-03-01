# Aya Air Pro 安装 Debian：打造近似 SteamOS 的掌上游戏体验

## 前言：为什么放弃 Windows？

Windows 在掌机上的痛点主要包括：

*   **睡眠唤醒缓慢**：从合盖到唤醒往往需要 3-5 秒
*   **唤醒失败率高**：经常出现无法唤醒的情况，只能强制重启
*   **游戏稳定性差**：睡眠唤醒后，正在运行的游戏时常崩溃
*   **系统冗余**：后台进程过多，影响游戏性能

这些问题在移动游戏场景下尤为致命——想随时随地玩两把，结果光等开机就要半天，好不容易进入游戏还容易闪退。

本文将带你一步步在 Aya Air Pro 上安装 Debian，并通过一系列优化配置，打造一个接近 SteamOS 般「唤醒即玩」的流畅体验。

---

## 一、解决核心痛点：MT7921 网卡睡眠唤醒丢失

### 问题根源
MT7921 网卡固件在电源状态切换时响应超时，导致睡眠唤醒后 WiFi 丢失。

### 解决方案：创建睡眠处理服务

通过创建一个 systemd 服务，在系统睡眠前卸载网卡驱动，唤醒后重新加载，彻底解决 WiFi 丢失问题。

### 1. 创建睡眠处理服务
```
sudo tee /etc/systemd/system/mt7921e-sleep.service > /dev/null <<'EOF'
[Unit]
Description=Handle Mediatek mt7921e wifi sleep/wake
Before=sleep.target
StopWhenUnneeded=yes

[Service]
Type=oneshot
ExecStart=/usr/sbin/modprobe -r mt7921e
ExecStop=/usr/sbin/modprobe mt7921e
RemainAfterExit=yes

[Install]
WantedBy=sleep.target
EOF
```

### 2. 启用服务
```
sudo systemctl daemon-reload && sudo systemctl enable mt7921e-sleep.service
```

---

## 二、系统基础优化

### 1. 修改 apt 源为阿里云镜像（加速下载）

```
sudo nano /etc/apt/sources.list
```

替换为以下内容（基于 Debian trixie）：
```
# 阿里云镜像源
deb https://mirrors.aliyun.com/debian/ trixie main contrib non-free non-free-firmware
deb-src https://mirrors.aliyun.com/debian/ trixie main contrib non-free non-free-firmware

deb https://mirrors.aliyun.com/debian/ trixie-updates main contrib non-free non-free-firmware
deb-src https://mirrors.aliyun.com/debian/ trixie-updates main contrib non-free non-free-firmware

deb https://mirrors.aliyun.com/debian/ trixie-backports main contrib non-free non-free-firmware
deb-src https://mirrors.aliyun.com/debian/ trixie-backports main contrib non-free non-free-firmware

# 安全更新源 (可选用阿里云，或保留官方源)
deb https://mirrors.aliyun.com/debian-security trixie-security main contrib non-free non-free-firmware
deb-src https://mirrors.aliyun.com/debian-security trixie-security main contrib non-free non-free-firmware
```

更新软件包列表：
```
sudo apt update
```

### 2. 安装虚拟键盘（可选）

```
sudo apt install maliit-keyboard maliit-framework
```

---

## 三、提升使用体验：自动登录与禁用锁屏

### 1. 配置自动登录

#### 对于 GDM3（GNOME 桌面）
```
sudo nano /etc/gdm3/daemon.conf
```
在 `[daemon]` 部分添加以下内容（将 `your_username` 替换为你的实际用户名）：
```
[daemon]
AutomaticLoginEnable = true
AutomaticLogin = your_username
```

#### 对于 SDDM（KDE 桌面）
```
sudo nano /etc/sddm.conf
```
添加或修改以下内容：
```
[Autologin]
User=your_username
Session=plasma.desktop
```

### 2. 防止唤醒后锁屏（KDE 关键步骤）

这是实现「唤醒即用」的核心设置：

1.  打开 **系统设置**
2.  进入 **安全性与隐私** → **屏幕锁定**
3.  **取消勾选**「自动锁定屏幕」，或将等待时间设为「永不」

---

## 四、Steam 相关配置

### 1. 安装 Steam

从 [Steam 官网](https://store.steampowered.com/about/) 下载 `.deb` 安装包，然后使用以下命令安装：
```
sudo dpkg --add-architecture i386 && sudo apt update
sudo dpkg -i steam_latest.deb
sudo apt-get install -f  # 修复依赖关系
```

### 2. 选择 Steam 启动模式

有三种主要模式可以让 Steam 以大屏模式启动，请根据需求选择一种：

#### 模式一：Openbox 专用会话（推荐）
此模式创建一个独立的轻量级会话，完全脱离 KDE，资源占用最低，体验最接近游戏机。

**第一步：安装 Openbox 窗口管理器**
```
sudo apt install openbox
```

**第二步：编写自定义会话启动脚本**
```
sudo nano /usr/local/bin/steam-session
```
将以下内容粘贴到编辑器中：
```bash
#!/bin/bash
# Steam Only Session with Display Replication
# 精确匹配：eDP 和 eDP-1 为内置，其他所有已连接且不是内置的为外置

# 关闭 KDE 相关服务
export KDE_FULL_SESSION=false
export KDE_SESSION_VERSION=0

# 函数：检测内置屏幕（精确匹配 eDP 和 eDP-1）
detect_internal_display() {
    # 先检查是否有 eDP 或 eDP-1 连接
    for internal in "eDP" "eDP-1"; do
        if xrandr --current | grep -q "^$internal connected"; then
            echo "$internal"
            return 0
        fi
    done
    echo ""
}

# 函数：检测第一个可用的外置屏幕
# 规则：所有已连接且不是内置屏幕的显示器
detect_external_display() {
    local internal="$1"
    
    # 如果没有内置屏幕，则第一个连接的显示器就是主屏
    if [ -z "$internal" ]; then
        xrandr --current | grep " connected" | head -n1 | cut -d' ' -f1
        return 0
    fi
    
    # 列出所有已连接且不是内置屏幕的显示器，取第一个
    xrandr --current | grep " connected" | while read -r line; do
        display=$(echo "$line" | cut -d' ' -f1)
        if [ "$display" != "$internal" ]; then
            echo "$display"
            return 0
        fi
    done
    echo ""
}

echo "正在配置显示器..."

# 获取显示器名称
INTERNAL=$(detect_internal_display)
EXTERNAL=$(detect_external_display "$INTERNAL")

echo "检测到内置屏幕: ${INTERNAL:-无}"
echo "检测到外置屏幕: ${EXTERNAL:-无}"

# 先关闭所有显示器，避免配置冲突
echo "重置所有显示器..."
xrandr --listmonitors 2>/dev/null | grep -oP '\S+(?=\s+[0-9]+)' | while read -r mon; do
    echo "关闭显示器: $mon"
    xrandr --output "$mon" --off 2>/dev/null
done

# sleep 1

# 配置显示器
if [ -n "$INTERNAL" ]; then
    # 先启动内置屏幕
    echo "启用内置屏幕 $INTERNAL 为 1920x1080..."
    xrandr --output "$INTERNAL" --primary --mode 1080x1920 --pos 0x0 --rotate left
    
    if [ -n "$EXTERNAL" ]; then
        echo "检测到外置屏幕 $EXTERNAL，设置为复制模式..."
        # 设置外置屏幕复制内置屏幕
        xrandr --output "$EXTERNAL" --mode 1920x1080 --rotate normal --pos 0x0
        echo "复制模式已应用：$INTERNAL ←→ $EXTERNAL"
    else
        echo "仅使用内置屏幕"
    fi
elif [ -n "$EXTERNAL" ]; then
    echo "仅检测到外置屏幕 $EXTERNAL，使用单屏模式..."
    xrandr --output "$EXTERNAL" --mode 1920x1080 --primary
else
    echo "错误：未检测到任何显示器！"
    exit 1
fi

# 显示最终配置
echo ""
echo "当前显示配置："
xrandr --current | grep -E " connected|\*" | while read -r line; do
    if echo "$line" | grep -q "connected"; then
        echo "$line"
    else
        echo "   └─ $line"
    fi
done

# 直接启动 Steam 全屏模式
echo ""
echo "启动 Openbox 窗口管理器..."
openbox --replace &

# sleep 1

echo "启动 Steam 全屏模式..."
steam -fullscreen -bigpicture -dev

# 清理 Openbox 进程
killall openbox 2>/dev/null

# 当 Steam 退出时，结束会话
exit 0
```
保存文件并退出。为脚本添加可执行权限：
```
sudo chmod +x /usr/local/bin/steam-session
```

**第三步：为 SDDM 创建自定义会话文件**
```
sudo nano /usr/share/xsessions/steam-session.desktop
```
填入以下内容：
```
[Desktop Entry]
Name=Steam
Comment=Launches Steam directly without KDE Plasma
Exec=/usr/local/bin/steam-session
Type=Application
DesktopNames=KDE
```
保存并退出文件。

**第三步：配置自动登录为此会话**
修改 SDDM 配置，将 `Session` 改为上一步创建的文件名（不含路径）：
```
sudo nano /etc/sddm.conf
```
```
[Autologin]
User=your_username
Session=steam-session.desktop
```

#### 模式二：KDE 桌面 + Steam 自启动
此模式保留完整的 KDE 桌面环境，通过自启动项在登录后自动运行 Steam 大屏模式。

**配置 Steam 开机自启（仅适用于 KDE 桌面模式）**
创建自启动文件，让 Steam 在登录 KDE 桌面后自动以全屏大屏模式启动：
```
nano ~/.config/autostart/steam-big-picture.desktop
```
粘贴以下内容：
```
[Desktop Entry]
Type=Application
Name=Steam Big Picture
Exec=steam -bigpicture
X-GNOME-Autostart-Phase=Applications
X-GNOME-AutoRestart=false
X-GNOME-Autostart-Notify=false
X-KDE-autostart-after=panel
```
**说明**：`Exec=steam -bigpicture` 中的 `-bigpicture` 参数强制 Steam 以**大屏模式**启动。

**自动登录配置**：保持 [SDDM 自动登录配置](#对于-sddmkde-桌面) 中的 `Session=plasma.desktop` 不变。

#### 模式三：Gamescope 会话（不推荐）
此模式使用 Valve 开发的 Gamescope 合成器创建独立的游戏会话，技术最先进但可能存在不可预测的问题（如按电源键崩溃）。

**编译安装 Gamescope (Debian 13 及以上)**
```
# 克隆 Gamescope 仓库
git clone https://github.com/ValveSoftware/gamescope.git
cd gamescope

# 安装编译依赖
sudo apt build-dep gamescope
sudo apt install meson ninja-build libdrm-dev libgbm-dev libx11-xcb-dev libxcb-composite0-dev libxcb-damage0-dev libxcb-dpms0-dev libxcb-ewmh-dev libxcb-icccm4-dev libxcb-present-dev libxcb-randr0-dev libxcb-render-util0-dev libxcb-render0-dev libxcb-res0-dev libxcb-shape0-dev libxcb-shm0-dev libxcb-sync-dev libxcb-util-dev libxcb-xfixes0-dev libxcb-xinput-dev libxcb-xv-dev libxcb-xvmc-dev libwayland-dev wayland-protocols libinput-dev libpipewire-0.3-dev libxmu6

# 编译
meson setup build
ninja -C build

# 安装
sudo ninja -C build install
```

**创建 Gamescope 会话启动脚本**
```
sudo nano /usr/local/bin/gamescope-session
```
```
#!/bin/bash
# Steam 大屏幕模式的 Gamescope 独立会话脚本

# 设置必要的环境变量，模拟一个完整的会话
export XDG_SESSION_TYPE=wayland
export XDG_SESSION_CLASS=user
export XDG_CURRENT_DESKTOP=gamescope
export XDG_SESSION_DESKTOP=gamescope

# 启动 Gamescope 嵌入式会话
# -e: 启用 Steam 集成
# -f: 启动时全屏
# -- 后面的命令是要在 Gamescope 中运行的程序
exec /usr/local/bin/gamescope -e -f -- /usr/bin/steam -bigpicture
```
赋予执行权限：
```
sudo chmod a+x /usr/local/bin/gamescope-session
```

**创建 Desktop Entry 文件供显示管理器识别**
```
sudo nano /usr/share/wayland-sessions/gamescope-steam.desktop
```
```
[Desktop Entry]
Name=Gamescope (Steam Big Picture)
Comment=Launch a dedicated Steam Big Picture session using Gamescope
Exec=/usr/local/bin/gamescope-session
Type=Application
DesktopNames=gamescope
```

**配置自动登录为此会话**
修改 SDDM 配置：
```
sudo nano /etc/sddm.conf
```
```
[Autologin]
User=your_username
Session=gamescope-steam.desktop
```

---

## 五、手柄与插件支持

### 1. 手柄驱动：InputPlumber
为获得最佳的手柄体验，推荐安装 [InputPlumber](https://github.com/ShadowBlip/InputPlumber)，它提供了类似 SteamOS 的手柄输入处理机制。
```
# 请参考项目官方文档进行安装
# https://github.com/ShadowBlip/InputPlumber#installation
```
InputPlumber 能够将内置控制器识别为标准 Xbox 手柄，同时支持陀螺仪等功能，是实现 SteamOS 般游戏体验的重要组件。

### 2. Decky Loader 插件支持
安装 Decky Loader 可以为游戏模式添加丰富的插件功能：
```
# 使用官方安装脚本，建议选择网络较好的时段执行
curl -L https://github.com/SteamDeckHomebrew/decky-installer/releases/latest/download/install_release.sh | sh
```

---

## 六、防止启动时黑屏
某些配置下，系统启动或唤醒后可能出现屏幕无法正常点亮的情况。添加一个快速 DPMS 刷新服务可以有效解决这个问题（此方法适用于所有模式，但主要针对使用 X11 的 Openbox 和 KDE 模式）：

```
# 创建自启动目录（如果不存在）
mkdir -p ~/.config/autostart

# 创建 DPMS 刷新服务
nano ~/.config/autostart/dpms-refresh.desktop
```
粘贴以下内容：
```
[Desktop Entry]
Type=Application
Name=Quick Sleep Wake
Comment=Quick sleep/wake cycle to refresh display
Exec=bash -c "xset dpms force standby && sleep 1 && xset dpms force on"
X-GNOME-Autostart-enabled=true
X-KDE-autostart-after=plasma-core
Terminal=false
StartupNotify=false
```

## 七、笔记
### 1. 解决 KDE 下 Chromium 系浏览器中文输入法问题

在 KDE Plasma 桌面环境下，Chromium、Chrome、Edge 等浏览器默认可能无法使用中文输入法。通过创建全局配置文件可一劳永逸地解决此问题。

#### 解决方案：创建浏览器启动参数配置文件

1.  **创建配置文件**：
    ```
    nano ~/.config/chromium-flags.conf
    ```

2.  **写入以下参数**（每行一个）：
    ```
    --enable-features=UseOzonePlatform
    --ozone-platform=wayland
    --enable-wayland-ime
    ```

保存并退出。此后，所有基于 Chromium 的浏览器在启动时将自动应用这些参数，无需再单独修改每个浏览器的桌面启动器。

---

这个小技巧会在桌面启动后快速执行一个显示器的睡眠唤醒循环，强制刷新屏幕显示，有效解决因驱动或硬件兼容性问题导致的黑屏。

---

现在，你的 Debian 掌机已经拥有了近似 SteamOS 的便捷体验。唤醒设备，即刻开玩！🎮

---

*本文配置基于 Debian trixie 版本，KDE Plasma 桌面环境。其他桌面环境请相应调整显示管理器相关配置。*