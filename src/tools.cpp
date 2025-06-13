#include "tools.h"

void ShowVersion(){
    printf("tiff version %s\n", TIFFGetVersion());
    printf("HPDF version %s\n", HPDF_GetVersion());
    printf("jpeg version %s\n", opj_version());
    printf("leptonica version %s\n", getLeptonicaVersion());
}

void PrintTiffInfo(const TIFF_FILE_BASIC_INFO *info) { 
    printf("=== TIFF图像信息 ===\n");
    printf("图像尺寸: %u x %u 像素\n", info->width, info->height);
    printf("每样本位数: %u 位\n", info->bps);
    printf("每像素样本数: %u\n", info->spp);
    printf("光度解释: %u ", info->photometric);
    
    // 解释光度解释的含义
    switch(info->photometric) {
        case 0:
            printf("(WhiteIsZero - 白色为0值)\n");
            break;
        case 1:
            printf("(BlackIsZero - 黑色为0值)\n");
            break;
        case 2:
            printf("(RGB彩色)\n");
            break;
        case 3:
            printf("(调色板颜色)\n");
            break;
        case 4:
            printf("(透明度掩码)\n");
            break;
        case 5:
            printf("(CMYK)\n");
            break;
        case 6:
            printf("(YCbCr)\n");
            break;
        default:
            printf("(未知格式)\n");
            break;
    }
    
    // 计算并输出额外信息
    printf("总像素数: %u\n", info->width * info->height);
    printf("图像类型: ");
    if (info->spp == 1) {
        printf("灰度图像\n");
    } else if (info->spp == 3) {
        printf("RGB彩色图像\n");
    } else if (info->spp == 4) {
        printf("RGBA或CMYK图像\n");
    } else {
        printf("%u通道图像\n", info->spp);
    }
    printf("==================\n");
}