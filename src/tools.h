#ifndef __TOOLS__H__
#define __TOOLS__H__

#include "headers.h"

static struct TIFF_FILE_BASIC_INFO{
    uint32 width, height;
    uint16 bps, spp, photometric;
}tif_file_info;

void ShowVersion();
void PrintTiffInfo(const TIFF_FILE_BASIC_INFO *info);

#endif