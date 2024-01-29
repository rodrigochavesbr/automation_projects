#!powershell
## PowerShell Option
#################
#Requires -Version 3
Set-StrictMode -Version 2
$ErrorActionPreference = "Continue"

## @file check_usersinfo.ps1
## @author Rodrigo Chaves <rschaves@kyndryl.com>
## @copyright (c) Kyndryl Inc. 2022. All Rights Reserved.
## @version if applicable, provide information
## @brief Check never expires user password
## @par URL
## https://github.kyndryl.net/la-innovation/next_scripts @n
##
## @par Purpose
##
## The purpose of this program is to run a Check never expires user password.
##
## @note
## This library is implemented for powershell version 3+. Prior versions of
## powershell will probably fail at interpreting that code.
## @note
## The powershell is supposed to run with strict mode, which mean that prohibits
## references to uninitialized variables, prohibits references to non-existent
## properties of an object, prohibits function calls that use the syntax for
## calling methods and also prohibits a variable without a name (${}) causing
## failure of the running script

################################################################################
# Licensed Materials - Property of Kyndryl
# (c) Kyndryl Inc. 2022. All Rights Reserved.
################################################################################
#
#             __/\\\\\_____/\\\__/\\\_______/\\\__/\\\\\\\\\\\\\\\_
#              _\/\\\\\\___\/\\\_\///\\\___/\\\/__\///////\\\/////__
#               _\/\\\/\\\__\/\\\___\///\\\\\\/__________\/\\\_______
#                _\/\\\//\\\_\/\\\_____\//\\\\____________\/\\\_______
#                 _\/\\\\//\\\\/\\\______\/\\\\____________\/\\\_______
#                  _\/\\\_\//\\\/\\\______/\\\\\\___________\/\\\_______
#                   _\/\\\__\//\\\\\\____/\\\////\\\_________\/\\\_______
#                    _\/\\\___\//\\\\\__/\\\/___\///\\\_______\/\\\_______
#                     _\///_____\/////__\///_______\///________\///________
#
################################################################################
#    Filename: check_user_info.ps1
# Description: The purpose of this program is to run a Check never expires user password
#   Reference:
#       Input:
#      Output: Json
#      Usage: From Ansible:
#               script: scripts/windows/check_usersinfo.ps1
#                args:
#                   executable: 'PowerShell -NoProfile -NonInteractive'
#             From Powershell Prompt
#               ./check_usersinfo.ps1
#     Pre-req: Powershell 3
#      Author: Rodrigo Chaves <rschaves@kyndryl.com>
#    Releases:
##############################################################################
#
## Global variables
#################

## @var String SERVER
## @brief Contains the server name used to connect on the instance
[String]$Script:Server = "$env:COMPUTERNAME"

## @var String SERVER
## @brief Contains the user information and domain name
Add-Type -AssemblyName System.DirectoryServices.AccountManagement
$Script:UserPrincipal = [System.DirectoryServices.AccountManagement.UserPrincipal]::Current

