# --------------------------
# Password Expiry Notification Script
# --------------------------
# Synopsis:
#     This script sends email notifications to users about their password expiry status.
# Description:
#     - Retrieves password expiry information for users from Active Directory.
#     - Sends email notifications to users with details on how to change their passwords.
#     - Includes company information, logo, contact details, and instructions in the email.
#     - Reads configuration settings and email templates from external files for easy maintenance.
#     - Custom handling for specific admin or service accounts with no mailbox.
#     - Excludes accounts with non-expiring passwords.
# Parameters:
#     - $ConfigFile: Path to the configuration file (default is "config.json").
#     - $AdminAccountsFile: Path to the admin accounts configuration file (default is "admin_accounts.json").
# Notes:
#     - Ensure the Active Directory module is available for this script to work correctly.
#     - Requires permissions to send emails using the specified SMTP server.
#     - Logs are created in the specified directory with timestamps for each run.
# Example Usage:
#     .\SendPasswordExpiryNotification.ps1 -ConfigFile ".\config.json" -AdminAccountsFile ".\admin_accounts.json"
# Author:
#     Turtlemonks
# Date:
#     08/05/24
# Configuration Instructions:
#     - Modify the configuration files `config.json` and `admin_accounts.json` to set SMTP server, email addresses, and other settings.
#     - Adjust email templates located in the `Templates` folder as needed.
#     - Ensure the LogDirectory exists and is writable.
# --------------------------

# Check for environment variables and use them if available, otherwise fall back to default values
$ScriptDirectory = Split-Path -Parent $MyInvocation.MyCommand.Path

$defaultConfigPath = Join-Path -Path $ScriptDirectory -ChildPath "config.json"
$defaultAdminAccountsPath = Join-Path -Path $ScriptDirectory -ChildPath "admin_accounts.json"

$configPath = if ($env:CONFIG_FILE_PATH) { $env:CONFIG_FILE_PATH } else { $defaultConfigPath }
$adminAccountsPath = if ($env:ADMIN_ACCOUNTS_FILE_PATH) { $env:ADMIN_ACCOUNTS_FILE_PATH } else { $defaultAdminAccountsPath }

param (
    [string]$ConfigFile = $configPath,
    [string]$AdminAccountsFile = $adminAccountsPath
)

# Define log file path
$LogDirectory = Join-Path -Path $ScriptDirectory -ChildPath "Logs"
if (-not (Test-Path -Path $LogDirectory)) {
    New-Item -ItemType Directory -Path $LogDirectory | Out-Null
}
$LogFilePath = "$LogDirectory\PWD_Notify_Email_Log-$((Get-Date).ToString('yyyy-MM-dd-HH-mm-ss')).txt"

# Define secure password file path
$SecurePasswordFilePath = Join-Path -Path $ScriptDirectory -ChildPath "securepassword.txt"

# Define template directory path
$TemplateDirectory = Join-Path -Path $ScriptDirectory -ChildPath "Templates"

# --------------------------
# Function: Get-Configuration
# Purpose: Load configuration settings from a JSON file.
# --------------------------
function Get-Configuration {
    param (
        [Parameter(Mandatory=$true)]
        [string]$ConfigFile
    )
    if (Test-Path $ConfigFile) {
        try {
            $config = Get-Content -Path $ConfigFile | ConvertFrom-Json
            return $config
        } catch {
            Write-Host "Failed to read configuration file: $_"
            exit
        }
    } else {
        Write-Host "Configuration file not found: $ConfigFile"
        exit
    }
}

# Load main configuration settings
$config = Get-Configuration -ConfigFile $ConfigFile

# Load admin accounts configuration settings
$adminAccounts = Get-Configuration -ConfigFile $AdminAccountsFile

