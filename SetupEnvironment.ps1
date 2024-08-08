# --------------------------
# Environment Setup Script
# --------------------------
# Synopsis:
#     This script sets up environment variables and securely stores the SMTP password.
# Description:
#     - Checks the current script directory and subfolders for configuration files and templates.
#     - Prompts the user for configuration file paths and SMTP password if not found.
#     - Sets environment variables for configuration file paths.
#     - Securely stores the SMTP password as a secure string.
#     - Logs all actions and errors.
# Parameters:
#     -Reconfigure: Switch to force reconfiguration of existing settings.
# Notes:
#     - Run this script once to initialize the environment.
# Example Usage:
#     .\SetupEnvironment.ps1 -Reconfigure
# Author:
#     Eric Givans
# Date:
#     08/05/24
# --------------------------

param (
    [switch]$Reconfigure
)

# Define script directory and log file path
$ScriptDirectory = Split-Path -Parent $MyInvocation.MyCommand.Path
$LogDirectory = Join-Path -Path $ScriptDirectory -ChildPath "Logs"
if (-not (Test-Path -Path $LogDirectory)) {
    New-Item -ItemType Directory -Path $LogDirectory | Out-Null
}
$LogFilePath = "$LogDirectory\Setup_Log-$((Get-Date).ToString('yyyy-MM-dd-HH-mm-ss')).txt"

# Define secure password file path
$SecurePasswordFilePath = Join-Path -Path $ScriptDirectory -ChildPath "securepassword.txt"

# Define template directory path
$TemplateDirectory = Join-Path -Path $ScriptDirectory -ChildPath "Templates"

# --------------------------
# Function: WriteLogEntry
# Purpose: Log information and errors to a specified log file.
# --------------------------
function WriteLogEntry {
    param (
        [Parameter(Mandatory=$true)]
        [string]$Message
    )
    $Timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $LogEntry = "$Timestamp - $Message`r`n"

    try {
        Add-Content -Path $LogFilePath -Value $LogEntry
    } catch {
        Write-Host "Failed to write to log file: $LogEntry"
    }
}

# --------------------------
# Function: Set-EnvironmentVariable
# Purpose: Set an environment variable and log the action.
# --------------------------
function Set-EnvironmentVariable {
    param (
        [Parameter(Mandatory=$true)]
        [string]$Name,
        [Parameter(Mandatory=$true)]
        [string]$Value
    )
    try {
        [System.Environment]::SetEnvironmentVariable($Name, $Value, [System.EnvironmentVariableTarget]::Machine)
        WriteLogEntry "Environment variable '$Name' set to '$Value'."
    } catch {
        WriteLogEntry "Failed to set environment variable '$Name': $_"
        exit
    }
}

# --------------------------
# Function: Test-ExistingConfiguration
# Purpose: Check if environment variables, secure password file, and templates already exist.
# --------------------------
function Test-ExistingConfiguration {
    $configExists = [System.Environment]::GetEnvironmentVariable("CONFIG_FILE_PATH", [System.EnvironmentVariableTarget]::Machine)
    $adminAccountsExists = [System.Environment]::GetEnvironmentVariable("ADMIN_ACCOUNTS_FILE_PATH", [System.EnvironmentVariableTarget]::Machine)
    $passwordExists = Test-Path -Path $SecurePasswordFilePath
    $templatesExist = Test-Path -Path $TemplateDirectory

    return ($configExists -or $adminAccountsExists -or $passwordExists -or $templatesExist)
}

# --------------------------
# Function: Find-RequiredFiles
# Purpose: Search for required files in the script directory and its subfolders.
# --------------------------
function Find-RequiredFiles {
    param (
        [Parameter(Mandatory=$true)]
        [string]$ScriptDirectory
    )
    $configFile = Get-ChildItem -Path $ScriptDirectory -Recurse -Filter "config.json" -ErrorAction SilentlyContinue | Select-Object -First 1
    $adminAccountsFile = Get-ChildItem -Path $ScriptDirectory -Recurse -Filter "admin_accounts.json" -ErrorAction SilentlyContinue | Select-Object -First 1
    $generalWarningTemplate = Get-ChildItem -Path $ScriptDirectory -Recurse -Filter "GeneralWarning.html" -ErrorAction SilentlyContinue | Select-Object -First 1
    $finalWarningTemplate = Get-ChildItem -Path $ScriptDirectory -Recurse -Filter "FinalWarning.html" -ErrorAction SilentlyContinue | Select-Object -First 1
    $alertTemplate = Get-ChildItem -Path $ScriptDirectory -Recurse -Filter "Alert.html" -ErrorAction SilentlyContinue | Select-Object -First 1
    
    return @{
        ConfigFile = $configFile
        AdminAccountsFile = $adminAccountsFile
        GeneralWarningTemplate = $generalWarningTemplate
        FinalWarningTemplate = $finalWarningTemplate
        AlertTemplate = $alertTemplate
    }
}

