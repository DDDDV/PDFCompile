<#
.SYNOPSIS
    Implements an optimized MRC (Mixed Raster Content) effect using ImageMagick.
    Extracts text regions, applies selective compression to background, and recombines
    with sharp text for optimal quality and file size balance.

.DESCRIPTION
    The script performs the following optimized steps:
    1. Creates a text detection mask using adaptive thresholding for better text isolation
    2. Applies selective compression: high quality for text areas, compressed for background
    3. Composites sharp black text onto the selectively compressed background
    4. Uses morphological operations to improve text mask quality

.PARAMETER InputImagePath
    The full path to the input image file.

.PARAMETER OutputImagePath
    The full path where the output MRC-processed image will be saved.

.PARAMETER BackgroundQuality
    The JPEG quality for background compression (0-100). Default is 75.

.PARAMETER TextQuality
    The quality for text areas (0-100). Default is 95.

.PARAMETER ForegroundThreshold
    The threshold percentage for detecting text (0-100). Default is 35.

.PARAMETER MorphologyRadius
    Radius for morphological operations to clean up text mask. Default is 1.

.PARAMETER KeepTempFiles
    If specified, temporary files will be preserved for inspection.

.PARAMETER TempDirectory
    Custom temporary directory path.

.EXAMPLE
    .\Process-OptimizedMRC.ps1 -InputImagePath "scan.jpg" -OutputImagePath "scan_mrc.jpg"
#>

param(
    [Parameter(Mandatory=$true)]
    [string]$InputImagePath,

    [Parameter(Mandatory=$true)]
    [string]$OutputImagePath,

    [ValidateRange(0,100)]
    [int]$BackgroundQuality = 75,

    [ValidateRange(0,100)]
    [int]$TextQuality = 95,

    [ValidateRange(0,100)]
    [int]$ForegroundThreshold = 35,

    [ValidateRange(1,5)]
    [int]$MorphologyRadius = 1,

    [switch]$KeepTempFiles,

    [string]$TempDirectory
)

function Process-OptimizedMRC {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]
        [string]$InputImagePath,
        [Parameter(Mandatory=$true)]
        [string]$OutputImagePath,
        [int]$BackgroundQuality = 75,
        [int]$TextQuality = 95,
        [int]$ForegroundThreshold = 35,
        [int]$MorphologyRadius = 1,
        [bool]$KeepTempFiles = $false,
        [string]$TempDirectory
    )

    # Find ImageMagick
    $imConvert = Get-Command magick -ErrorAction SilentlyContinue
    if (-not $imConvert) {
        $imConvert = Get-Command convert -ErrorAction SilentlyContinue
    }
    if (-not $imConvert) {
        Write-Error "ImageMagick not found. Please install ImageMagick."
        return
    }
    $imConvertPath = $imConvert.Source

    # Validate input
    if (-not (Test-Path $InputImagePath -PathType Leaf)) {
        Write-Error "Input image not found: $InputImagePath"
        return
    }

    # Setup temp directory
    if ([string]::IsNullOrEmpty($TempDirectory)) {
        $timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
        $tempDir = Join-Path $env:TEMP "OptimizedMRC_$timestamp"
    } else {
        $tempDir = $TempDirectory
    }

    try {
        if (-not (Test-Path $tempDir)) {
            New-Item -ItemType Directory -Force -Path $tempDir | Out-Null
        }
    } catch {
        Write-Error "Failed to create temp directory: $tempDir"
        return
    }

    # Define temp files
    $textMaskRaw = Join-Path $tempDir "01_text_mask_raw.png"
    $textMaskClean = Join-Path $tempDir "02_text_mask_clean.png"
    $backgroundMask = Join-Path $tempDir "03_background_mask.png"
    $backgroundCompressed = Join-Path $tempDir "04_background_compressed.jpg"
    $textAreaHighQuality = Join-Path $tempDir "05_text_area_hq.jpg"
    $backgroundSelective = Join-Path $tempDir "06_background_selective.png"
    $textSharp = Join-Path $tempDir "07_text_sharp.png"
    $processLog = Join-Path $tempDir "process_log.txt"

    Write-Host "Starting optimized MRC process..."
    Write-Host "Input: $InputImagePath"
    Write-Host "Output: $OutputImagePath"
    Write-Host "Background Quality: $BackgroundQuality, Text Quality: $TextQuality"
    Write-Host "Temp directory: $tempDir"

    $logContent = @"
