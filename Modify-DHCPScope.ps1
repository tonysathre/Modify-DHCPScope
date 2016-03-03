function Modify-DHCPScope {
    param (
        [Parameter(Mandatory=$true)]
            [string]$ComputerName,
        [Parameter(Mandatory=$true)]
            [string]$ScopeId,
        [Parameter(Mandatory=$true)]
            [string]$SubnetMask,
        [Parameter(Mandatory=$true)]
            [string]$StartRange,
        [Parameter(Mandatory=$true)]
            [string]$EndRange,
        [Parameter(Mandatory=$true)]
            [string]$BackupPath,
            [switch]$Force
    )

    if (Test-Connection -ComputerName $ComputerName -Count 2 -Quiet -Verbose) {
        try {
            
            $ErrorActionPreference = 'Stop'
            #$VerbosePreference     = 'Continue'

            $XmlFile = ("$PSScriptRoot\$ScopeId.xml")
            
            $ExportScopeProperties = @{
                ComputerName  = $ComputerName
                ScopeId       = $ScopeId
                File          = $XmlFile
            }

            if ($Force) {
                Export-DhcpServer @ExportScopeProperties -Leases -Force -Verbose -ErrorAction Stop
            } else {
                Export-DhcpServer @ExportScopeProperties -Leases -Verbose -ErrorAction Stop
            }
            
            [xml]$Xml = Get-Content -Path "$ScopeId.xml"

            $NodesToRemove = @(                 'Classes',                'OptionDefinitions',                'OptionValues',                'Filters'            )            foreach ($ChildNode in $NodesToRemove) {                $Node = $xml.SelectSingleNode("//$ChildNode")                $Node.ParentNode.RemoveChild($Node) | Out-Null            }

            $Xml.DHCPServer.IPv4.Scopes.Scope.SubnetMask = $SubnetMask
            $Xml.DHCPServer.IPv4.Scopes.Scope.StartRange = $StartRange
            $Xml.DHCPServer.IPv4.Scopes.Scope.EndRange   = $EndRange
            $Xml.Save($XmlFile)

            $RemoveScopeProperties = @{
                ComputerName = $ComputerName
                ScopeId      = $ScopeId
            }

            $ImportScopeProperties = @{
                ComputerName = $ComputerName
                ScopeId      = $ScopeId
                BackupPath   = $BackupPath
                File         = $XmlFile
            }

            $FailoverProperties = @{
                ComputerName = $ComputerName
                Name         = $FailoverRelationship.Name
                ScopeId      = $ScopeId
            }
            
            Write-Verbose 'Checking if scope is part of a failover relationship...'
            $FailoverRelationship = Get-DhcpServerv4Failover -ComputerName $ComputerName -ScopeId $ScopeId -ErrorAction SilentlyContinue

            if ($FailoverRelationship) {
                Write-Verbose "Failover relationship found. Removing it from the partner server $($FailoverRelationship.PartnerServer)."
                Remove-DhcpServerv4FailoverScope -ComputerName $ComputerName -ScopeId $ScopeId -Name $FailoverRelationship.Name -Verbose
            } else {
                Write-Verbose "No failover relationship found."    
            }

            if ($Force) {
                Remove-DhcpServerv4Scope @RemoveScopeProperties -Force -Verbose
                Import-DhcpServer @ImportScopeProperties -Leases -Force -Verbose
            } else {
                Remove-DhcpServerv4Scope @RemoveScopeProperties -ErrorAction Stop -Verbose
                Import-DhcpServer @ImportScopeProperties -Leases -Verbose
            }

            if ($FailoverRelationship) {
                Add-DhcpServerv4FailoverScope @FailoverProperties -Verbose
            }
        }
        catch {
            throw $Error[0]
        }
        finally {
            Remove-Item $XmlFile -Force -Verbose
        }
    } else {
        throw "Unable to contact $ComputerName"
    }
}

Modify-DHCPScope -ComputerName dc1 -ScopeId 12.12.12.0 -SubnetMask 255.0.0.0 -StartRange 12.12.12.200 -EndRange 12.12.12.250 -BackupPath c:\temp\adsf.bak -Verbose -Force