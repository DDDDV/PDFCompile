#!/bin/bash
# libtiff构建脚本

set -e

# 创建构建目录
mkdir -p build
cd build

# 配置和构建
cmake .. -DCMAKE_BUILD_TYPE=Debug \
         -DCMAKE_INSTALL_PREFIX=../../build/libtiff \

make -j$(nproc)
make install

echo "libtiff构建完成"