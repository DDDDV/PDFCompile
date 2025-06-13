#include <stdlib.h>
#include <stdio.h>
#include <string.h>
#include <setjmp.h>

#include "headers.h"

void ShowVersion(){
    printf("tiff version %s\n", TIFFGetVersion());
    printf("HPDF version %s\n", HPDF_GetVersion());
    printf("jpeg version %s\n", opj_version());
    printf("leptonica version %s\n", getLeptonicaVersion());
}
int main(){
    ShowVersion();
}