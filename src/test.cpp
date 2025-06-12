#include "hpdf.h"
#include "openjpeg.h"

#include <stdlib.h>
#include <stdio.h>
#include <string.h>
#include <setjmp.h>
#include "hpdf.h"
#include "jpeg_comp.h"
#include "tiffio.h"

static const char *png_name = "test.png";

int main(){
    printf("tiff version %s\n", TIFFGetVersion());
    printf("HPDF version %s\n", HPDF_GetVersion());
    printf("jpeg version %s\n", opj_version());
    return 0;
}