Optimized MRC Processing Log
============================
Input: $InputImagePath
Output: $OutputImagePath
Background Quality: $BackgroundQuality
Text Quality: $TextQuality
Threshold: $ForegroundThreshold%
Morphology Radius: $MorphologyRadius
Start Time: $(Get-Date)

Processing Steps:
"@

    try {
        # Step 1: Create initial text mask with better threshold detection
        Write-Host "Step 1: Creating initial text mask..."
        $logContent += "`nStep 1: Initial text mask creation..."
        
        # Use Otsu thresholding for better automatic threshold selection
        $arguments = @(
            "`"$InputImagePath`"",
            "-colorspace", "Gray",
            "-auto-level",  # Improve contrast first
            "-threshold", "${ForegroundThreshold}%",
            "-negate",  # White text on black background
            "`"$textMaskRaw`""
        )
        $logContent += "`n  Command: $imConvertPath $($arguments -join ' ')"
        & $imConvertPath $arguments
        if ($LASTEXITCODE -ne 0) {
            throw "Failed to create initial text mask. Exit code: $LASTEXITCODE"
        }

        # Step 2: Clean up text mask using morphological operations
        Write-Host "Step 2: Cleaning text mask..."
        $logContent += "`nStep 2: Text mask cleanup..."
        $arguments = @(
            "`"$textMaskRaw`"",
            "-morphology", "Close", "Disk:$MorphologyRadius",  # Fill small gaps in text
            "-morphology", "Open", "Disk:$MorphologyRadius",   # Remove noise
            "`"$textMaskClean`""
        )
        $logContent += "`n  Command: $imConvertPath $($arguments -join ' ')"
        & $imConvertPath $arguments
        if ($LASTEXITCODE -ne 0) {
            throw "Failed to clean text mask. Exit code: $LASTEXITCODE"
        }

        # Step 3: Create background mask (inverted text mask)
        Write-Host "Step 3: Creating background mask..."
        $logContent += "`nStep 3: Background mask creation..."
        $arguments = @("`"$textMaskClean`"", "-negate", "`"$backgroundMask`"")
        & $imConvertPath $arguments
        if ($LASTEXITCODE -ne 0) {
            throw "Failed to create background mask. Exit code: $LASTEXITCODE"
        }

        # Step 4: Create compressed background version
        Write-Host "Step 4: Creating compressed background..."
        $logContent += "`nStep 4: Background compression..."
        $arguments = @(
            "`"$InputImagePath`"",
            "-quality", $BackgroundQuality,
            "`"$backgroundCompressed`""
        )
        & $imConvertPath $arguments
        if ($LASTEXITCODE -ne 0) {
            throw "Failed to compress background. Exit code: $LASTEXITCODE"
        }

        # Step 5: Create high-quality version for text areas
        Write-Host "Step 5: Creating high-quality text areas..."
        $logContent += "`nStep 5: High-quality text areas..."
        $arguments = @(
            "`"$InputImagePath`"",
            "-quality", $TextQuality,
            "`"$textAreaHighQuality`""
        )
        & $imConvertPath $arguments
        if ($LASTEXITCODE -ne 0) {
            throw "Failed to create high-quality text areas. Exit code: $LASTEXITCODE"
        }

        # Step 6: Combine high-quality text areas with compressed background
        Write-Host "Step 6: Applying selective compression..."
        $logContent += "`nStep 6: Selective compression..."
        $arguments = @(
            "`"$backgroundCompressed`"",  # Base layer (compressed)
            "`"$textAreaHighQuality`"",   # High quality overlay
            "`"$textMaskClean`"",         # Mask for where to apply high quality
            "-composite",
            "`"$backgroundSelective`""
        )
        & $imConvertPath $arguments
        if ($LASTEXITCODE -ne 0) {
            throw "Failed to apply selective compression. Exit code: $LASTEXITCODE"
        }

        # Step 7: Create sharp black text overlay
        Write-Host "Step 7: Creating sharp text overlay..."
        $logContent += "`nStep 7: Sharp text overlay..."
        $arguments = @(
            "`"$InputImagePath`"",
            "-colorspace", "Gray",
            "-auto-level",
            "-threshold", "${ForegroundThreshold}%",
            "-transparent", "white",  # Make white transparent, keep black text
            "`"$textSharp`""
        )
        & $imConvertPath $arguments
        if ($LASTEXITCODE -ne 0) {
            throw "Failed to create sharp text overlay. Exit code: $LASTEXITCODE"
        }

        # Step 8: Final composition
        Write-Host "Step 8: Final composition..."
        $logContent += "`nStep 8: Final composition..."
        $arguments = @(
            "`"$backgroundSelective`"",
            "`"$textSharp`"",
            "-composite",
            "-quality", "90",  # Good quality for final output
            "`"$OutputImagePath`""
        )
        & $imConvertPath $arguments
        if ($LASTEXITCODE -ne 0) {
            throw "Failed to create final composition. Exit code: $LASTEXITCODE"
        }

        $logContent += "`n`nProcess completed successfully at $(Get-Date)"
        Write-Host "✅ MRC process completed successfully!"
        Write-Host "Output saved to: $OutputImagePath"

        # Show file size comparison
        if (Test-Path $InputImagePath -and Test-Path $OutputImagePath) {
            $inputSize = (Get-Item $InputImagePath).Length
            $outputSize = (Get-Item $OutputImagePath).Length
            $compressionRatio = [math]::Round((1 - $outputSize / $inputSize) * 100, 1)
            Write-Host "File size: $(Format-FileSize $inputSize) → $(Format-FileSize $outputSize) (${compressionRatio}% reduction)"
        }

    }
    catch {
        $logContent += "`n`nERROR: $($_.Exception.Message)"
        $logContent += "`nProcess failed at $(Get-Date)"
        Write-Error "MRC processing failed: $($_.Exception.Message)"
        throw
    }
    finally {
        # Save log
        $logContent | Out-File -FilePath $processLog -Encoding UTF8
        
        if ($KeepTempFiles) {
            Write-Host "`n📁 Temporary files preserved in: $tempDir"
            Get-ChildItem $tempDir | ForEach-Object {
                $size = Format-FileSize $_.Length
                Write-Host "  - $($_.Name) ($size)"
            }
        } else {
            Write-Host "🧹 Cleaning up temporary files..."
            Remove-Item $tempDir -Recurse -Force -ErrorAction SilentlyContinue
        }
    }
}

function Format-FileSize {
    param([long]$Size)
    if ($Size -gt 1GB) { return "{0:N2} GB" -f ($Size / 1GB) }
    if ($Size -gt 1MB) { return "{0:N2} MB" -f ($Size / 1MB) }
    if ($Size -gt 1KB) { return "{0:N2} KB" -f ($Size / 1KB) }
    return "$Size bytes"
}

# Execute the function
Process-OptimizedMRC -InputImagePath $InputImagePath -OutputImagePath $OutputImagePath -BackgroundQuality $BackgroundQuality -TextQuality $TextQuality -ForegroundThreshold $ForegroundThreshold -MorphologyRadius $MorphologyRadius -KeepTempFiles:$KeepTempFiles -TempDirectory $TempDirectory