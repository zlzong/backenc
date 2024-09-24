#!/bin/bash

# 默认参数
SOURCE_DIR=""
DEST_DIR=""
KEY=""
DB_FILE="./processed_files.db"
SCAN_INTERVAL=10
WRITE_CHECK_INTERVAL=5

# 帮助信息
show_help() {
  echo "Usage: $0 -s SOURCE_DIR -d DEST_DIR -k KEY"
  echo ""
  echo "Options:"
  echo "  -s    Source directory to monitor for new files."
  echo "  -d    Destination directory to store encrypted files."
  echo "  -k    AES-256 encryption key (32 bytes)."
  exit 1
}

# 解析命令行参数
while getopts "s:d:k:" opt; do
  case "$opt" in
    s) SOURCE_DIR=$OPTARG ;;
    d) DEST_DIR=$OPTARG ;;
    k) KEY=$OPTARG ;;
    *) show_help ;;
  esac
done

# 检查是否所有必需参数都已提供
if [ -z "$SOURCE_DIR" ] || [ -z "$DEST_DIR" ] || [ -z "$KEY" ]; then
  echo "Error: Missing required arguments."
  show_help
fi

# 确保目标文件夹存在
mkdir -p "$DEST_DIR"

# 初始化 SQLite 数据库表
init_db() {
  sqlite3 "$DB_FILE" <<EOF
CREATE TABLE IF NOT EXISTS processed_files (
  filepath TEXT PRIMARY KEY
);
CREATE TABLE IF NOT EXISTS file_write_progress (
  filepath TEXT PRIMARY KEY,
  filesize INTEGER
);
EOF
}

timestamp=$(date +"%Y%m%d%H%M%S")

# 使用 AES-256 加密文件
encrypt_file() {
  local filepath="$1"
  local filename=$(basename "$filepath")
  local dest_filepath="$DEST_DIR/${filename}_$timestamp.zenc"

  # 使用 openssl 进行 AES-256-CBC 加密
  openssl enc -aes-256-cbc -salt -in "$filepath" -out "$dest_filepath" -pass pass:"$KEY" -pbkdf2

  if [ $? -eq 0 ]; then
    echo "Encrypted file saved to: $dest_filepath"
    # 记录已处理文件到 SQLite 数据库
    sqlite3 "$DB_FILE" "INSERT INTO processed_files (filepath) VALUES ('$filepath');"
    # 删除文件进度记录
    sqlite3 "$DB_FILE" "DELETE FROM file_write_progress WHERE filepath = '$filepath';"
  else
    echo "Failed to encrypt file: $filepath"
  fi
}

# 检查文件是否仍在写入中
check_file_writing() {
  local filepath="$1"
  local current_size=$(stat --printf="%s" "$filepath")
  
  # 查询数据库中的上一次记录的文件大小
  local last_size=$(sqlite3 "$DB_FILE" "SELECT filesize FROM file_write_progress WHERE filepath = '$filepath';")

  # 如果文件还没有被记录，插入初始文件大小
  if [ -z "$last_size" ]; then
    sqlite3 "$DB_FILE" "INSERT INTO file_write_progress (filepath, filesize) VALUES ('$filepath', $current_size);"
    return 0  # 文件还在写入中，暂不处理
  fi

  # 如果文件大小没有变化，认为写入完成
  if [ "$last_size" -eq "$current_size" ]; then
    echo "File write complete: $filepath"
    return 1  # 文件写入已完成
  else
    # 更新文件大小记录
    sqlite3 "$DB_FILE" "UPDATE file_write_progress SET filesize = $current_size WHERE filepath = '$filepath';"
    return 0  # 文件还在写入中
  fi
}

# 定期扫描目录，查找新增文件并进行加密
scan_directory() {
  echo "Scanning directory: $SOURCE_DIR"

  # 查找源目录中所有的文件，并检查它们是否已经处理过
  find "$SOURCE_DIR" -type f | while read NEW_FILE
  do
    # 检查文件是否已处理过
    local is_processed=$(sqlite3 "$DB_FILE" "SELECT COUNT(*) FROM processed_files WHERE filepath='$NEW_FILE';")
    if [ "$is_processed" -eq 0 ]; then
      # 检查文件是否还在写入
      if check_file_writing "$NEW_FILE"; then
        echo "New file detected and write completed: $NEW_FILE"

        # 加密文件
        encrypt_file "$NEW_FILE"
      else
        echo "File is still being written: $NEW_FILE"
      fi
    else
      echo "File already processed: $NEW_FILE"
    fi
  done
}

# 初始化数据库
init_db

# 扫描目录
scan_directory
