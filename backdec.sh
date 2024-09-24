#!/bin/bash

# 默认参数
ENCRYPTED_DIR=""
DECRYPTED_DIR=""
KEY=""

# 帮助信息
show_help() {
  echo "Usage: $0 -e ENCRYPTED_DIR -d DECRYPTED_DIR -k KEY"
  echo ""
  echo "Options:"
  echo "  -e    Directory containing encrypted files (.enc)."
  echo "  -d    Directory to store decrypted files."
  echo "  -k    AES-256 decryption key (32 bytes)."
  exit 1
}

# 解析命令行参数
while getopts "e:d:k:" opt; do
  case "$opt" in
    e) ENCRYPTED_DIR=$OPTARG ;;
    d) DECRYPTED_DIR=$OPTARG ;;
    k) KEY=$OPTARG ;;
    *) show_help ;;
  esac
done

# 检查是否所有必需参数都已提供
if [ -z "$ENCRYPTED_DIR" ] || [ -z "$DECRYPTED_DIR" ] || [ -z "$KEY" ]; then
  echo "Error: Missing required arguments."
  show_help
fi

# 确保解密目标目录存在
mkdir -p "$DECRYPTED_DIR"

# 遍历加密目录下的所有文件并进行解密
for encrypted_file in "$ENCRYPTED_DIR"/*.enc; do
  if [ -f "$encrypted_file" ]; then
    # 获取解密后的文件名
    decrypted_filename=$(basename "$encrypted_file" .zenc)
    decrypted_filepath="$DECRYPTED_DIR/$decrypted_filename"

    # 执行解密操作
    openssl enc -d -aes-256-cbc -in "$encrypted_file" -out "$decrypted_filepath" -pass pass:"$KEY"
    
    if [ $? -eq 0 ]; then
      echo "Decrypted file saved to: $decrypted_filepath"
    else
      echo "Failed to decrypt file: $encrypted_file"
    fi
  fi
done

