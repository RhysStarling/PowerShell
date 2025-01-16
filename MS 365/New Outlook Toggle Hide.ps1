# Define the registry key path and value details
$registryPath = "HKCU:\Software\Microsoft\Office\16.0\Outlook\Options\General"
$valueName = "HideNewOutlookToggle"
$valueData = 1
$valueType = "DWord"

# Check if the registry key already exists
if (-not (Test-Path -Path $registryPath)) {
    # Create a new registry key
    New-Item -Path $registryPath -Force | Out-Null
}

# Check if the registry key exists or was created successfully
if (Test-Path -Path $registryPath) {
    # Set the value for the registry key
    Set-ItemProperty -Path $registryPath -Name $valueName -Value $valueData -Type $valueType -Force | Out-Null

    # Check if the registry value was set successfully
    $keyValue = Get-ItemProperty -Path $registryPath -Name $valueName -ErrorAction SilentlyContinue
    if ($keyValue -ne $null -and $keyValue.$valueName -eq $valueData) {
        Write-Host "Registry key '$valueName' with value '$valueData' created successfully."
    } else {
        Write-Host "Failed to set value for registry key '$valueName'."
    }
} else {
    Write-Host "Failed to create registry key '$registryPath'."
}

