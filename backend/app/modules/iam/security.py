import bcrypt

def verify_password(plain_password: str, hashed_password: str) -> bool:
    """验证密码是否正确"""
    # bcrypt 要求必须是 bytes 类型，所以要 encode
    password_bytes = plain_password.encode('utf-8')
    hash_bytes = hashed_password.encode('utf-8')
    return bcrypt.checkpw(password_bytes, hash_bytes)

def get_password_hash(password: str) -> str:
    """将明文密码进行加盐哈希"""
    password_bytes = password.encode('utf-8')
    # 生成随机盐并加密
    salt = bcrypt.gensalt()
    hashed_bytes = bcrypt.hashpw(password_bytes, salt)
    # 存入数据库的是字符串，所以解码回 str
    return hashed_bytes.decode('utf-8')