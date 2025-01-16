﻿# Define the registry key path and value name
$registryPath = "HKCU:\Software\Microsoft\Office\16.0\Outlook\Options\General"
$valueName = "HideNewOutlookToggle"

# Check if the registry key exists
if (Test-Path -Path $registryPath) {
    try {
        $value = Get-ItemProperty -Path $registryPath -Name $valueName -ErrorAction Stop
        if ($value -ne $null) {
            Write-Host "Registry key '$valueName' exists."
            $exitCode = 0
        } else {
            Write-Host "Registry key '$valueName' exists but the value is not set."
            $exitCode = 1
        }
    } catch {
        Write-Host "An error occurred while trying to access the registry value."
        $exitCode = 1
    }
} else {
    Write-Host "Registry key '$registryPath' does not exist."
    $exitCode = 1
}

# Display the exit code used
Write-Host "Exit code: $exitCode"

# Exit the script with the determined exit code
$host.SetShouldExit($exitCode)


