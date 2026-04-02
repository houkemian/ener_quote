import sqlite3

# 1. 连上咱们珍贵的核心数据库
conn = sqlite3.connect('pv_ess.db')
cursor = conn.cursor()

try:
    # 2. 执行 ALTER TABLE 增加字段 (注意：SQLite 支持 ADD COLUMN)
    # 语法：ALTER TABLE 表名 ADD COLUMN 字段名 数据类型;
    cursor.execute("ALTER TABLE iam_users ADD COLUMN phone VARCHAR(50);")
    conn.commit()
    print("✅ 字段追加成功！老数据毫发无损。")
except Exception as e:
    print(f"❌ 追加失败，可能是字段已经存在了：{e}")
finally:
    conn.close()