## @fn Get-ADusers_information()
## @brief This function check AD never expires password user
function Get-ADusers_information {
  $privilegedgroups = "Account Operators", "Administrators", "All Application Packages", "Allowed RODC Password Replication", "Backup Operators",
  "Certificate Service DCOM Access", "Cert Publishers", "Cryptographic Operators", "Distributed COM Users", "DnsAdmins",
  "DHCP Administrators", "Domain Admins", "Enterprise Admins", "Enterprise Key Admins", "Event Log Readers", "Group Policy Creator Owners",
  "Hyper-V Administrators", "IIS_IUSRS", "Network Configuration Operators", "Performance Log Users", "Performance Monitor Users",
  "Pre-Windows 2000 Compatible Access", "Incoming Forest Trust Builders", "Key Admins", "Print Operators", "Protected Users",
  "Remote Desktop Users", "Remote Management Users", "Schema Admins", "Server Operators", "Storage Replica Administrators",
  "Windows Authorization Access group", "Power Users", "Group Policy Owners", "Enterprise Operators", "Certificate Service DCOM Access",
  "Administradores", "Admins. do domínio", "KYN_ADM", "ADMIN_IBM", "DBA", "Oracle", "AdmIntel", "*admin*", "*ADMIN_IBM*", "*ADMIN_KYN*"

  $userreport = get-aduser -ldapfilter "(objectclass=user)" -properties SamAccountName, Name, UserPrincipalName, displayname, Description, CanonicalName, MemberOf, PrimaryGroup,
  Department, manager, distinguishedname, Enabled, admincount, LockedOut, badpwdcount, accountlockouttime, LastBadPasswordAttempt, cannotchangepassword, AccountExpirationDate,
  LastLogonDate, logonCount, PasswordExpired, PasswordLastSet, PasswordNeverExpires, PasswordNotRequired, ScriptPath, ProfilePath, HomeDirectory, Homedrive,
  Protectedfromaccidentaldeletion, emailaddress, WhenChanged, WhenCreated, AllowReversiblePasswordEncryption,
  TrustedForDelegation, TrustedToAuthForDelegation, UseDESKeyOnly |
  Select-Object SamAccountName, Name, UserPrincipalName, displayname, Description,
  @{Name = 'MemberOf'; expression = { [string]::join(";", (($_.memberof -replace "\,.*") -replace "CN=", "" )) } },
  @{Name = 'privilegedgroup'; expression = {
      $memberOf = $_.MemberOf | ForEach-Object { ($_ -split ',')[0] -replace '^CN=' }
      $privileged = $memberOf | Where-Object { $group = $_; $privilegedgroups | Where-Object { $group -like $_ } }
      if ($privileged) { $privileged -join ";" } else { $null }
    }
  },
  @{Name = 'PrimaryGroup'; expression = { [string]::join(";", (($_.PrimaryGroup -replace "\,.*") -replace "CN=", "" )) } },
  Department, manager, distinguishedname, CanonicalName,
  @{Name = 'Domain'; expression = { ($_.canonicalname -split '/')[0] } },
  Enabled, admincount, LockedOut, badpwdcount, accountlockouttime, LastBadPasswordAttempt, cannotchangepassword, AccountExpirationDate,
  LastLogonDate, logonCount, PasswordExpired, PasswordLastSet, PasswordNeverExpires, PasswordNotRequired, ScriptPath, ProfilePath, HomeDirectory, Homedrive,
  Protectedfromaccidentaldeletion, emailaddress, WhenChanged, WhenCreated, AllowReversiblePasswordEncryption,
  TrustedForDelegation, TrustedToAuthForDelegation, UseDESKeyOnly
  $userreport
}

## @fn Get-LocalUsersInformation()
## @brief This function check local users information
function Get-LocalUsersInformation() {
  $privilegedgroups = "Account Operators", "Administrators", "All Application Packages", "Backup Operators",
  "Certificate Service DCOM Access", "Cert Publishers", "Cryptographic Operators", "Distributed COM Users",
  "Event Log Readers", "Group Policy Creator Owners", "Hyper-V Administrators", "IIS_IUSRS", "Network Configuration Operators",
  "Performance Log Users", "Performance Monitor Users", "Print Operators", "Protected Users", "Remote Desktop Users",
  "Remote Management Users", "Server Operators", "Power Users", "Group Policy Owners", "Certificate Service DCOM Access",
  "Administradores", "Admins. do domínio", "KYN_ADM", "ADMIN_IBM", "DBA", "Oracle", "AdmIntel", "Administrator", "Administrador", "*Admin", "*ADMIN_IBM", "*ADMIN_Kyndryl"
  Get-LocalUser -Name * | Where-Object -Property Enabled -eq $true |
  ForEach-Object {
    $user = $_
    $userGroups = (Get-LocalGroup | Where-Object { $user.SID -in ($_ | Get-LocalGroupMember | Select-Object -ExpandProperty "SID") } | Select-Object -ExpandProperty "Name")
    $privilegedUserGroups = $userGroups | Where-Object { $privilegedgroups -contains $_ -or $_ -like "*Admin*" }
    if ($privilegedUserGroups) {
      [PSCustomObject]@{
        "Hostname"                 = $env:COMPUTERNAME
        "User"                     = $user.Name
        "Enabled"                  = $user.Enabled
        "Password Changeable Date" = $user.PasswordChangeableDate
        "Password Expires"         = $user.PasswordExpires
        "User May Change Password" = $user.UserMayChangePassword
        "Password Last Set"        = $user.PasswordLastSet
        "Last Logon"               = $user.LastLogon
        "Groups"                   = ($userGroups -join ";")
        "Privileged Groups"        = ($privilegedUserGroups -join ";")
      }
    }
  }
}

