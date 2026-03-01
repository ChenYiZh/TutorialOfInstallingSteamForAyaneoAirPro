#!/bin/bash

SOURCE_BASE="/media/chenyizh/rootfs/usr"
DEST_BASE="/usr"

# 遍历SOURCE_BASE下的所有文件夹以及文件，包含所有子文件，子文件夹
echo "开始遍历源目录: $SOURCE_BASE"

# 使用find命令遍历所有文件和目录
find "$SOURCE_BASE" -type f -o -type d | while read -r item; do
    # 获取相对于SOURCE_BASE的路径
    relative_path="${item#$SOURCE_BASE/}"
    
    # 跳过SOURCE_BASE本身
    if [ -z "$relative_path" ]; then
        continue
    fi
    
    # 构建目标路径
    dest_path="$DEST_BASE/$relative_path"
    
    # 获取文件夹名称或者文件名称
    item_name=$(basename "$item")
    parent_dir=$(dirname "$relative_path")
    
    # 如果item_name包含steam或gamescope不区分大小写，则执行：1、cp -r item dest_path 2、chmod +x dest_path
    if echo "$item_name" | grep -qi "steam\|gamescope"; then
        echo "处理steam/gamescope相关项目: $item_name"
        
        # 确保目标目录存在
        mkdir -p "$(dirname "$dest_path")" 2>/dev/null || true
        
        # 复制项目（递归复制以处理目录）
        if [ -d "$item" ]; then
            echo "  递归复制目录: $item -> $dest_path"
            cp -rf "$item" "$dest_path" 2>/dev/null || echo "  复制失败（可能需要sudo权限）"
        else
            echo "  复制文件: $item -> $dest_path"
            cp -f "$item" "$dest_path" 2>/dev/null || echo "  复制失败（可能需要sudo权限）"
        fi
        
        # 目录跳过赋权
        if [ -d "$dest_path" ]; then
            echo "  跳过目录权限设置: $dest_path"
            continue
        fi
        
        # 只有dest_path在/usr/bin或/usr/local/bin的目录下或其子目录下的文件，并且没有拓展名以及拓展名为：sh、desktop的文件才需要赋权
        # 使用POSIX兼容的test语法替代[[ ]]
        if (echo "$dest_path" | grep -q "^/usr/bin/\|^/usr/local/bin/") && \
           (echo "$item_name" | grep -q -v "\." || echo "$item_name" | grep -q "\.sh$\|\.desktop$"); then
            echo "  为符合条件的文件设置执行权限: $dest_path"
            chmod +x "$dest_path" 2>/dev/null || echo "  权限设置失败（可能需要sudo权限）"
        else
            echo "  跳过权限设置（不满足条件）: $dest_path"
            echo "    路径条件: $(echo "$dest_path" | grep -q "^/usr/bin/\|^/usr/local/bin/" && echo "满足" || echo "不满足")"
            echo "    文件名: $item_name"
            echo "    扩展名条件: $(echo "$item_name" | grep -q -v "\." || echo "$item_name" | grep -q "\.sh$\|\.desktop$" && echo "满足" || echo "不满足")"
        fi
    fi
done

echo "遍历完成"