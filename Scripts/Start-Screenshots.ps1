# Suppress all output and errors to run silently
$ErrorActionPreference = 'SilentlyContinue'
$ProgressPreference = 'SilentlyContinue'

# Load required assemblies
Add-Type -AssemblyName System.Drawing
Add-Type -AssemblyName System.Windows.Forms

# Get the Pictures folder path
$picturesFolder = [Environment]::GetFolderPath("MyPictures")
$dateTime = Get-Date -Format "yyyyMMdd_HHmmss"

# Get all screens (monitors)
$screens = [System.Windows.Forms.Screen]::AllScreens

# Loop through each screen to capture a screenshot
foreach ($screen in $screens) {
    # Get the screen's bounds (native resolution)
    $bounds = $screen.Bounds

    # Create a bitmap with the screen's native resolution
    $bmp = New-Object System.Drawing.Bitmap $bounds.Width, $bounds.Height

    # Create graphics object and capture the screen
    $graphics = [System.Drawing.Graphics]::FromImage($bmp)
    $graphics.CopyFromScreen($bounds.Location, [System.Drawing.Point]::Empty, $bounds.Size)

    # Save the screenshot to the Pictures folder with a timestamp and screen index
    $screenIndex = $screens.IndexOf($screen)
    $filePath = Join-Path $picturesFolder "Screenshot_$dateTime`_Screen$screenIndex.png"
    $bmp.Save($filePath, [System.Drawing.Imaging.ImageFormat]::Png)

    # Clean up resources
    $graphics.Dispose()
    $bmp.Dispose()
}