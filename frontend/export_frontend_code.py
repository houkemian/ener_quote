import os

# 🌟 核心拦截网：绝对不能去碰的 Flutter 缓存和原生平台壳目录
IGNORE_DIRS = {
    '.git', '.idea', '.dart_tool', 'build',
    'android', 'ios', 'web', 'windows', 'macos', 'linux'
}

# 🌟 我们只关心 Dart 代码、YAML 配置和 ARB 多语言字典
TARGET_EXTENSIONS = {'.dart', '.yaml', '.arb'}

def export_frontend_code(target_dir):
    output_file = 'frontend_all_code.txt'

    # 确保保存输出文件的路径是在当前运行脚本的目录下
    output_path = os.path.join(os.getcwd(), output_file)

    with open(output_path, 'w', encoding='utf-8') as outfile:
        for root, dirs, files in os.walk(target_dir):
            # 动态过滤掉黑名单文件夹，防止陷入几万个缓存文件的深渊
            dirs[:] = [d for d in dirs if d not in IGNORE_DIRS]

            for file in files:
                # 筛选指定后缀，并且跳过提取脚本自身（如果它刚好放在该目录）
                if any(file.endswith(ext) for ext in TARGET_EXTENSIONS) and file != 'export_frontend_code.py':
                    filepath = os.path.join(root, file)

                    # 打印漂亮的分隔符和文件路径，方便 AI 阅读上下文
                    outfile.write(f"\n{'='*60}\n")
                    outfile.write(f"📁 File: {filepath}\n")
                    outfile.write(f"{'='*60}\n\n")

                    try:
                        with open(filepath, 'r', encoding='utf-8') as infile:
                            outfile.write(infile.read())
                    except Exception as e:
                        outfile.write(f"# 读取文件失败: {e}\n")

    print(f"🎉 前端代码提取完成！请打开 {output_path} 全选复制。")

if __name__ == '__main__':
    # 🎯 你的前端项目绝对路径
    FRONTEND_DIR = r"D:\APP\pv_ess_quote_frontend"
    export_frontend_code(FRONTEND_DIR)