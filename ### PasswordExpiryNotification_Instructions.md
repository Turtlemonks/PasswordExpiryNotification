### Main Script Documentation

#### Overview

The `SendPasswordExpiryNotification.ps1` script sends email notifications to users about their password expiry status.

#### Prerequisites

- PowerShell environment
- Active Directory module available
- Permissions to send emails using the specified SMTP server

#### Parameters

- `$ConfigFile`: Path to the configuration file (default is "config.json").
- `$AdminAccountsFile`: Path to the admin accounts configuration file (default is "admin_accounts.json").

#### Usage

```powershell
.\SendPasswordExpiryNotification.ps1

If you need to specify custom paths for the config files:
.\SendPasswordExpiryNotification.ps1 -ConfigFile ".\custom_config.json" -AdminAccountsFile ".\custom_admin_accounts.json"

####Configuration Instructions
.Modify the configuration files config.json and admin_accounts.json to set SMTP server, email addresses, and other settings.
.Adjust email templates located in the Templates folder as needed.
.Ensure the LogDirectory exists and is writable.




### Environment Setup Script Documentation

#### Overview

The `SetupEnvironment.ps1` script sets up environment variables and securely stores the SMTP password.

#### Prerequisites

- PowerShell environment
- Permissions to set machine-level environment variables

#### Parameters

- `-Reconfigure`: Switch to force reconfiguration of existing settings.

#### Usage

```powershell
.\SetupEnvironment.ps1

To force reconfiguration of existing settings:
.\SetupEnvironment.ps1 -Reconfigure

####Configuration Instructions

1.Run the script to initialize the environment.
2.If configuration files and templates are not found, the script will prompt for their paths.
3.Enter the SMTP password when prompted. The input will be hidden for security purposes.
4.The script will set environment variables and securely store the SMTP password.

####Notes

.This script should be run once to initialize the environment.
.Logs all actions and errors in the Logs directory.



### Admin Accounts Configuration File Documentation

#### Overview

The `admin_accounts.json` file contains a list of admin accounts that may not have mailboxes and their corresponding email addresses for notification purposes.

#### Structure

The `admin_accounts.json` file is a JSON object where each key is an admin account's SamAccountName, and the value is the email address to be used for notifications.

#### Example

```json
{
    "AdminAccounts": {
        "admin1": "admin1@example.com",
        "admin2": "admin2@example.com"
    }
}

####Adding an Admin Account

To add an admin account:

1.Open the admin_accounts.json file.
2.Add a new key-value pair inside the AdminAccounts object, where the key is the SamAccountName, and the value is the email address.

####Removing an Admin Account

To remove an admin account:

1.Open the admin_accounts.json file.
2.Delete the key-value pair corresponding to the admin account you want to remove.

Notes

.Ensure that the JSON structure is maintained (e.g., use commas to separate key-value pairs).
.This file should be located in the same directory as the main script or the path should be specified in the environment setup.
