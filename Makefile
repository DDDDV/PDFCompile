# 简洁的Makefile用于构建libharu及其依赖项
include macro.mk

# 定义目录
THIRD_PARTY_DIR = third_party
BUILD_DIR = build
BIN_DIR = $(BUILD_DIR)
SRC_DIR = src
ZLIB_DIR = $(THIRD_PARTY_DIR)/zlib-develop
LIBPNG_DIR = $(THIRD_PARTY_DIR)/libpng-libpng16
LIBHARU_DIR = $(THIRD_PARTY_DIR)/libharu-libharu-555d4c0
OPENJPEG_DIR = $(THIRD_PARTY_DIR)/openjpeg-master
LIBTIFF_DIR = $(THIRD_PARTY_DIR)/libtiff-master

# 修正源文件路径
SRCS = $(wildcard $(SRC_DIR)/*.cpp)
OBJS = $(patsubst $(SRC_DIR)/%.cpp,$(BUILD_DIR)/%.o,$(SRCS))

# 定义头文件路径
INCLUDE_DIRS = -I$(LIBHARU_DIR)/include \
               -I$(LIBPNG_DIR) \
               -I$(ZLIB_DIR) \
               -I$(THIRD_PARTY_DIR)/build/openjpeg/include/openjpeg-2.5 \
               -I$(THIRD_PARTY_DIR)/build/libharu/include \
               -I$(THIRD_PARTY_DIR)/build/libpng/include \
               -I$(THIRD_PARTY_DIR)/build/zlib/include \
			   -I$(THIRD_PARTY_DIR)/build/libtiff/include

# 定义库文件路径
LIB_DIRS = -L$(THIRD_PARTY_DIR)/build/libharu/lib \
           -L$(THIRD_PARTY_DIR)/build/libpng/lib \
           -L$(THIRD_PARTY_DIR)/build/zlib/lib \
           -L$(THIRD_PARTY_DIR)/build/openjpeg/lib \
		   -L$(THIRD_PARTY_DIR)/build/libtiff/lib

# 添加运行时库路径
RPATH_FLAGS = -Wl,-rpath,$(CURDIR)/$(THIRD_PARTY_DIR)/build/libharu/lib \
              -Wl,-rpath,$(CURDIR)/$(THIRD_PARTY_DIR)/build/libpng/lib \
              -Wl,-rpath,$(CURDIR)/$(THIRD_PARTY_DIR)/build/zlib/lib \
              -Wl,-rpath,$(CURDIR)/$(THIRD_PARTY_DIR)/build/openjpeg/lib \
			  -Wl,-rpath,$(CURDIR)/$(THIRD_PARTY_DIR)/build/libtiff/lib 

# 定义链接库
LIBS = -lhpdf -lpng -lz -lopenjp2 -lm -ltiff

# 定义可执行程序名称
TARGET_EXEC = $(BUILD_DIR)/pdf

# 默认目标
all: $(BUILD_DIR) $(TARGET_EXEC)

# 编译可执行文件
$(TARGET_EXEC): $(OBJS)
	$(CXX) $(CFLAGS) -o $@ $^ $(LIB_DIRS) $(RPATH_FLAGS) $(LIBS)

# 编译对象文件
$(BUILD_DIR)/%.o: $(SRC_DIR)/%.cpp
	$(CXX) $(CFLAGS) $(INCLUDE_DIRS) -c $< -o $@

third_party: libharu openjpeg libtiff

# 创建构建目录
$(BUILD_DIR):
	mkdir -p $(BUILD_DIR)

# 构建zlib
zlib: $(BUILD_DIR)
	cd $(ZLIB_DIR) && ./build.sh

# 构建libpng (依赖zlib)
libpng: zlib
	cd $(LIBPNG_DIR) && ./build.sh

openjpeg:
	cd $(OPENJPEG_DIR) && ./build.sh

libtiff:
	cd $(LIBTIFF_DIR) && ./build.sh

# 构建libharu (依赖zlib和libpng)
libharu: libpng
	cd $(LIBHARU_DIR) && ./build.sh

# 清理
clean:
	rm -rf $(BUILD_DIR)
	
clean-all:
	rm -rf $(BUILD_DIR)
	cd $(ZLIB_DIR) && rm -rf build
	cd $(LIBPNG_DIR) && rm -rf build
	cd $(LIBHARU_DIR) && rm -rf build
	cd $(THIRD_PARTY_DIR) && rm -rf build
	

# 声明伪目标
.PHONY: all zlib libpng libharu openjpeg third_party clean clean-all