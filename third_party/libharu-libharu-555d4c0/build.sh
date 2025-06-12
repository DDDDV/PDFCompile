#!/bin/bash
# libharu构建脚本

set -e

# 创建构建目录
mkdir -p build
cd build

# 配置和构建
cmake .. -DCMAKE_BUILD_TYPE=Debug \
         -DCMAKE_INSTALL_PREFIX=../../build/libharu \
         -DZLIB_ROOT=../../build/zlib \
         -DPNG_ROOT=../../build/libpng \
         -DLIBHPDF_EXAMPLES=ON 

make -j$(nproc)
make install

echo "libharu构建完成"