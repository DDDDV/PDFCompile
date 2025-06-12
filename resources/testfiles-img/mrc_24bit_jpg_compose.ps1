<#
.SYNOPSIS
    Implements a simplified MRC (Mixed Raster Content) effect using ImageMagick.
    Separates a color background and a black & white foreground (text),
    compresses them, and then recombines them. Aims to keep original colors
    for the background, while making foreground text black.

.DESCRIPTION
    The script performs the following steps:
    1. Creates a compressed version of the original image to serve as the background layer.
       The original colors are preserved in this layer, subject to JPEG compression.
    2. Extracts a foreground layer by converting the image to grayscale and applying a threshold
       to isolate dark text. This text is made black, and the rest of the layer is made transparent.
    3. Composites the black text foreground layer onto the compressed background layer.
    The input image is expected to be a JPG, 600ppi, 24-bit depth, though ImageMagick
    is generally flexible with input formats. The output will be a JPG image.

.PARAMETER InputImagePath
    The full path to the input JPG image file.

.PARAMETER OutputImagePath
    The full path where the output MRC-processed JPG image will be saved.

.PARAMETER BackgroundQuality
    The JPEG quality for the background layer compression (0-100). Default is 85.
    Higher values mean better quality and larger file size.

.PARAMETER ForegroundThreshold
    The threshold percentage (0-100) for detecting foreground text.
    Pixels darker than this percentage will be considered foreground (text).
    Default is 40. You might need to adjust this value based on your image.

.EXAMPLE
    .\Process-SimplifiedMRC.ps1 -InputImagePath "C:\path\to\your\input.jpg" -OutputImagePath "C:\path\to\your\output_mrc.jpg"

.EXAMPLE
    .\Process-SimplifiedMRC.ps1 -InputImagePath ".\scan.jpg" -OutputImagePath ".\scan_mrc.jpg" -BackgroundQuality 80 -ForegroundThreshold 45
#>

param(
    [Parameter(Mandatory=$true)]
    [string]$InputImagePath,

    [Parameter(Mandatory=$true)]
    [string]$OutputImagePath,

    [ValidateRange(0,100)]
    [int]$BackgroundQuality = 85,

    [ValidateRange(0,100)]
    [int]$ForegroundThreshold = 40
)

function Process-SimplifiedMRC {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]
        [string]$InputImagePath,

        [Parameter(Mandatory=$true)]
        [string]$OutputImagePath,

        [ValidateRange(0,100)]
        [int]$BackgroundQuality = 85,

        [ValidateRange(0,100)]
        [int]$ForegroundThreshold = 40
    )

    # Try to find ImageMagick command
    $imConvert = Get-Command magick -ErrorAction SilentlyContinue
    if (-not $imConvert) {
        $imConvert = Get-Command convert -ErrorAction SilentlyContinue # For older ImageMagick v6
    }
    if (-not $imConvert) {
        Write-Error "ImageMagick command ('magick' or 'convert') not found. Please ensure ImageMagick is installed and in your PATH."
        return
    }
    $imConvertPath = $imConvert.Source

    # Check if input file exists
    if (-not (Test-Path $InputImagePath -PathType Leaf)) {
        Write-Error "Input image file not found: $InputImagePath"
        return
    }

    # Create a temporary directory for intermediate files
    $tempDir = Join-Path $env:TEMP "ImageMagickMRC_$(Get-Random)"
    try {
        New-Item -ItemType Directory -Force -Path $tempDir | Out-Null
    } catch {
        Write-Error "Failed to create temporary directory: $tempDir. Error: $($_.Exception.Message)"
        return
    }

    # Define temporary file paths
    $backgroundCompressed = Join-Path $tempDir "background_compressed.jpg"
    $foregroundBW = Join-Path $tempDir "foreground_bw.png"         # Black text on white background
    $foregroundLayerAlpha = Join-Path $tempDir "foreground_layer_alpha.png" # Black text on transparent background

    Write-Host "Starting simplified MRC process for: $InputImagePath"
    Write-Host "Using ImageMagick: $imConvertPath"
    Write-Host "Parameters: BackgroundQuality=$BackgroundQuality, ForegroundThreshold=$ForegroundThreshold"

    try {
        # Step 1: Compress the background layer
        Write-Host "Step 1: Compressing background layer (colors preserved)..."
        $arguments = @("`"$InputImagePath`"", "-quality", $BackgroundQuality, "`"$backgroundCompressed`"")
        Write-Verbose "Executing: $imConvertPath $arguments"
        & $imConvertPath $arguments
        if ($LASTEXITCODE -ne 0) {
            throw "Failed to compress background layer. LastExitCode: $LASTEXITCODE"
        }

        # Step 2: Create a black & white foreground layer (black text, white background)
        Write-Host "Step 2: Creating black & white foreground layer (text detection)..."
        $arguments = @("`"$InputImagePath`"", "-colorspace", "Gray", "-threshold", "${ForegroundThreshold}%", "`"$foregroundBW`"")
        Write-Verbose "Executing: $imConvertPath $arguments"
        & $imConvertPath $arguments
        if ($LASTEXITCODE -ne 0) {
            throw "Failed to create black & white foreground layer. LastExitCode: $LASTEXITCODE"
        }

        # Step 3: Make the white background of the foreground layer transparent
        Write-Host "Step 3: Making foreground's background transparent..."
        $arguments = @("`"$foregroundBW`"", "-transparent", "white", "`"$foregroundLayerAlpha`"")
        Write-Verbose "Executing: $imConvertPath $arguments"
        & $imConvertPath $arguments
        if ($LASTEXITCODE -ne 0) {
            throw "Failed to make foreground background transparent. LastExitCode: $LASTEXITCODE"
        }

        # Step 4: Composite the transparent foreground layer onto the compressed background
        Write-Host "Step 4: Compositing foreground onto background to create final image..."
        $arguments = @("`"$backgroundCompressed`"", "`"$foregroundLayerAlpha`"", "-composite", "`"$OutputImagePath`"")
        Write-Verbose "Executing: $imConvertPath $arguments"
        & $imConvertPath $arguments
        if ($LASTEXITCODE -ne 0) {
            throw "Failed to composite layers. LastExitCode: $LASTEXITCODE"
        }

        Write-Host "Simplified MRC process completed successfully."
        Write-Host "Output image saved to: $OutputImagePath"
    }
    catch {
        Write-Error "Error during MRC processing: $($_.Exception.Message)"
        throw
    }
    finally {
        # Cleanup temporary files and directory
        Write-Host "Cleaning up temporary files..."
        if (Test-Path $tempDir) {
            Remove-Item $tempDir -Recurse -Force -ErrorAction SilentlyContinue
            if (Test-Path $tempDir) {
                Write-Warning "Could not fully remove temporary directory: $tempDir"
            }
        }
    }

    Write-Host "Done."
}

# Call the function with the provided parameters
Process-SimplifiedMRC -InputImagePath $InputImagePath -OutputImagePath $OutputImagePath -BackgroundQuality $BackgroundQuality -ForegroundThreshold $ForegroundThreshold