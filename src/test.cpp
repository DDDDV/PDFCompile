#include "hpdf.h"
#include "openjpeg.h"

int main(){
    printf("test\n");
    
    const char * result = opj_version();
    printf("openjpeg version is %s\n", result);
    return 0;
}