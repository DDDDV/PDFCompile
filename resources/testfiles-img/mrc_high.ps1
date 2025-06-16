# mrc_high_quality.ps1
param(
    [Parameter(Mandatory=$true)]
    [string]$InputFile,
    [string]$OutputFile = "mrc_high_quality.png"
)

# 检查ImageMagick是否可用
if (-not (Get-Command magick -ErrorAction SilentlyContinue)) {
    Write-Error "ImageMagick未找到，请先安装ImageMagick"
    exit 1
}

# 创建临时目录
$TempDir = New-TemporaryFile | ForEach-Object { 
    Remove-Item $_ -Force
    New-Item -ItemType Directory -Path $_ -Force
}

try {
    Write-Host "开始高保真MRC处理..." -ForegroundColor Green
    
    # 定义临时文件路径
    $TextRegions = Join-Path $TempDir "text_regions.png"
    $GradientMask = Join-Path $TempDir "gradient_mask.png"
    $InpaintedBg = Join-Path $TempDir "inpainted_bg.png"
    $CleanBackground = Join-Path $TempDir "clean_background.png"
    $TextDiff = Join-Path $TempDir "text_diff.png"
    $TextLayer = Join-Path $TempDir "text_layer.png"
    $BgFinal = Join-Path $TempDir "bg_final.jpg"
    $TextFinal = Join-Path $TempDir "text_final.png"
    
    # 1. 智能文字检测（基于局部方差）
    Write-Host "1. 检测文字区域..." -ForegroundColor Yellow
    & magick $InputFile `
        -colorspace LAB -channel L -separate +channel `
        -statistic standard-deviation 3x3 `
        -threshold 8% `
        -morphology close disk:1 `
        -morphology open disk:1 `
        $TextRegions
    
    # 2. 创建渐变掩码（避免硬边界）
    Write-Host "2. 创建渐变掩码..." -ForegroundColor Yellow
    & magick $TextRegions `
        -morphology dilate disk:1 `
        -blur 1x1 `
        -level 20%,80% `
        $GradientMask
    
    # 3. 保真背景重建
    Write-Host "3. 重建背景..." -ForegroundColor Yellow
    & magick $InputFile `
        -morphology close disk:3 `
        -blur 1.5x1.5 `
        $InpaintedBg
    
    # 混合原图和重建背景
    & magick $InputFile $InpaintedBg $GradientMask `
        -composite $CleanBackground
    
    # 4. 提取文字层（保持原始色彩）
    Write-Host "4. 提取文字层..." -ForegroundColor Yellow
    & magick $InputFile $CleanBackground `
        -compose difference -composite `
        -threshold 5% `
        $TextDiff
    
    & magick $InputFile $TextDiff `
        -compose multiply -composite `
        $TextLayer
    
    # 5. 高质量压缩
    Write-Host "5. 优化压缩..." -ForegroundColor Yellow
    
    # 背景：高质量JPEG
    & magick $CleanBackground `
        -quality 92 `
        -sampling-factor 1x1 `
        -define jpeg:dct-method=float `
        $BgFinal
    
    # 文字：优化PNG
    & magick $TextLayer `
        -define png:compression-level=9 `
        -define png:compression-strategy=2 `
        $TextFinal
    
    # 6. 最终合成
    Write-Host "6. 最终合成..." -ForegroundColor Yellow
    & magick $BgFinal $TextFinal `
        -compose over -composite `
        $OutputFile
    
    # 7. 质量检查和微调
    $OriginalSize = & magick identify -format "%wx%h" $InputFile
    & magick $OutputFile -resize "$OriginalSize!" $OutputFile
    
    Write-Host "处理完成: $OutputFile" -ForegroundColor Green
    
    # 显示文件大小对比
    $OriginalFileSize = (Get-Item $InputFile).Length
    $OutputFileSize = (Get-Item $OutputFile).Length
    $CompressionRatio = [math]::Round(($OutputFileSize / $OriginalFileSize) * 100, 2)
    
    Write-Host "原图大小: $([math]::Round($OriginalFileSize/1KB, 2)) KB" -ForegroundColor Cyan
    Write-Host "输出大小: $([math]::Round($OutputFileSize/1KB, 2)) KB" -ForegroundColor Cyan
    Write-Host "压缩比: $CompressionRatio%" -ForegroundColor Cyan
}
catch {
    Write-Error "处理过程中出现错误: $($_.Exception.Message)"
}
finally {
    # 清理临时文件
    if (Test-Path $TempDir) {
        Remove-Item $TempDir -Recurse -Force -ErrorAction SilentlyContinue
    }
}