# --------------------------
# Main Script Logic
# --------------------------
try {
    if (-not $Reconfigure -and (Test-ExistingConfiguration)) {
        Write-Host "Configuration already exists. Use the -Reconfigure switch to update items to default values."
        WriteLogEntry "Environment setup aborted due to existing configuration."
        exit
    }

    # Find required files
    $requiredFiles = Find-RequiredFiles -ScriptDirectory $ScriptDirectory
    $ConfigFilePath = $requiredFiles.ConfigFile
    $AdminAccountsFilePath = $requiredFiles.AdminAccountsFile
    $GeneralWarningTemplatePath = $requiredFiles.GeneralWarningTemplate
    $FinalWarningTemplatePath = $requiredFiles.FinalWarningTemplate
    $AlertTemplatePath = $requiredFiles.AlertTemplate

    # Prompt user for configuration file paths if not found
    if (-not $ConfigFilePath) {
        $ConfigFilePath = Read-Host "Enter the path to the configuration file"
        if (-not $ConfigFilePath) {
            WriteLogEntry "Configuration file path not provided."
            Write-Host "Configuration file path not provided."
            exit
        }
    } else {
        $ConfigFilePath = $ConfigFilePath.FullName
    }

    if (-not $AdminAccountsFilePath) {
        $AdminAccountsFilePath = Read-Host "Enter the path to the admin accounts file"
        if (-not $AdminAccountsFilePath) {
            WriteLogEntry "Admin accounts file path not provided."
            Write-Host "Admin accounts file path not provided."
            exit
        }
    } else {
        $AdminAccountsFilePath = $AdminAccountsFilePath.FullName
    }

    # Validate input file paths
    if (-not (Test-Path -Path $ConfigFilePath)) {
        WriteLogEntry "Configuration file not found: $ConfigFilePath"
        exit
    }

    if (-not (Test-Path -Path $AdminAccountsFilePath)) {
        WriteLogEntry "Admin accounts file not found: $AdminAccountsFilePath"
        exit
    }

    # Prompt user for template file paths if not found
    if (-not $GeneralWarningTemplatePath) {
        $GeneralWarningTemplatePath = Read-Host "Enter the path to the GeneralWarning.html template"
        if (-not $GeneralWarningTemplatePath) {
            WriteLogEntry "GeneralWarning.html template path not provided."
            Write-Host "GeneralWarning.html template path not provided."
            exit
        }
    } else {
        $GeneralWarningTemplatePath = $GeneralWarningTemplatePath.FullName
    }

    if (-not $FinalWarningTemplatePath) {
        $FinalWarningTemplatePath = Read-Host "Enter the path to the FinalWarning.html template"
        if (-not $FinalWarningTemplatePath) {
            WriteLogEntry "FinalWarning.html template path not provided."
            Write-Host "FinalWarning.html template path not provided."
            exit
        }
    } else {
        $FinalWarningTemplatePath = $FinalWarningTemplatePath.FullName
    }

    if (-not $AlertTemplatePath) {
        $AlertTemplatePath = Read-Host "Enter the path to the Alert.html template"
        if (-not $AlertTemplatePath) {
            WriteLogEntry "Alert.html template path not provided."
            Write-Host "Alert.html template path not provided."
            exit
        }
    } else {
        $AlertTemplatePath = $AlertTemplatePath.FullName
    }

    # Validate template file paths
    if (-not (Test-Path -Path $GeneralWarningTemplatePath)) {
        WriteLogEntry "GeneralWarning.html template not found: $GeneralWarningTemplatePath"
        exit
    }

    if (-not (Test-Path -Path $FinalWarningTemplatePath)) {
        WriteLogEntry "FinalWarning.html template not found: $FinalWarningTemplatePath"
        exit
    }

    if (-not (Test-Path -Path $AlertTemplatePath)) {
        WriteLogEntry "Alert.html template not found: $AlertTemplatePath"
        exit
    }

    # Inform user about password input
    Write-Host "Please enter the SMTP password. The input will be hidden for security purposes." -ForegroundColor Cyan
    # Prompt user for SMTP password
    $SmtpPassword = Read-Host "Enter the SMTP password" -AsSecureString

    # Set environment variables
    Set-EnvironmentVariable -Name "CONFIG_FILE_PATH" -Value (Resolve-Path $ConfigFilePath).Path
    Set-EnvironmentVariable -Name "ADMIN_ACCOUNTS_FILE_PATH" -Value (Resolve-Path $AdminAccountsFilePath).Path

    # Securely store the SMTP password
    try {
        $SmtpPassword | ConvertFrom-SecureString | Set-Content $SecurePasswordFilePath
        WriteLogEntry "SMTP password stored securely."
    } catch {
        WriteLogEntry "Failed to store SMTP password: $_"
        exit
    }

    WriteLogEntry "Environment setup completed successfully."
    Write-Host "Environment setup completed successfully."

} catch {
    WriteLogEntry "Unhandled error: $_"
    Write-Host "Environment setup failed. Check the log file for details."
}

# Keep the host up for a few seconds to display the summary or error message
Write-Host "Press any key to exit..." -ForegroundColor Yellow
$host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown") | Out-Null
