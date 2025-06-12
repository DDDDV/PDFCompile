#!/bin/bash
# zlib构建脚本

set -e

# 创建构建目录
mkdir -p build
cd build

# 配置和构建
cmake .. -DCMAKE_BUILD_TYPE=Debug \
         -DCMAKE_INSTALL_PREFIX=../../build/zlib

make -j$(nproc)
make install

echo "zlib构建完成"