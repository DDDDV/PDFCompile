#include "headers.h"
#include "tools.h"
// 新增函数：输出TIFF图像信息

jmp_buf env;

void error_handler (HPDF_STATUS   error_no,
               HPDF_STATUS   detail_no,
               void         *user_data)
{
    (void) user_data; /* Not used */
    printf ("ERROR: error_no=%04X, detail_no=%u\n", (HPDF_UINT)error_no,
                (HPDF_UINT)detail_no);
    longjmp(env, 1);
}

TIFF* ReadTiffFile(const char* tiff_filename){
    TIFF* tif = TIFFOpen(tiff_filename, "r");
    // 获取图像信息
    TIFFGetField(tif, TIFFTAG_IMAGEWIDTH, &tif_file_info.width);
    TIFFGetField(tif, TIFFTAG_IMAGELENGTH, &tif_file_info.height);
    TIFFGetField(tif, TIFFTAG_BITSPERSAMPLE, &tif_file_info.bps);
    TIFFGetField(tif, TIFFTAG_SAMPLESPERPIXEL, &tif_file_info.spp);
    TIFFGetField(tif, TIFFTAG_PHOTOMETRIC, &tif_file_info.photometric);
    // 调用专门的输出函数
    PrintTiffInfo(&tif_file_info);
    printf("read tiff file success\n");
    return tif;
}

HPDF_STATUS Page_DrawImage(HPDF_Page page, HPDF_Image image, int ppi){
    HPDF_REAL width = HPDF_Image_GetWidth(image);
    HPDF_REAL height = HPDF_Image_GetHeight(image);
    HPDF_Page_DrawImage(page, image, 0, 0, width*72/ppi, height*72/ppi);
    printf("draw image success\n");
    return HPDF_OK;
}

int main(int argc, char **argv){
    ShowVersion();
    const char* background_file_jpeg = argv[1];
    const char* foreground_file_tiff = argv[2];
    TIFF* tif = ReadTiffFile(foreground_file_tiff);
    tmsize_t scanline_size = TIFFScanlineSize(tif);
    // printf("tiff scan line size is %d\n", scanline_size); //638
    unsigned char* image_data = (unsigned char*)malloc(scanline_size * tif_file_info.height);
    if (image_data == NULL) {
        fprintf(stderr, "Failed to allocate memory for TIFF image data.\n");
        TIFFClose(tif);
        return EXIT_FAILURE;
    }
    for(uint32 row = 0; row < tif_file_info.height; row++){
        TIFFReadScanline(tif, image_data + row * scanline_size, row, 0);
    }

    HPDF_ColorSpace color_space;
    switch(tif_file_info.photometric) {
        case PHOTOMETRIC_MINISBLACK:
            color_space = HPDF_CS_DEVICE_GRAY;
            break;
        case PHOTOMETRIC_RGB:
            color_space = HPDF_CS_DEVICE_RGB;
            break;
        default:
            fprintf(stderr, "Unsupported photometric interpretation: %u\n", tif_file_info.photometric);
            free(image_data);
            TIFFClose(tif);
            return EXIT_FAILURE;
    }

    HPDF_Doc pdf;
    pdf = HPDF_New(error_handler, NULL);
    HPDF_SetCompressionMode(pdf, HPDF_COMP_ALL);
    // 确保这是1位图像才能使用HPDF_Image_LoadRaw1BitImageFromMem
    if (tif_file_info.bps != 1) {
        fprintf(stderr, "Error: HPDF_Image_LoadRaw1BitImageFromMem requires 1-bit image, but got %d bits per sample\n", tif_file_info.bps);
        free(image_data);
        TIFFClose(tif);
        HPDF_Free(pdf);
        return EXIT_FAILURE;
    }
    
    // 计算每行的字节数（1位图像）
    HPDF_UINT line_width = (tif_file_info.width + 7) / 8;
    
    // 使用HPDF_Image_LoadRaw1BitImageFromMem加载1位图像
    HPDF_Image text_image = HPDF_Image_LoadRaw1BitImageFromMem(pdf, image_data, tif_file_info.width, tif_file_info.height, line_width, HPDF_TRUE, HPDF_TRUE);
    if (!text_image) {
        HPDF_CheckError(&pdf->error);
        free(image_data);
        TIFFClose(tif);
        HPDF_Free(pdf);
        return EXIT_FAILURE;
    }

    
    HPDF_Page page = HPDF_AddPage(pdf);
    HPDF_Page_SetSize(page, HPDF_PAGE_SIZE_A4, HPDF_PAGE_PORTRAIT);
    
    HPDF_Image back_image = HPDF_LoadJpegImageFromFile(pdf, background_file_jpeg);
    Page_DrawImage(page, back_image, 600);

    HPDF_Image masked_text = HPDF_Image_LoadRaw1BitImageFromMem(pdf, image_data, tif_file_info.width, tif_file_info.height, line_width, HPDF_TRUE, HPDF_TRUE);
    HPDF_Image_SetMaskImage(masked_text, text_image);
    Page_DrawImage(page, masked_text, 600);
    HPDF_STATUS status = HPDF_SaveToFile(pdf, "output.pdf");

    if (status != HPDF_OK) {
        HPDF_Free(pdf);
        free(image_data);
        TIFFClose(tif);
        return EXIT_FAILURE;
    }
    HPDF_Free(pdf);
    free(image_data);
    TIFFClose(tif);
    printf("PDF created successfully with the TIFF image.\n");

    return 0;
}