# mrc_basic.ps1
param(
    [Parameter(Mandatory=$true)]
    [string]$InputFile,
    [string]$OutputFile = "mrc_output.png"
)

# 创建临时目录
$TempDir = New-TemporaryFile | ForEach-Object { Remove-Item $_; New-Item -ItemType Directory -Path $_ }
$TextMask = Join-Path $TempDir "text_mask.png"
$BgMask = Join-Path $TempDir "bg_mask.png"
$BgOnly = Join-Path $TempDir "background.jpg"
$TextOnly = Join-Path $TempDir "text.png"

try {
    Write-Host "开始MRC处理..." -ForegroundColor Green
    
    # 创建文字掩码
    & magick $InputFile -colorspace Gray -threshold 65% -morphology close disk:1 $TextMask
    
    # 创建背景掩码
    & magick $TextMask -negate $BgMask
    
    # 分离背景和文字
    & magick $InputFile $BgMask -compose multiply -composite $BgOnly
    & magick $InputFile $TextMask -compose multiply -composite $TextOnly
    
    # 优化压缩
    $BgCompressed = Join-Path $TempDir "bg_compressed.jpg"
    $TextOptimized = Join-Path $TempDir "text_optimized.png"
    
    & magick $BgOnly -quality 85 $BgCompressed
    & magick $TextOnly -colors 16 $TextOptimized
    
    # 最终合成
    & magick $BgCompressed $TextOptimized -compose over -composite $OutputFile
    
    Write-Host "MRC处理完成: $OutputFile" -ForegroundColor Green
    
    # 显示文件大小对比
    $OriginalSize = (Get-Item $InputFile).Length
    $OutputSize = (Get-Item $OutputFile).Length
    $Ratio = [math]::Round(($OutputSize / $OriginalSize) * 100, 2)
    
    Write-Host "原图大小: $([math]::Round($OriginalSize/1KB, 2)) KB" -ForegroundColor Cyan
    Write-Host "输出大小: $([math]::Round($OutputSize/1KB, 2)) KB" -ForegroundColor Cyan
    Write-Host "压缩比: $Ratio%" -ForegroundColor Cyan
}
finally {
    # 清理临时文件
    Remove-Item $TempDir -Recurse -Force -ErrorAction SilentlyContinue
}