# --------------------------
# Global Configuration
# --------------------------
$SMTPServer = $config.SMTPServer
$FromAddress = $config.FromAddress
$ReplyToAddress = $config.ReplyToAddress
$SubjectPrefix = $config.SubjectPrefix
$DaysBeforeExpiry = $config.DaysBeforeExpiry
$FinalWarningDays = $config.FinalWarningDays
$CompanyLogoURL = $config.CompanyLogoURL
$LogDirectory = $config.LogDirectory
$LogRetentionDays = $config.LogRetentionDays
$EmailTemplates = @{
    GeneralWarning = Join-Path -Path $TemplateDirectory -ChildPath $config.EmailTemplates.GeneralWarning
    FinalWarning = Join-Path -Path $TemplateDirectory -ChildPath $config.EmailTemplates.FinalWarning
    Alert = Join-Path -Path $TemplateDirectory -ChildPath $config.EmailTemplates.Alert
}
$BatchSize = $config.BatchSize -or 100  # Number of users to process in each batch

# Load SMTP password from secure file
if (Test-Path $SecurePasswordFilePath) {
    $SMTPPassword = Get-Content $SecurePasswordFilePath | ConvertTo-SecureString
} else {
    Write-Host "SMTP password not found."
    exit
}

# --------------------------
# Function: InitializeLogging
# Purpose: Ensure required modules are loaded and log paths are accessible.
# --------------------------
function InitializeLogging {
    try {
        if (-not (Get-Module -Name ActiveDirectory -ListAvailable)) {
            Import-Module ActiveDirectory -ErrorAction Stop
        }
        WriteLogEntry "ActiveDirectory module loaded successfully."
    } catch {
        WriteLogEntry "ActiveDirectory module could not be loaded: $_"
        exit
    }
}

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
# Function: CleanupOldLogs
# Purpose: Delete log files older than the specified retention period.
# --------------------------
function CleanupOldLogs {
    param (
        [Parameter(Mandatory=$true)]
        [string]$LogDirectory,
        [Parameter(Mandatory=$true)]
        [int]$RetentionDays
    )
    $cutoffDate = (Get-Date).AddDays(-$RetentionDays)
    Get-ChildItem -Path $LogDirectory -Filter "*.txt" | Where-Object { $_.CreationTime -lt $cutoffDate } | ForEach-Object {
        Remove-Item -Path $_.FullName -Force
        Write-Host "Deleted old log file: $($_.Name)"
    }
}

# --------------------------
# Function: Get-ADUserPasswordExpiry
# Purpose: Retrieve the AD user's password expiry information.
# --------------------------
function Get-ADUserPasswordExpiry {
    param (
        [Parameter(Mandatory=$true)]
        [string]$Username
    )
    try {
        # Retrieve only the necessary properties
        $user = Get-ADUser -Identity $Username -Property "msDS-UserPasswordExpiryTimeComputed", "DisplayName", "EmailAddress", "PasswordNeverExpires"

        if ($null -eq $user) {
            WriteLogEntry "User $Username not found in Active Directory."
            return $null
        }

        if ($user.PasswordNeverExpires) {
            WriteLogEntry "Password for user $Username is set to never expire, skipping."
            return $null
        }

        $expiryTime = $user."msDS-UserPasswordExpiryTimeComputed"
        $expiryDate = [datetime]::FromFileTime($expiryTime)
        $daysLeft = [math]::Ceiling(($expiryDate - (Get-Date)).TotalDays)
        return @{
            "DaysLeft" = $daysLeft
            "ExpiryDate" = $expiryDate
            "DisplayName" = $user.DisplayName
            "EmailAddress" = $user.EmailAddress
        }
    } catch {
        WriteLogEntry "Error retrieving password expiry information for user: $Username - $_"
        return $null
    }
}

