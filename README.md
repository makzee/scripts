## 🔐 Generate Temporary AWS Credentials with MFA

This PowerShell script allows you to generate temporary AWS credentials using MFA and automatically creates a new AWS CLI profile (e.g., `myprofile-mfa`).

### 🧱 Prerequisites

- PowerShell installed  
- [AWS CLI v2](https://docs.aws.amazon.com/cli/latest/userguide/install-cliv2.html)  
- An existing long-lived AWS CLI profile (e.g., `myprofile`) with sufficient IAM permissions  
- MFA (Multi-Factor Authentication) enabled for your IAM user

---

### ⚙️ Setup

1. **Create a JSON config file** named `{profile}.json` in the same directory as the script.

   Example: `myprofile.json`
   ```json
   {
     "UserName": "your-iam-username",
     "Region": "us-east-1",
     "MfaDeviceName": "your-mfa-device-name"
   }
