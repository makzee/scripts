param (
    [string]$ProfileName
)

# Validate input
if (-not $ProfileName) {
    Write-Host "Please provide a profile name."
    exit 1
}

# Define file path for the JSON configuration file
$configFilePath = "$PSScriptRoot\$ProfileName.json"

# Check if the file exists
if (-not (Test-Path $configFilePath)) {
    Write-Host "Profile file '$ProfileName.json' not found in the current directory."
    exit 1
}

# Step 1: Load parameters from the JSON file
Write-Host "Loading parameters from '$ProfileName.json'..."
$config = Get-Content -Path $configFilePath | ConvertFrom-Json

# Validate required fields in the config
if (-not $config.UserName -or -not $config.Region -or -not $config.MfaDeviceName) {
    Write-Host "Missing required parameters in the configuration file."
    exit 1
}

$UserName = $config.UserName
$Region = $config.Region
$MfaDeviceName = $config.MfaDeviceName

# Step 2: Get MFA Device ARN based on the MfaDeviceName
Write-Host "Getting MFA device ARN for user '$UserName' using profile '$ProfileName'..."

$mfaDevices = aws iam list-mfa-devices --user-name $UserName --profile $ProfileName | ConvertFrom-Json

if ($mfaDevices.MFADevices.Count -eq 0) {
    Write-Error "No MFA devices found for user '$UserName'"
    exit 1
}

# Filter MFA device by name
$mfaArn = $mfaDevices.MFADevices | Where-Object { $_.SerialNumber -like "*$MfaDeviceName*" } | Select-Object -ExpandProperty SerialNumber

if (-not $mfaArn) {
    Write-Host "No MFA device found matching '$MfaDeviceName'."
    exit 1
}

# Step 3: Prompt for MFA Code
$mfaCode = Read-Host -Prompt "Enter the current 6-digit MFA code for $mfaArn"

# Step 4: Call sts get-session-token
Write-Host "Requesting temporary session token using MFA..."
$session = aws sts get-session-token `
    --serial-number $mfaArn `
    --token-code $mfaCode `
    --profile $ProfileName `
    --region $Region | ConvertFrom-Json

if (-not $session.Credentials) {
    Write-Error "Failed to get session token."
    exit 1
}

# Step 5: Save to ~/.aws/credentials as a new profile with '-mfa' suffix
$credPath = "$HOME\.aws\credentials"
$mfaProfileName = "$ProfileName-mfa"  # New profile name with '-mfa' suffix

# Check if the profile already exists in the credentials file
if (Test-Path $credPath) {
    $existingProfiles = Get-Content $credPath
    if ($existingProfiles -contains "[$mfaProfileName]") {
        Write-Host "Profile '$mfaProfileName' already exists. Overwriting credentials."
    }
} else {
    # Create a new file if it doesn't exist
    Write-Host "Creating new credentials file."
    New-Item -Path $credPath -ItemType File
}

# Append or overwrite the new profile in credentials
Add-Content -Path $credPath -Value "`n[$mfaProfileName]"
Add-Content -Path $credPath -Value "aws_access_key_id = $($session.Credentials.AccessKeyId)"
Add-Content -Path $credPath -Value "aws_secret_access_key = $($session.Credentials.SecretAccessKey)"
Add-Content -Path $credPath -Value "aws_session_token = $($session.Credentials.SessionToken)"

Write-Host "`n[+] Temporary credentials saved under profile '$mfaProfileName'"
Write-Host "Session expires at: $($session.Credentials.Expiration)"

# Step 6: Add the profile to the AWS config file as well
$configPath = "$HOME\.aws\config"
if (Test-Path $configPath) {
    $existingConfig = Get-Content $configPath
    if ($existingConfig -contains "[profile $mfaProfileName]") {
        Write-Host "Profile '$mfaProfileName' already exists in the config file."
    }
} else {
    # Create a new config file if it doesn't exist
    Write-Host "Creating new config file."
    New-Item -Path $configPath -ItemType File
}

# Append the new profile configuration to the config file
Add-Content -Path $configPath -Value "`n[$mfaProfileName]"
Add-Content -Path $configPath -Value "region = $Region"

Write-Host "`n[+] Profile '$mfaProfileName' added to AWS config file."

# Step 7: Set the environment variable for the current session profile
$env:AWS_PROFILE = $mfaProfileName
Write-Host "`n[>] AWS_PROFILE is now set to '$mfaProfileName'"

# Step 8: Test it
Write-Host "Testing session with 'aws sts get-caller-identity'..."
aws sts get-caller-identity --profile $mfaProfileName
