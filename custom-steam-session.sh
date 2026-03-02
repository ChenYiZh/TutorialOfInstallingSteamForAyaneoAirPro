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

# 新增功能1：创建Openbox配置文件，将电源键改为睡眠
create_openbox_config() {
    local config_dir="$HOME/.config/openbox"
    local config_file="$config_dir/rc.xml"
    local backup_file="$config_dir/rc.xml.backup"
    
    # 创建配置目录
    mkdir -p "$config_dir"
    
    # 检查配置文件是否存在
    if [ -f "$config_file" ]; then
        echo "检测到已存在的Openbox配置文件"
        
        # 检查是否已包含电源键配置
        if grep -q "XF86PowerOff" "$config_file" || grep -q "XF86Sleep" "$config_file"; then
            echo "配置文件已包含电源键设置，跳过创建"
            return 0
        fi
        
        # 备份原配置文件
        echo "备份原配置文件到: $backup_file"
        cp "$config_file" "$backup_file"
        
        # 检查是否有<keyboard>标签
        if grep -q "<keyboard>" "$config_file"; then
            echo "在现有配置中添加电源键设置..."
            # 在<keyboard>标签后添加电源键配置
            sed -i '/<keyboard>/a\    <keybind key="XF86PowerOff">\n      <action name="Execute">\n        <command>systemctl suspend</command>\n      </action>\n    </keybind>\n    <keybind key="XF86Sleep">\n      <action name="Execute">\n        <command>systemctl suspend</command>\n      </action>\n    </keybind>' "$config_file"
            echo "电源键配置已添加到现有文件"
        else
            echo "现有配置中没有<keyboard>标签，创建新配置..."
            # 创建包含电源键配置的新文件
            cat > "$config_file" << 'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<openbox_config xmlns="http://openbox.org/3.4/rc">
  <keyboard>
    <keybind key="XF86PowerOff">
      <action name="Execute">
        <command>systemctl suspend</command>
      </action>
    </keybind>
    <keybind key="XF86Sleep">
      <action name="Execute">
        <command>systemctl suspend</command>
      </action>
    </keybind>
  </keyboard>
</openbox_config>
EOF
            echo "新配置文件已创建"
        fi
    else
        echo "创建新的Openbox配置文件..."
        # 创建Openbox配置文件
        cat > "$config_file" << 'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<openbox_config xmlns="http://openbox.org/3.4/rc">
  <keyboard>
    <keybind key="XF86PowerOff">
      <action name="Execute">
        <command>systemctl suspend</command>
      </action>
    </keybind>
    <keybind key="XF86Sleep">
      <action name="Execute">
        <command>systemctl suspend</command>
      </action>
    </keybind>
  </keyboard>
</openbox_config>
EOF
        echo "Openbox配置文件已创建：电源键映射为睡眠"
    fi
}

# 新增功能2：旋转触摸坐标90度
rotate_touch_coordinates() {
    # 查找所有触摸屏设备
    local touch_devices=$(xinput list --name-only | grep -i touch)
    
    if [ -z "$touch_devices" ]; then
        echo "未检测到触摸屏设备"
        return 1
    fi
    
    echo "检测到触摸屏设备："
    echo "$touch_devices"
    
    # 对每个触摸屏设备应用90度旋转
    echo "$touch_devices" | while read -r device; do
        if [ -n "$device" ]; then
            echo "旋转触摸屏 '$device' 90度..."
            xinput set-prop "$device" 'Coordinate Transformation Matrix' 0 -1 1 1 0 0 0 0 1
            if [ $? -eq 0 ]; then
                echo "  ✓ '$device' 旋转成功"
            else
                echo "  ✗ '$device' 旋转失败"
            fi
        fi
    done
}

# 新增功能3：隐藏鼠标光标
hide_mouse_cursor() {
    # 方法1：使用unclutter隐藏鼠标
    if command -v unclutter &> /dev/null; then
        echo "使用unclutter隐藏鼠标光标..."
        unclutter -idle 0.1 -root &
        echo "unclutter进程已启动"
        return 0
    fi
    
    # 方法2：使用xdotool隐藏鼠标
    if command -v xdotool &> /dev/null; then
        echo "使用xdotool隐藏鼠标光标..."
        xdotool mousemove 10000 10000
        echo "鼠标已移动到屏幕外"
        return 0
    fi
    
    # 方法3：使用xsetroot设置透明光标
    if command -v xsetroot &> /dev/null; then
        echo "使用xsetroot设置透明光标..."
        xsetroot -cursor_name left_ptr -cursor /dev/null
        echo "透明光标已设置"
        return 0
    fi
    
    echo "警告：未找到隐藏鼠标的工具（unclutter/xdotool/xsetroot）"
    return 1
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

# 新增功能执行部分
echo ""
echo "=== 新增功能配置 ==="

# 1. 创建Openbox配置文件（电源键改为睡眠）
echo "1. 配置Openbox电源键事件..."
create_openbox_config

# 2. 旋转触摸坐标90度
echo ""
echo "2. 配置触摸屏旋转..."
rotate_touch_coordinates

# 3. 隐藏鼠标光标
echo ""
echo "3. 隐藏鼠标光标..."
hide_mouse_cursor

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