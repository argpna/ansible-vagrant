<#
.SYNOPSIS
Update mssql availability group listener DNS parameters

.DESCRIPTION
Sets or rolls back mssql availability group listener DNS parameters.

.PARAMETER Mode
Action to run. Apply, Rollback, Show

.PARAMETER ClusterName
The WSFC cluster name

.PARAMETER ListenerName
The AG listener name used to find the listener Network Name resource.

.PARAMETER NetworkNameResource
Exact cluster Network Name resource name. Use this when ListenerName matches multiple resources.

.PARAMETER ApplyRegisterAllProvidersIP
RegisterAllProvidersIP value for Apply mode. Defaults to 1

.PARAMETER ApplyHostRecordTTL
HostRecordTTL value for Apply mode. Defaults to 60

.PARAMETER RollbackRegisterAllProvidersIP
RegisterAllProvidersIP value for Rollback mode. Defaults to 0

.PARAMETER RollbackHostRecordTTL
HostRecordTTL value for Rollback mode. Defaults to 1200

.PARAMETER NoRestart
Set parameters without stopping and starting the listener Network Name resource

.EXAMPLE
.\scripts\set-ag-listener-dns-parameters.ps1 -Mode Show -ClusterName wincl01 -ListenerName agl01

Shows the current listener DNS parameters

.EXAMPLE
.\scripts\set-ag-listener-dns-parameters.ps1 -Mode Apply -ClusterName wincl01 -ListenerName agl01

Applies multi-subnet listener settings: RegisterAllProvidersIP=1 and HostRecordTTL=60

.EXAMPLE
.\scripts\set-ag-listener-dns-parameters.ps1 -Mode Rollback -ClusterName wincl01 -ListenerName agl01

Rolls back to RegisterAllProvidersIP=0 and HostRecordTTL=1200

.EXAMPLE
.\scripts\set-ag-listener-dns-parameters.ps1 -Mode Apply -ClusterName wincl01 -ListenerName agl01 -WhatIf

Shows what would change without modifying the cluster resource

.EXAMPLE
.\scripts\set-ag-listener-dns-parameters.ps1 -Mode Apply -ClusterName wincl01 -ListenerName agl01 -NetworkNameResource "agl01"

Applies the settings to an exact Network Name resource when ListenerName matches multiple resources
#>
[CmdletBinding(SupportsShouldProcess = $true)]
param(
    [Parameter()]
    [ValidateSet('Apply', 'Rollback', 'Show')]
    [string]$Mode = 'Apply',

    [Parameter(Mandatory)]
    [string]$ClusterName,

    [Parameter(Mandatory)]
    [string]$ListenerName,

    [Parameter()]
    [string]$NetworkNameResource,

    [Parameter()]
    [int]$ApplyRegisterAllProvidersIP = 1,

    [Parameter()]
    [int]$ApplyHostRecordTTL = 60,

    [Parameter()]
    [int]$RollbackRegisterAllProvidersIP = 0,

    [Parameter()]
    [int]$RollbackHostRecordTTL = 1200,

    [Parameter()]
    [switch]$NoRestart
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

Import-Module FailoverClusters

function Get-ListenerNetworkNameResource {
    param(
        [Parameter(Mandatory)]
        [string]$ClusterName,

        [Parameter(Mandatory)]
        [string]$ListenerName,

        [Parameter()]
        [string]$NetworkNameResource
    )

    $resources = @(Get-ClusterResource -Cluster $ClusterName |
        Where-Object { $_.ResourceType.Name -eq 'Network Name' })

    if ($NetworkNameResource) {
        $matches = @($resources | Where-Object { $_.Name -eq $NetworkNameResource })
    }
    else {
        $matches = @($resources | Where-Object {
            $_.Name -eq $ListenerName -or
            $_.Name -eq "$ListenerName Network Name" -or
            $_.Name -like "*$ListenerName*"
        })
    }

    if ($matches.Count -eq 0) {
        $available = ($resources | Select-Object -ExpandProperty Name) -join ', '
        throw "Could not find a Network Name resource for listener '$ListenerName'. Available Network Name resources: $available"
    }

    if ($matches.Count -gt 1) {
        $names = ($matches | Select-Object -ExpandProperty Name) -join ', '
        throw "Found multiple candidate Network Name resources for listener '$ListenerName': $names. Rerun with -NetworkNameResource."
    }

    $matches[0]
}

function Show-ListenerDnsParameters {
    param(
        [Parameter(Mandatory)]
        [object]$Resource
    )

    $parameters = Get-ClusterParameter -InputObject $Resource |
        Where-Object { $_.Name -in @('DnsName', 'RegisterAllProvidersIP', 'HostRecordTTL') } |
        Select-Object Name, Value

    [pscustomobject]@{
        ClusterName = $ClusterName
        Resource = $Resource.Name
        State = $Resource.State.ToString()
        OwnerGroup = $Resource.OwnerGroup.Name
        OwnerNode = $Resource.OwnerNode.Name
        Parameters = @($parameters)
    }
}

$resource = Get-ListenerNetworkNameResource `
    -ClusterName $ClusterName `
    -ListenerName $ListenerName `
    -NetworkNameResource $NetworkNameResource

Write-Host "Current listener DNS parameters:"
Show-ListenerDnsParameters -Resource $resource | ConvertTo-Json -Depth 4

if ($Mode -eq 'Show') {
    return
}

if ($Mode -eq 'Apply') {
    $registerAllProvidersIP = $ApplyRegisterAllProvidersIP
    $hostRecordTTL = $ApplyHostRecordTTL
}
else {
    $registerAllProvidersIP = $RollbackRegisterAllProvidersIP
    $hostRecordTTL = $RollbackHostRecordTTL
}

$target = "Network Name resource '$($resource.Name)' on cluster '$ClusterName'"
$change = "RegisterAllProvidersIP=$registerAllProvidersIP, HostRecordTTL=$hostRecordTTL"

if ($PSCmdlet.ShouldProcess($target, "Set $change")) {
    Set-ClusterParameter -InputObject $resource -Name RegisterAllProvidersIP -Value $registerAllProvidersIP
    Set-ClusterParameter -InputObject $resource -Name HostRecordTTL -Value $hostRecordTTL

    if (-not $NoRestart) {
        Stop-ClusterResource -InputObject $resource | Out-Null
        Start-ClusterResource -InputObject $resource | Out-Null
        $resource = Get-ClusterResource -Cluster $ClusterName -Name $resource.Name
    }

    Write-Host "Updated listener DNS parameters:"
    Show-ListenerDnsParameters -Resource $resource | ConvertTo-Json -Depth 4
}