## @fn main()
## @brief This is main function
function main() {
  $osInfo = Get-CimInstance -ClassName Win32_OperatingSystem
  If ($osInfo.ProductType -eq 2) {
    $domain = Get-ADDomain -Current LoggedOnUser
    $domain_name = $domain.Name
    Get-ADusers_information | export-csv $env:HOMEDRIVE\IBM\results\"$domain_name"_"$env:COMPUTERNAME"_usersinformation.csv -NoTypeInformation -Encoding UTF8
  }
  else {
    Get-LocalUsersInformation | export-csv $env:HOMEDRIVE\IBM\results\"$env:COMPUTERNAME"_usersinformation.csv -NoTypeInformation -Encoding UTF8
  }
}
main

# SIG # Begin signature block
# MIIb3QYJKoZIhvcNAQcCoIIbzjCCG8oCAQExCzAJBgUrDgMCGgUAMGkGCisGAQQB
# gjcCAQSgWzBZMDQGCisGAQQBgjcCAR4wJgIDAQAABBAfzDtgWUsITrck0sYpfvNR
# AgEAAgEAAgEAAgEAAgEAMCEwCQYFKw4DAhoFAAQUuRiAIf/rr1AEy1eGr+mPihIz
# BTmgghY9MIIDMjCCAhqgAwIBAgIQa3t5dk2Oz5pPEVWyWBMWPzANBgkqhkiG9w0B
# AQsFADAxMS8wLQYDVQQDDCZLeW5kcnlsIFNNSSAtIENvZGUgU2lnbmluZyBDZXJ0
# aWZpY2F0ZTAeFw0yMzAxMDIxOTEzMjhaFw0yNDAxMDIxOTMzMjhaMDExLzAtBgNV
# BAMMJkt5bmRyeWwgU01JIC0gQ29kZSBTaWduaW5nIENlcnRpZmljYXRlMIIBIjAN
# BgkqhkiG9w0BAQEFAAOCAQ8AMIIBCgKCAQEAo30zDTAdnZpvwmPUn+VM5yI5MPk1
# mjz8GT/qm9HLE8LmY3l4ZZ4lljTxAZo68H9L6pybnzNmWhhg5d3225GRN0H0OdtR
# cPNyLetVZiFJvNMfCckclJRWg7VRd1TMScUgKU9FxIbCRWF9ziQyaZlwn1WTkg3P
# FUe2I1xtGE929Mr4S0DCZGs/3xbu0x0MJKfnFdUXwTBBLkatIs3NTug/LnTnP3iy
# nsxamgvBFo78ixCnHueVMQLweXZjjXakpJ3JsRSq4Q7c/3S9LLWJQentRvxrppI9
# qutngbCF2HMx1E3QgZSN0qU0UCR7qfYxesOz76/2JP/LYm0qwZYD4zKFvQIDAQAB
# o0YwRDAOBgNVHQ8BAf8EBAMCB4AwEwYDVR0lBAwwCgYIKwYBBQUHAwMwHQYDVR0O
# BBYEFH4uauY+u3rl7dZN33fN3Vwik8o3MA0GCSqGSIb3DQEBCwUAA4IBAQAqEGZ3
# Kv2L51yykaU+wyPu02w+KHHcsKjAQEQ6R6hOO1knqXvxpYAojDJ0BZjTqBqMCTqa
# FTJfReOnzELTWvRdQTFiiOJQUeBBSQ/Rty0cxl9U0cFq8jWe7pDTYKfAcAM4w+k5
# CR7VANP7Hhzj8r35oPIZNkYC0Pzyxykby6h0mm9gZxuZx7U0W0IRRseEvvf7m35S
# uv30OquU2WPInhTOGT+sZ0r3W7LxOFK8kj+wGMlVmTb73OF8Pr4RIyIe7nDcutwh
# SkQEkiTSvBSpmX7EVNrsAsunOsv/Lvtgrek+1Yd/JqZwsXHn9N/KmfaBFauZZSy1
# RhskEhadIM7VcXEFMIIFjTCCBHWgAwIBAgIQDpsYjvnQLefv21DiCEAYWjANBgkq
# hkiG9w0BAQwFADBlMQswCQYDVQQGEwJVUzEVMBMGA1UEChMMRGlnaUNlcnQgSW5j
# MRkwFwYDVQQLExB3d3cuZGlnaWNlcnQuY29tMSQwIgYDVQQDExtEaWdpQ2VydCBB
# c3N1cmVkIElEIFJvb3QgQ0EwHhcNMjIwODAxMDAwMDAwWhcNMzExMTA5MjM1OTU5
# WjBiMQswCQYDVQQGEwJVUzEVMBMGA1UEChMMRGlnaUNlcnQgSW5jMRkwFwYDVQQL
# ExB3d3cuZGlnaWNlcnQuY29tMSEwHwYDVQQDExhEaWdpQ2VydCBUcnVzdGVkIFJv
# b3QgRzQwggIiMA0GCSqGSIb3DQEBAQUAA4ICDwAwggIKAoICAQC/5pBzaN675F1K
# PDAiMGkz7MKnJS7JIT3yithZwuEppz1Yq3aaza57G4QNxDAf8xukOBbrVsaXbR2r
# snnyyhHS5F/WBTxSD1Ifxp4VpX6+n6lXFllVcq9ok3DCsrp1mWpzMpTREEQQLt+C
# 8weE5nQ7bXHiLQwb7iDVySAdYyktzuxeTsiT+CFhmzTrBcZe7FsavOvJz82sNEBf
# sXpm7nfISKhmV1efVFiODCu3T6cw2Vbuyntd463JT17lNecxy9qTXtyOj4DatpGY
# QJB5w3jHtrHEtWoYOAMQjdjUN6QuBX2I9YI+EJFwq1WCQTLX2wRzKm6RAXwhTNS8
# rhsDdV14Ztk6MUSaM0C/CNdaSaTC5qmgZ92kJ7yhTzm1EVgX9yRcRo9k98FpiHaY
# dj1ZXUJ2h4mXaXpI8OCiEhtmmnTK3kse5w5jrubU75KSOp493ADkRSWJtppEGSt+
# wJS00mFt6zPZxd9LBADMfRyVw4/3IbKyEbe7f/LVjHAsQWCqsWMYRJUadmJ+9oCw
# ++hkpjPRiQfhvbfmQ6QYuKZ3AeEPlAwhHbJUKSWJbOUOUlFHdL4mrLZBdd56rF+N
# P8m800ERElvlEFDrMcXKchYiCd98THU/Y+whX8QgUWtvsauGi0/C1kVfnSD8oR7F
# wI+isX4KJpn15GkvmB0t9dmpsh3lGwIDAQABo4IBOjCCATYwDwYDVR0TAQH/BAUw
# AwEB/zAdBgNVHQ4EFgQU7NfjgtJxXWRM3y5nP+e6mK4cD08wHwYDVR0jBBgwFoAU
# Reuir/SSy4IxLVGLp6chnfNtyA8wDgYDVR0PAQH/BAQDAgGGMHkGCCsGAQUFBwEB
# BG0wazAkBggrBgEFBQcwAYYYaHR0cDovL29jc3AuZGlnaWNlcnQuY29tMEMGCCsG
# AQUFBzAChjdodHRwOi8vY2FjZXJ0cy5kaWdpY2VydC5jb20vRGlnaUNlcnRBc3N1
# cmVkSURSb290Q0EuY3J0MEUGA1UdHwQ+MDwwOqA4oDaGNGh0dHA6Ly9jcmwzLmRp
# Z2ljZXJ0LmNvbS9EaWdpQ2VydEFzc3VyZWRJRFJvb3RDQS5jcmwwEQYDVR0gBAow
# CDAGBgRVHSAAMA0GCSqGSIb3DQEBDAUAA4IBAQBwoL9DXFXnOF+go3QbPbYW1/e/
# Vwe9mqyhhyzshV6pGrsi+IcaaVQi7aSId229GhT0E0p6Ly23OO/0/4C5+KH38nLe
# JLxSA8hO0Cre+i1Wz/n096wwepqLsl7Uz9FDRJtDIeuWcqFItJnLnU+nBgMTdydE
# 1Od/6Fmo8L8vC6bp8jQ87PcDx4eo0kxAGTVGamlUsLihVo7spNU96LHc/RzY9Hda
# XFSMb++hUD38dglohJ9vytsgjTVgHAIDyyCwrFigDkBjxZgiwbJZ9VVrzyerbHbO
# byMt9H5xaiNrIv8SuFQtJ37YOtnwtoeW/VvRXKwYw02fc7cBqZ9Xql4o4rmUMIIG
# rjCCBJagAwIBAgIQBzY3tyRUfNhHrP0oZipeWzANBgkqhkiG9w0BAQsFADBiMQsw
# CQYDVQQGEwJVUzEVMBMGA1UEChMMRGlnaUNlcnQgSW5jMRkwFwYDVQQLExB3d3cu
# ZGlnaWNlcnQuY29tMSEwHwYDVQQDExhEaWdpQ2VydCBUcnVzdGVkIFJvb3QgRzQw
# HhcNMjIwMzIzMDAwMDAwWhcNMzcwMzIyMjM1OTU5WjBjMQswCQYDVQQGEwJVUzEX
# MBUGA1UEChMORGlnaUNlcnQsIEluYy4xOzA5BgNVBAMTMkRpZ2lDZXJ0IFRydXN0
# ZWQgRzQgUlNBNDA5NiBTSEEyNTYgVGltZVN0YW1waW5nIENBMIICIjANBgkqhkiG
# 9w0BAQEFAAOCAg8AMIICCgKCAgEAxoY1BkmzwT1ySVFVxyUDxPKRN6mXUaHW0oPR
# nkyibaCwzIP5WvYRoUQVQl+kiPNo+n3znIkLf50fng8zH1ATCyZzlm34V6gCff1D
# tITaEfFzsbPuK4CEiiIY3+vaPcQXf6sZKz5C3GeO6lE98NZW1OcoLevTsbV15x8G
# ZY2UKdPZ7Gnf2ZCHRgB720RBidx8ald68Dd5n12sy+iEZLRS8nZH92GDGd1ftFQL
# IWhuNyG7QKxfst5Kfc71ORJn7w6lY2zkpsUdzTYNXNXmG6jBZHRAp8ByxbpOH7G1
# WE15/tePc5OsLDnipUjW8LAxE6lXKZYnLvWHpo9OdhVVJnCYJn+gGkcgQ+NDY4B7
# dW4nJZCYOjgRs/b2nuY7W+yB3iIU2YIqx5K/oN7jPqJz+ucfWmyU8lKVEStYdEAo
# q3NDzt9KoRxrOMUp88qqlnNCaJ+2RrOdOqPVA+C/8KI8ykLcGEh/FDTP0kyr75s9
# /g64ZCr6dSgkQe1CvwWcZklSUPRR8zZJTYsg0ixXNXkrqPNFYLwjjVj33GHek/45
# wPmyMKVM1+mYSlg+0wOI/rOP015LdhJRk8mMDDtbiiKowSYI+RQQEgN9XyO7ZONj
# 4KbhPvbCdLI/Hgl27KtdRnXiYKNYCQEoAA6EVO7O6V3IXjASvUaetdN2udIOa5kM
# 0jO0zbECAwEAAaOCAV0wggFZMBIGA1UdEwEB/wQIMAYBAf8CAQAwHQYDVR0OBBYE
# FLoW2W1NhS9zKXaaL3WMaiCPnshvMB8GA1UdIwQYMBaAFOzX44LScV1kTN8uZz/n
# upiuHA9PMA4GA1UdDwEB/wQEAwIBhjATBgNVHSUEDDAKBggrBgEFBQcDCDB3Bggr
# BgEFBQcBAQRrMGkwJAYIKwYBBQUHMAGGGGh0dHA6Ly9vY3NwLmRpZ2ljZXJ0LmNv
# bTBBBggrBgEFBQcwAoY1aHR0cDovL2NhY2VydHMuZGlnaWNlcnQuY29tL0RpZ2lD
# ZXJ0VHJ1c3RlZFJvb3RHNC5jcnQwQwYDVR0fBDwwOjA4oDagNIYyaHR0cDovL2Ny
# bDMuZGlnaWNlcnQuY29tL0RpZ2lDZXJ0VHJ1c3RlZFJvb3RHNC5jcmwwIAYDVR0g
# BBkwFzAIBgZngQwBBAIwCwYJYIZIAYb9bAcBMA0GCSqGSIb3DQEBCwUAA4ICAQB9
# WY7Ak7ZvmKlEIgF+ZtbYIULhsBguEE0TzzBTzr8Y+8dQXeJLKftwig2qKWn8acHP
# HQfpPmDI2AvlXFvXbYf6hCAlNDFnzbYSlm/EUExiHQwIgqgWvalWzxVzjQEiJc6V
# aT9Hd/tydBTX/6tPiix6q4XNQ1/tYLaqT5Fmniye4Iqs5f2MvGQmh2ySvZ180HAK
# fO+ovHVPulr3qRCyXen/KFSJ8NWKcXZl2szwcqMj+sAngkSumScbqyQeJsG33irr
# 9p6xeZmBo1aGqwpFyd/EjaDnmPv7pp1yr8THwcFqcdnGE4AJxLafzYeHJLtPo0m5
# d2aR8XKc6UsCUqc3fpNTrDsdCEkPlM05et3/JWOZJyw9P2un8WbDQc1PtkCbISFA
# 0LcTJM3cHXg65J6t5TRxktcma+Q4c6umAU+9Pzt4rUyt+8SVe+0KXzM5h0F4ejjp
# nOHdI/0dKNPH+ejxmF/7K9h+8kaddSweJywm228Vex4Ziza4k9Tm8heZWcpw8De/
# mADfIBZPJ/tgZxahZrrdVcA6KYawmKAr7ZVBtzrVFZgxtGIJDwq9gdkT/r+k0fNX
# 2bwE+oLeMt8EifAAzV3C+dAjfwAL5HYCJtnwZXZCpimHCUcr5n8apIUP/JiW9lVU
# Kx+A+sDyDivl1vupL0QVSucTDh3bNzgaoSv27dZ8/DCCBsAwggSooAMCAQICEAxN
# aXJLlPo8Kko9KQeAPVowDQYJKoZIhvcNAQELBQAwYzELMAkGA1UEBhMCVVMxFzAV
# BgNVBAoTDkRpZ2lDZXJ0LCBJbmMuMTswOQYDVQQDEzJEaWdpQ2VydCBUcnVzdGVk
# IEc0IFJTQTQwOTYgU0hBMjU2IFRpbWVTdGFtcGluZyBDQTAeFw0yMjA5MjEwMDAw
# MDBaFw0zMzExMjEyMzU5NTlaMEYxCzAJBgNVBAYTAlVTMREwDwYDVQQKEwhEaWdp
# Q2VydDEkMCIGA1UEAxMbRGlnaUNlcnQgVGltZXN0YW1wIDIwMjIgLSAyMIICIjAN
# BgkqhkiG9w0BAQEFAAOCAg8AMIICCgKCAgEAz+ylJjrGqfJru43BDZrboegUhXQz
# Gias0BxVHh42bbySVQxh9J0Jdz0Vlggva2Sk/QaDFteRkjgcMQKW+3KxlzpVrzPs
# YYrppijbkGNcvYlT4DotjIdCriak5Lt4eLl6FuFWxsC6ZFO7KhbnUEi7iGkMiMbx
# vuAvfTuxylONQIMe58tySSgeTIAehVbnhe3yYbyqOgd99qtu5Wbd4lz1L+2N1E2V
# hGjjgMtqedHSEJFGKes+JvK0jM1MuWbIu6pQOA3ljJRdGVq/9XtAbm8WqJqclUeG
# hXk+DF5mjBoKJL6cqtKctvdPbnjEKD+jHA9QBje6CNk1prUe2nhYHTno+EyREJZ+
# TeHdwq2lfvgtGx/sK0YYoxn2Off1wU9xLokDEaJLu5i/+k/kezbvBkTkVf826uV8
# MefzwlLE5hZ7Wn6lJXPbwGqZIS1j5Vn1TS+QHye30qsU5Thmh1EIa/tTQznQZPpW
# z+D0CuYUbWR4u5j9lMNzIfMvwi4g14Gs0/EH1OG92V1LbjGUKYvmQaRllMBY5eUu
# KZCmt2Fk+tkgbBhRYLqmgQ8JJVPxvzvpqwcOagc5YhnJ1oV/E9mNec9ixezhe7nM
# ZxMHmsF47caIyLBuMnnHC1mDjcbu9Sx8e47LZInxscS451NeX1XSfRkpWQNO+l3q
# RXMchH7XzuLUOncCAwEAAaOCAYswggGHMA4GA1UdDwEB/wQEAwIHgDAMBgNVHRMB
# Af8EAjAAMBYGA1UdJQEB/wQMMAoGCCsGAQUFBwMIMCAGA1UdIAQZMBcwCAYGZ4EM
# AQQCMAsGCWCGSAGG/WwHATAfBgNVHSMEGDAWgBS6FtltTYUvcyl2mi91jGogj57I
# bzAdBgNVHQ4EFgQUYore0GH8jzEU7ZcLzT0qlBTfUpwwWgYDVR0fBFMwUTBPoE2g
# S4ZJaHR0cDovL2NybDMuZGlnaWNlcnQuY29tL0RpZ2lDZXJ0VHJ1c3RlZEc0UlNB
# NDA5NlNIQTI1NlRpbWVTdGFtcGluZ0NBLmNybDCBkAYIKwYBBQUHAQEEgYMwgYAw
# JAYIKwYBBQUHMAGGGGh0dHA6Ly9vY3NwLmRpZ2ljZXJ0LmNvbTBYBggrBgEFBQcw
# AoZMaHR0cDovL2NhY2VydHMuZGlnaWNlcnQuY29tL0RpZ2lDZXJ0VHJ1c3RlZEc0
# UlNBNDA5NlNIQTI1NlRpbWVTdGFtcGluZ0NBLmNydDANBgkqhkiG9w0BAQsFAAOC
# AgEAVaoqGvNG83hXNzD8deNP1oUj8fz5lTmbJeb3coqYw3fUZPwV+zbCSVEseIhj
# VQlGOQD8adTKmyn7oz/AyQCbEx2wmIncePLNfIXNU52vYuJhZqMUKkWHSphCK1D8
# G7WeCDAJ+uQt1wmJefkJ5ojOfRu4aqKbwVNgCeijuJ3XrR8cuOyYQfD2DoD75P/f
# nRCn6wC6X0qPGjpStOq/CUkVNTZZmg9U0rIbf35eCa12VIp0bcrSBWcrduv/mLIm
# lTgZiEQU5QpZomvnIj5EIdI/HMCb7XxIstiSDJFPPGaUr10CU+ue4p7k0x+GAWSc
# AMLpWnR1DT3heYi/HAGXyRkjgNc2Wl+WFrFjDMZGQDvOXTXUWT5Dmhiuw8nLw/ub
# E19qtcfg8wXDWd8nYiveQclTuf80EGf2JjKYe/5cQpSBlIKdrAqLxksVStOYkEVg
# M4DgI974A6T2RUflzrgDQkfoQTZxd639ouiXdE4u2h4djFrIHprVwvDGIqhPm73Y
# HJpRxC+a9l+nJ5e6li6FV8Bg53hWf2rvwpWaSxECyIKcyRoFfLpxtU56mWz06J7U
# WpjIn7+NuxhcQ/XQKujiYu54BNu90ftbCqhwfvCXhHjjCANdRyxjqCU4lwHSPzra
# 5eX25pvcfizM/xdMTQCi2NYBDriL7ubgclWJLCcZYfZ3AYwxggUKMIIFBgIBATBF
# MDExLzAtBgNVBAMMJkt5bmRyeWwgU01JIC0gQ29kZSBTaWduaW5nIENlcnRpZmlj
# YXRlAhBre3l2TY7Pmk8RVbJYExY/MAkGBSsOAwIaBQCgeDAYBgorBgEEAYI3AgEM
# MQowCKACgAChAoAAMBkGCSqGSIb3DQEJAzEMBgorBgEEAYI3AgEEMBwGCisGAQQB
# gjcCAQsxDjAMBgorBgEEAYI3AgEVMCMGCSqGSIb3DQEJBDEWBBSlDRrJatkeVhgI
# Z0X/pm9Lxbxf6jANBgkqhkiG9w0BAQEFAASCAQAd+3h3K1eTCM9HAHJwYl/BlD86
# lHKrYxRAmuxrMhBDXggt/4Xa8pg1ZgUqT2DSZUiQP5qnSlkM+SmyKcjfJSuTNi0/
# jKfaDeMth3RHza9tCVc44R1DgcGs2zBJCxwcpu/VXwmqYRmJSm2yM4C32+Va/ZAh
# K4cKRZ0GcVtQWzpu2/RdnwpFgJyIae+LHojEMRMrFIZF7rV666bQhmvT1+czuIFU
# rPXLuJfMYZHVaiKisOcPcwEuyXCRA7wvXqsve9CZ3lm/C5IAypUeNkT91rndnADP
# L9h1jwjR9mmL0qT9vaxC/YEEJSzOiy1oruCHzNMwCyY9j8sQxYkRii8oUxERoYID
# IDCCAxwGCSqGSIb3DQEJBjGCAw0wggMJAgEBMHcwYzELMAkGA1UEBhMCVVMxFzAV
# BgNVBAoTDkRpZ2lDZXJ0LCBJbmMuMTswOQYDVQQDEzJEaWdpQ2VydCBUcnVzdGVk
# IEc0IFJTQTQwOTYgU0hBMjU2IFRpbWVTdGFtcGluZyBDQQIQDE1pckuU+jwqSj0p
# B4A9WjANBglghkgBZQMEAgEFAKBpMBgGCSqGSIb3DQEJAzELBgkqhkiG9w0BBwEw
# HAYJKoZIhvcNAQkFMQ8XDTIzMDQwNjE1MTkzMVowLwYJKoZIhvcNAQkEMSIEIAiA
# tl2JGbNyGC4xg2j64cNGZhvsiyGdVp60Khzmg2B7MA0GCSqGSIb3DQEBAQUABIIC
# AD7vi/OXu9ACW3lL1bv91GtkOn683D+HlssR0TiI5QgMgB5GuPnRHkhTI/1NYEhk
# V1zRmLMb5Gow0Fjo/iXfqQ9FJJL6WJvxKRi/9M+bTm6T1T5MAka/PN5Ivpu9sLtj
# cq/obDNEhl4zsSfK9Hxv2xh9tXhkkaJo2rGCmRpnCKZZS+mwa1z+5pIWi8I/hor4
# A1jxNUEJOScZrMMBuw2j8WjvOomPxSCVJnOspY0H32ZYRBzzCI9otyxp9eXgJKV7
# BZuKq8QFg68SO+bnXORwF7ZkO9aFaNsgh/ekFwM4MdVOa8N8qwzdJesUWFBVARBX
# lcniyHi9CSxIcVdabdbfe/8E3bZU84SWGCyvpBNjY2rk43BNXTje57nITzzDNij6
# AhxvASj55Nr1Ly1h8QmcXTHpplPft8S6mEv7YeXQj4IMUGxZlpxoCJTaeNOOSDgw
# cQIRKR19EDrgo+Evb7Hy+6NHBm060xLYng0Kd8qHg2NGaNCM3yMf2rRBVBZKyVhD
# YHu/CT9RqwxP3Uv/1Clni0VE76CN3ngJEkrViZRf4aKofEW/QFpr8ad8NUhSfSF8
# hBiyj4KsZSn+ixMWPwA8p2WNKxNwJcx2zo/tWSKUkxkrCFr7maNWN+AhEhGJMVYC
# VJicGFmireih63OSCxYdbPyeY/TCDUfVKw8kmE6BUQE4
# SIG # End signature block
