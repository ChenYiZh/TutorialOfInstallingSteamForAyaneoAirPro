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