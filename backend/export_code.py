import os

# 我们不需要把虚拟环境和缓存发给 AI
IGNORE_DIRS = {'.venv', 'venv', '__pycache__', '.git', '.idea'}

def export_project_code():
    output_file = 'backend_all_code.txt'
    
    with open(output_file, 'w', encoding='utf-8') as outfile:
        for root, dirs, files in os.walk('.'):
            # 动态过滤掉不需要的隐藏文件夹和依赖包
            dirs[:] = [d for d in dirs if d not in IGNORE_DIRS]
            
            for file in files:
                # 我们只抓取 Python 源文件
                if file.endswith('.py') and file != 'export_code.py':
                    filepath = os.path.join(root, file)
                    
                    # 打印漂亮的分隔符和文件路径，方便我阅读
                    outfile.write(f"\n{'='*60}\n")
                    outfile.write(f"📁 File: {filepath}\n")
                    outfile.write(f"{'='*60}\n\n")
                    
                    try:
                        with open(filepath, 'r', encoding='utf-8') as infile:
                            outfile.write(infile.read())
                    except Exception as e:
                        outfile.write(f"# 读取文件失败: {e}\n")
                        
    print(f"🎉 代码提取完成！请打开 {output_file} 全选复制给 Gemini。")

if __name__ == '__main__':
    export_project_code()