# --------------------------
# Function: Send-EmailNotification
# Purpose: Construct and send an email notification to the user.
# --------------------------
function Send-EmailNotification {
    param (
        [Parameter(Mandatory=$true)]
        [string]$ToAddress,
        [string]$DaysLeft,
        [string]$ExpiryDate,
        [string]$DisplayName,
        [string]$TemplatePath
    )
    $subject = "$SubjectPrefix - Password Expiry in $DaysLeft Day(s)"
    $templateData = @{
        "CompanyLogoURL" = $CompanyLogoURL
        "DisplayName" = $DisplayName
        "DaysLeft" = $DaysLeft
        "ExpiryDate" = $ExpiryDate
        "PasswordValidityPeriod" = $PasswordValidityPeriod
        "ReplyToAddress" = $ReplyToAddress
    }
    $body = Get-Template -TemplatePath $TemplatePath -TemplateData $templateData

    $mailMessageParams = @{
        To = $ToAddress
        From = $FromAddress
        Subject = $subject
        Body = $body
        SmtpServer = $SMTPServer
        BodyAsHtml = $true
        Priority = 'High'
        ReplyTo = $ReplyToAddress
        Credential = New-Object -TypeName System.Management.Automation.PSCredential -ArgumentList $FromAddress, $SMTPPassword
    }

    try {
        Send-MailMessage @mailMessageParams
        WriteLogEntry "High priority email sent to $ToAddress for password expiry notification."
    } catch {
        WriteLogEntry "Failed to send email to ${ToAddress}: $_"
    }
}

# --------------------------
# Main Script Logic
# Purpose:
#     - Retrieve all Active Directory users.
#     - Check each user's password expiry status.
#     - Send appropriate email notifications based on days left until password expiry.
#     - Custom handling for specific admin or service accounts with no mailbox.
#     - Exclude accounts with non-expiring passwords.
#     - Clean up old log files based on retention period.
# Steps:
#     1. Initialize logging and ensure required modules are loaded.
#     2. Retrieve all users from Active Directory.
#     3. For each user, calculate days left until password expiry.
#     4. Determine which notification to send based on the days left.
#     5. Clean up old log files.
# --------------------------

try {
    InitializeLogging
    WriteLogEntry "Starting password expiry notification process"

    # Retrieve all Active Directory users and calculate the total number of batches
    $allUsers = Get-ADUser -Filter * -Property "msDS-UserPasswordExpiryTimeComputed", "EmailAddress"
    $batches = [math]::Ceiling($allUsers.Count / $BatchSize)

    # Process users in batches
    for ($i = 0; $i -lt $batches; $i++) {
        $batch = $allUsers | Select-Object -Skip ($i * $BatchSize) -First $BatchSize

        foreach ($user in $batch) {
            try {
                $expiryInfo = Get-ADUserPasswordExpiry -Username $user.SamAccountName
                if ($null -ne $expiryInfo) {
                    $daysLeft = $expiryInfo.DaysLeft
                    $expiryDate = $expiryInfo.ExpiryDate
                    $displayName = $expiryInfo.DisplayName
                    $emailAddress = $expiryInfo.EmailAddress

                    if (-not $emailAddress) {
                        WriteLogEntry "No email address found for user: $($user.SamAccountName), skipping."
                        continue
                    }

                    if ($adminAccounts.AdminAccounts.ContainsKey($user.SamAccountName)) {
                        $emailAddress = $adminAccounts.AdminAccounts[$user.SamAccountName]
                    }

                    switch ($daysLeft) {
                        { $_ -le $DaysBeforeExpiry -and $_ -gt $FinalWarningDays } {
                            Send-EmailNotification -ToAddress $emailAddress -DaysLeft $daysLeft -ExpiryDate $expiryDate -DisplayName $displayName -TemplatePath $EmailTemplates.GeneralWarning
                        }
                        { $_ -le $FinalWarningDays -and $_ -gt 0 } {
                            Send-EmailNotification -ToAddress $emailAddress -DaysLeft $daysLeft -ExpiryDate $expiryDate -DisplayName $displayName -TemplatePath $EmailTemplates.FinalWarning
                        }
                        { $_ -le 0 } {
                            Send-EmailNotification -ToAddress $emailAddress -DaysLeft "0 (Expired)" -ExpiryDate $expiryDate -DisplayName $displayName -TemplatePath $EmailTemplates.Alert
                        }
                    }
                }
            } catch {
                WriteLogEntry "Error processing user $($user.SamAccountName): $_"
            }
        }
    }

    # Log completion of the password expiry notification process
    WriteLogEntry "Password expiry notification process completed"

    # Clean up old log files based on the retention period
    CleanupOldLogs -LogDirectory $LogDirectory -RetentionDays $LogRetentionDays
} catch {
    WriteLogEntry "Unhandled error: $_"
}
