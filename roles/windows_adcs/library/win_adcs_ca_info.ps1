#!powershell

# Copyright: (c) 2026, Arun Gopinath
# GNU General Public License v3.0+ (see COPYING or https://www.gnu.org/licenses/gpl-3.0.txt)

#Requires -Module Ansible.ModuleUtils.Legacy

$ErrorActionPreference = "Stop"

$params = Parse-Args -arguments $args -supports_check_mode $true

$result = @{
    changed = $false
    ca_name = ""
    subject = ""
    pem_body = ""
}

$raw_ca_name = (& certutil.exe -CAInfo name)[0]
$null = $raw_ca_name -match 'CA Name: (.*)'
$ca_name = $matches[1]

$certificate = Get-ChildItem Cert:\LocalMachine\Root |
    Where-Object { $_.Subject.StartsWith("CN=$ca_name") } |
    Select-Object -First 1

if (-not $certificate) {
    Fail-Json -obj $result -message "Could not find CA certificate in LocalMachine\Root for CN=$ca_name"
}

$cert_bytes = $certificate.Export([System.Security.Cryptography.X509Certificates.X509ContentType]::Cert)

$result.ca_name = $ca_name
$result.subject = $certificate.Subject
$result.pem_body = [System.Convert]::ToBase64String(
    $cert_bytes,
    [System.Base64FormattingOptions]::InsertLineBreaks
)

Exit-Json -obj $result
