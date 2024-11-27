# Define file path (used for both input and output)
$filePath = "C:\Users\99dreada\Desktop\Users.csv"

# Import Active Directory module
Import-Module ActiveDirectory

# Function to generate a random 16-character password with higher complexity
function Generate-Password {
    # Define character sets for password generation
    $upperChars = "ABCDEFGHIJKLMNOPQRSTUVWXYZ".ToCharArray()
    $lowerChars = "abcdefghijklmnopqrstuvwxyz".ToCharArray()
    $numberChars = "0123456789".ToCharArray()
    $specialChars = "!@#$%^&*()-_=+[]{}|;:,.<>?/`~".ToCharArray()

    # Ensure at least one character from each category
    $passwordArray = @(
        ($upperChars | Get-Random),
        ($lowerChars | Get-Random),
        ($numberChars | Get-Random),
        ($specialChars | Get-Random)
    )

    # Fill the rest of the password with random characters from all categories
    $allChars = $upperChars + $lowerChars + $numberChars + $specialChars
    $passwordArray += (1..(16 - $passwordArray.Length)) | ForEach-Object { $allChars | Get-Random }

    # Shuffle the password array to ensure randomness
    $shuffledPassword = $passwordArray | Get-Random -Count $passwordArray.Length

    # Return the password as a string
    return -join $shuffledPassword
}

# Function to ensure user is part of Domain Users and remove from other groups
function Manage-UserGroups {
    param (
        [string]$Username
    )

    try {
        # Get the user's current group memberships
        $currentGroups = Get-ADUser -Identity $Username -Property MemberOf | Select-Object -ExpandProperty MemberOf

        # Resolve group names from distinguished names
        $currentGroupNames = $currentGroups | ForEach-Object { 
            (Get-ADGroup -Identity $_).Name
        }

        # Check if the user is in the "Domain Users" group
        if (-not ($currentGroupNames -contains "Domain Users")) {
            Add-ADGroupMember -Identity "Domain Users" -Members $Username
        }

        # Remove the user from all groups except "Domain Users"
        foreach ($group in $currentGroupNames) {
            if ($group -ne "Domain Users") {
                Remove-ADGroupMember -Identity $group -Members $Username -Confirm:$false
            }
        }

    } catch {
        Write-Host ("Error managing group memberships for user {0}: {1}" -f $Username, $_.Exception.Message) -ForegroundColor Red
    }
}

# Function to process the CSV and output passwords, update AD user password
function Process-Users {
    param (
        [Parameter(Mandatory=$true)]
        [string]$CsvPath  # Path to the CSV file (used for both input and output)
    )

    # Read input CSV
    if (-Not (Test-Path $CsvPath)) {
        Write-Host "CSV file not found at $CsvPath" -ForegroundColor Red
        return
    }

    $users = Import-Csv -Path $CsvPath

    # Process each user
    $updatedUsers = @()

    foreach ($user in $users) {
        $username = $user.Username
        $firstName = $user.FirstName
        $lastName = $user.LastName

        try {
            # Generate a random 16-character password with at least one uppercase letter, number, and special character
            $newPassword = Generate-Password

            # Output the generated password to the user's record
            $user.Password = $newPassword

            # Update the user's password in Active Directory
            Set-ADAccountPassword -Identity $username -NewPassword (ConvertTo-SecureString -AsPlainText $newPassword -Force) -Reset

            # Confirm password change
            Write-Host ("Password for user {0} successfully changed." -f $username) -ForegroundColor Green

            # Manage group memberships
            Manage-UserGroups -Username $username

        } catch {
            $user.Password = "Error: " + $_.Exception.Message  # Update the password field with error
            Write-Host ("Error processing user {0}: {1}" -f $username, $_.Exception.Message) -ForegroundColor Red
        }

        # Add updated user info to the list
        $updatedUsers += $user
    }

    # Export updated users to the same CSV file
    $updatedUsers | Export-Csv -Path $CsvPath -NoTypeInformation -Force
    Write-Host "Password generation and update process completed. Updated CSV saved to $CsvPath" -ForegroundColor Cyan
}

# Execute the function with the specified file path
Process-Users -CsvPath $filePath
