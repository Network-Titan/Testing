# I am using this outside of Ninja to confirm it works not combining multiple elements. 
# This is the file I will be modifiying. 


$tempDir = "$env:TEMP\TEMP-DCU"
$installerPath = "$tempDir\DellCommandUpdateInstaller.exe"


$dellModelInstallers = @{
    "Latitude" = "https://dl.dell.com/FOLDER11914128M/1/Dell-Command-Update-Windows-Universal-Application_9M35M_WIN_5.4.0_A00.EXE"
    "OptiPlex" = "https://dl.dell.com/FOLDER11914128M/1/Dell-Command-Update-Windows-Universal-Application_9M35M_WIN_5.4.0_A00.EXE"
    "Precision" = "https://dl.dell.com/FOLDER11914128M/1/Dell-Command-Update-Windows-Universal-Application_9M35M_WIN_5.4.0_A00.EXE"
    "Vostro" = "https://dl.dell.com/FOLDER11914128M/1/Dell-Command-Update-Windows-Universal-Application_9M35M_WIN_5.4.0_A00.EXE"
    # Update links
}

$conflictingApps = @(
    "Dell Update",
    "Dell SupportAssist",
    "Dell SupportAssistAgent",
    "Alienware Update"
)


function Get-ComputerManufacturer {
    (Get-WmiObject -Class Win32_ComputerSystem).Manufacturer
}


function Get-DellModel {
    (Get-WmiObject -Class Win32_ComputerSystem).Model
}


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

 # Set TLS 1.2 
[Net.ServicePointManager]:: SecureProtocol = [Net.SecurityProtocolType]::Tls12   

function Install-DellCommandUpdate {
    $model = Get-DellModel
    $installerUrl = ""

    # Match partial model names like "Vostro", "Latitude", etc.
    foreach ($key in $dellModelInstallers.Keys) {
        if ($model -like "*$key*") {
            $installerUrl = $dellModelInstallers[$key]
            break
        }
    }

    if (-not $installerUrl) {
        Write-Output "No specific installer found for model $model. Exiting."
        return
    }

    # Ensure TEMP-DCU directory exists
    if (-not (Test-Path $tempDir)) {
        New-Item -Path $tempDir -ItemType Directory | Out-Null
    }

    Write-Output "Downloading Dell Command | Update installer for model $model ($key)..."

    try {
        Invoke-WebRequest -Uri $installerUrl -OutFile $installerPath -ErrorAction Stop
        Write-Output "Installer downloaded successfully."

        Write-Output "Running Dell Command | Update installer..."
        Start-Process -FilePath $installerPath -ArgumentList "/silent" -Wait -ErrorAction Stop
        Write-Output "Dell Command | Update installed successfully."
    } catch {
        Write-Output "Installation failed: $($_.Exception.Message)"
    }
}

function Update-Drivers {
    Write-Output "Checking for driver updates using Dell Command | Update..."

    try {
        $updateResults = & 'C:\Program Files\Dell\CommandUpdate\dcu-cli.exe' /applyUpdates /silent /noreboot
        Write-Output "Dell Command | Update process completed."

        # Parse the output 
        $installedDrivers = $updateResults | Select-String -Pattern "Installation Succeeded"
        $failedDrivers = $updateResults | Select-String -Pattern "Installation Failed"

        if ($installedDrivers) {
            Write-Output "Installed drivers:"
            $installedDrivers -join "`n"
        } else {
            Write-Output "No drivers were installed."
        }

        if ($failedDrivers) {
            Write-Output "Failed drivers:"
            $failedDrivers -join "`n"
        } else {
            Write-Output "No driver installation failures."
        }

    } catch {
        Write-Output "Failed to update drivers: $($_.Exception.Message)"
    }
}

# Function to report results back to Ninja RMM (pseudo code, replace with actual Ninja RMM API)
function Report-ToNinjaRMM {
    Write-Output "Reporting results to NinjaRMM..."
    # Report installed and failed drivers here
    # NinjaRMM_SetCustomField -Device $env:COMPUTERNAME -FieldName "InstalledDrivers" -FieldValue $installedDrivers
    # NinjaRMM_SetCustomField -Device $env:COMPUTERNAME -FieldName "FailedDrivers" -FieldValue $failedDrivers
}

# Main logic
if ((Get-ComputerManufacturer) -like "*Dell*") {
    Write-Output "Dell computer detected."

    # Check for conflicting software
    Write-Output "Checking for conflicting Dell software..."
    Remove-ConflictingApps

    # Check if Dell Command Update is already installed
    if (Is-DellCommandUpdateInstalled) {
        Write-Output "Dell Command | Update is already installed. Checking for updates..."
        Update-Drivers
    } else {
        Write-Output "Dell Command | Update is not installed. Attempting to install..."
        Install-DellCommandUpdate
        
            Update-Drivers
    }
} else {
    Write-Output "This is not a Dell computer. Exiting script."
}

# Clean up the installer file if it exists
if (Test-Path $installerPath) {
    Remove-Item $installerPath -Force
}

# Final report and cleanup
Report-ToNinjaRMM
Write-Output "Script completed."
