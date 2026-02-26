#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
更新strokes.txt文件，将sbjm.extended.dict.yaml中单字编码的第二、三码作为前两笔添加到strokes.txt中
"""

import os
import re

def main():
    # 文件路径
    sbjm_dict_path = os.path.join(os.path.dirname(__file__), '../sbxlm/sbjm.extended.dict.yaml')
    strokes_path = os.path.join(os.path.dirname(__file__), '../sbxlm/lua/sbxlm/strokes.txt')
    output_path = os.path.join(os.path.dirname(__file__), '../sbxlm/lua/sbxlm/strokes.txt.new')
    
    print(f"读取文件: {sbjm_dict_path}")
    print(f"读取文件: {strokes_path}")
    print(f"输出文件: {output_path}")
    
    # 1. 读取sbjm.extended.dict.yaml，提取单字编码的第二、三码
    char_strokes = {}
    with open(sbjm_dict_path, 'r', encoding='utf-8') as f:
        for line in f:
            line = line.strip()
            if not line or line.startswith('#') or line.startswith('---') or line.startswith('...'):
                continue
            # 匹配单字行：单字\t编码\t权重
            match = re.match(r'^(.)\t([a-z0-9]+)\t\d+$', line)
            if match:
                char = match.group(1)
                code = match.group(2)
                if len(code) >= 3:
                    # 提取第二、三码作为前两笔
                    first_two_strokes = code[1:3]
                    char_strokes[char] = first_two_strokes
    
    print(f"从sbjm.extended.dict.yaml中提取了 {len(char_strokes)} 个单字的前两笔")
    
    # 2. 读取strokes.txt，更新笔画编码
    updated_lines = []
    updated_count = 0
    with open(strokes_path, 'r', encoding='utf-8') as f:
        for line in f:
            line = line.strip()
            if not line:
                updated_lines.append(line)
                continue
            # 匹配strokes.txt行：单字\t笔画编码
            match = re.match(r'^(.)\t([a-z]+)$', line)
            if match:
                char = match.group(1)
                existing_strokes = match.group(2)
                if char in char_strokes:
                    # 添加前两笔
                    new_strokes = char_strokes[char] + existing_strokes
                    updated_lines.append(f"{char}\t{new_strokes}")
                    updated_count += 1
                else:
                    # 保持原有编码
                    updated_lines.append(line)
            else:
                # 保持原有行
                updated_lines.append(line)
    
    # 3. 写入新文件
    with open(output_path, 'w', encoding='utf-8') as f:
        f.write('\n'.join(updated_lines))
    
    print(f"更新完成，共更新了 {updated_count} 个单字的笔画编码")
    print(f"新文件已生成: {output_path}")
    print("请检查新文件，确认无误后替换原文件")

if __name__ == '__main__':
    main()
