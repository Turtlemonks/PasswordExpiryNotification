Password Expiry Notification System Documentation
Overview

This documentation provides details on the configuration and usage of the Password Expiry Notification System. The system comprises several scripts and configuration files to send email notifications to users about their password expiry status.
**Configuration Files**

####config.json

This file contains the main configuration settings for the script.
json{
    "SMTPServer": "smtp.example.com",
    "FromAddress": "no-reply@example.com",
    "ReplyToAddress": "support@example.com",
    "SubjectPrefix": "[Password Expiry Notification]",
    "DaysBeforeExpiry": 14,
    "FinalWarningDays": 7,
    "CompanyLogoURL": "https://example.com/logo.png",
    "LogDirectory": "C:\\Logs\\PasswordExpiry",
    "LogRetentionDays": 30,
    "EmailTemplates": {
        "GeneralWarning": "GeneralWarning.html",
        "FinalWarning": "FinalWarning.html",
        "Alert": "Alert.html"
    },
    "BatchSize": 100
}
*SMTPServer: The SMTP server used to send emails.

    -Used in Send-EmailNotification function to set the SmtpServer parameter.

*FromAddress: The email address used as the sender.

    -Used in Send-EmailNotification function to set the From parameter.

*ReplyToAddress: The email address for replies.

    -Used in Send-EmailNotification function to set the ReplyTo parameter.

*SubjectPrefix: The prefix for the email subject.

    -Used in Send-EmailNotification function to construct the Subject.

*DaysBeforeExpiry: Number of days before expiry to send the general warning.

    -Used in the main script logic to determine which email template to use.

*FinalWarningDays: Number of days before expiry to send the final warning.

    -Used in the main script logic to determine which email template to use.

*CompanyLogoURL: URL of the company logo to include in emails.

    -Used in Get-Template function to replace the logo URL in email templates.

*LogDirectory: Directory where logs are stored.

    -Used to define $LogDirectory and create log files.

*LogRetentionDays: Number of days to retain log files.

    -Used in CleanupOldLogs function to delete old log files.

*EmailTemplates: Paths to the email templates.

    -Used to set paths for GeneralWarning, FinalWarning, and Alert templates.

*BatchSize: Number of users to process in each batch.

    -Used to set the size of user batches in the main script logic.


####admin_accounts.json

This file contains the email addresses for specific admin accounts.
json{
    "AdminAccounts": {
        "admin1": "admin1@example.com",
        "admin2": "admin2@example.com"
    }
}
*AdminAccounts: A dictionary mapping admin account usernames to their email addresses.

    -Used in the main script logic to set custom email addresses for admin accounts.


####Environment Setup Script
SetupEnvironment.ps1

This script sets up environment variables and securely stores the SMTP password.
Overview of Variable Operations

    *ScriptDirectory: The directory where the script is located.
        -Used to define paths for log files, configuration files, and templates.
    *LogDirectory: Directory where logs are stored.
        -Created if it doesn't exist.
    *LogFilePath: Path to the setup log file.
        -Used to log actions and errors.
    *SecurePasswordFilePath: Path to the file where the SMTP password is stored.
        -Used to store and retrieve the SMTP password as a secure string.
    *TemplateDirectory: Directory where email templates are stored.
        -Used to locate the email templates.
*Specific Lines
# Define script directory and log file path
$ScriptDirectory = Split-Path -Parent $MyInvocation.MyCommand.Path
$LogDirectory = Join-Path -Path $ScriptDirectory -ChildPath "Logs"
$LogFilePath = "$LogDirectory\Setup_Log-$((Get-Date).ToString('yyyy-MM-dd-HH-mm-ss')).txt"

# Define secure password file path
$SecurePasswordFilePath = Join-Path -Path $ScriptDirectory -ChildPath "securepassword.txt"

# Define template directory path
$TemplateDirectory = Join-Path -Path $ScriptDirectory -ChildPath "Templates"

# Set environment variables
Set-EnvironmentVariable -Name "CONFIG_FILE_PATH" -Value (Resolve-Path $ConfigFilePath).Path
Set-EnvironmentVariable -Name "ADMIN_ACCOUNTS_FILE_PATH" -Value (Resolve-Path $AdminAccountsFilePath).Path

# Securely store the SMTP password
$SmtpPassword | ConvertFrom-SecureString | Set-Content $SecurePasswordFilePath



####Main Script
SendPasswordExpiryNotification.ps1

This script sends email notifications to users about their password expiry status.
Overview of Variable Operations

    *ConfigFile: Path to the main configuration file.
        -Loaded to set global configuration variables.
    *AdminAccountsFile: Path to the admin accounts configuration file.
        -Loaded to set email addresses for admin accounts.
    *LogDirectory: Directory where logs are stored.
        -Created if it doesn't exist.
    *LogFilePath: Path to the log file for the script run.
        -Used to log actions and errors.
    *SecurePasswordFilePath: Path to the file where the SMTP password is stored.
        -Used to retrieve the SMTP password as a secure string.
    *TemplateDirectory: Directory where email templates are stored.
        -Used to locate the email templates.
*Specific Lines
# Define log file path
$LogDirectory = Join-Path -Path $ScriptDirectory -ChildPath "Logs"
$LogFilePath = "$LogDirectory\PWD_Notify_Email_Log-$((Get-Date).ToString('yyyy-MM-dd-HH-mm-ss')).txt"

# Define secure password file path
$SecurePasswordFilePath = Join-Path -Path $ScriptDirectory -ChildPath "securepassword.txt"

# Define template directory path
$TemplateDirectory = Join-Path -Path $ScriptDirectory -ChildPath "Templates"

# Load main configuration settings
$config = Get-Configuration -ConfigFile $ConfigFile

# Global Configuration
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
$SMTPPassword = Get-Content $SecurePasswordFilePath | ConvertTo-SecureString
