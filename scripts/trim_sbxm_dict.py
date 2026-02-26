#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
脚本功能：重新生成sbxm.extended.dict.yaml文件，只保留每个词条的前四码编码
"""

import os

def trim_sbxm_dict():
    """处理sbxm.extended.dict.yaml文件，只保留编码的前四码"""
    input_file = os.path.join(os.path.dirname(__file__), '../sbxlm/sbxm.extended.dict.yaml')
    output_file = os.path.join(os.path.dirname(__file__), '../sbxlm/sbxm.extended.dict.yaml.new')
    
    print(f"读取文件: {input_file}")
    print(f"输出文件: {output_file}")
    
    with open(input_file, 'r', encoding='utf-8') as f:
        lines = f.readlines()
    
    with open(output_file, 'w', encoding='utf-8') as f:
        # 写入文件头
        for i, line in enumerate(lines):
            if line.strip() == '...':
                f.write(line)
                break
            f.write(line)
        
        # 处理词条
        for line in lines[i+1:]:
            line = line.strip()
            if not line:
                continue
            
            parts = line.split('\t')
            if len(parts) < 2:
                f.write(line + '\n')
                continue
            
            text = parts[0]
            code = parts[1]
            weight = parts[2] if len(parts) > 2 else ''
            
            # 只保留编码的前四码
            trimmed_code = code[:4]
            
            # 写入新条目
            if weight:
                f.write(f"{text}\t{trimmed_code}\t{weight}\n")
            else:
                f.write(f"{text}\t{trimmed_code}\n")
    
    print(f"处理完成，共处理 {len(lines) - i - 1} 个词条")
    print(f"新文件已生成: {output_file}")
    print("请检查新文件，确认无误后替换原文件")

if __name__ == '__main__':
    trim_sbxm_dict()
