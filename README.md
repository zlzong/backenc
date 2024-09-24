# 文件加密备份脚本
## 一、加密脚本使用方式
```sh
backenc.sh -s /源文件夹 -d /目标文件夹 -k "32位密码"
```
## 二、解密脚本使用方式
```sh
backdec.sh -e /包含加密文件的文件夹 -d /恢复之后文件存放位置 -k "32位密码"
```
## 三、需要安装的库
```sh
sudo apt install openssl
sudo apt install sqlite3
```
可以配合crontab实现定时备份
