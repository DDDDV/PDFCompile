#!/bin/bash

#遇到错误立即退出
set -e

# 创建构建目录
mkdir -p build
cd build

cmake ..    -DCMAKE_BUILD_TYPE=Debug \
            -DCMAKE_INSTALL_PREFIX=../../build/openjpeg \

make -j$(nproc)
make install

echo "openjpeg构建完成"
