$installerUrl = "https://dl.dell.com/FOLDER11914128M/1/Dell-Command-Update-Windows-Universal-Application_9M35M_WIN_5.4.0_A00.EXE"


$installerPath = "$env:TEMP\DellCommandUpdateInstaller.exe"


$conflictingApps = @(
    "Dell Update",
    "Dell SupportAssist",
    "Dell SupportAssistAgent",
    "Alienware Update"
)

# Function to check if Dell Command Update is installed
function Is-DellCommandUpdateInstalled {
    Get-WmiObject -Query "SELECT * FROM Win32_Product WHERE Name = 'Dell Command | Update'" -ErrorAction SilentlyContinue
}


function Remove-ConflictingApps {
    foreach ($app in $conflictingApps) {
        $installedApp = Get-WmiObject -Query "SELECT * FROM Win32_Product WHERE Name LIKE '%$app%'" -ErrorAction SilentlyContinue
        if ($installedApp) {
            Write-Output "Conflicting application found: $($installedApp.Name). Uninstalling..."
            $installedApp.Uninstall() | Out-Null
            Write-Output "$($installedApp.Name) has been uninstalled."
        }
    }
}


function Install-DellCommandUpdate {
    Write-Output "Downloading and installing Dell Command | Update..."
    Invoke-WebRequest -Uri $installerUrl -OutFile $installerPath
    Start-Process -FilePath $installerPath -ArgumentList "/silent" -Wait
    Write-Output "Dell Command | Update installed."
}

# Function to check for updates and apply them using Dell Command Update
function Update-DellCommandUpdate {
    Write-Output "Checking for updates using Dell Command | Update..."
    $updateAvailable = & 'C:\Program Files (x86)\Dell\CommandUpdate\dcu-cli.exe' /check
    if ($updateAvailable) {
        Write-Output "Update available. Installing..."
        & 'C:\Program Files (x86)\Dell\CommandUpdate\dcu-cli.exe' /applyUpdates
        Write-Output "Updates applied successfully."
    } else {
        Write-Output "Dell Command | Update is already up to date."
    }
}

# Main logic
if (Is-DellCommandUpdateInstalled) {
    Write-Output "Dell Command | Update is already installed."
    Update-DellCommandUpdate
} else {
    Write-Output "Dell Command | Update is not installed. Checking for conflicting software..."
    Remove-ConflictingApps

    # After removing conflicting software, try installing Dell Command Update
    Install-DellCommandUpdate
    Update-DellCommandUpdate
}

# Clean up the installer file if it exists
if (Test-Path $installerPath) {
    Remove-Item $installerPath -Force
}

Write-Output "Script completed.
