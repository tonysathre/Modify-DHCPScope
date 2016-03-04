function Modify-DHCPScope {
    [CmdletBinding()] 
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
    
    if (Test-Connection -ComputerName $ComputerName -Count 2 -Quiet) {
        try {

            $PSDefaultParameterValues['*:Verbose'] = $true
            $PSDefaultParameterValues['*:Force']   = $Force
            $PSDefaultParameterValues['*:Leases']   = $true

            $ErrorActionPreference = 'Stop'

            $XmlFile = ("$PSScriptRoot\$ScopeId.xml")
            $RestoreXml = ("$PSScriptRoot\$ScopeId.xml.bak")

            $ComputerAndScope = @{
                ComputerName = $ComputerName
                ScopeId      = $ScopeId
            }

            $ExportScopeProperties = @{
                File   = $XmlFile
            }

            Export-DhcpServer @ExportScopeProperties @ComputerAndScope

            [xml]$Xml = Get-Content -Path "$ScopeId.xml"

            $NodesToRemove = @(                 'Classes',                'OptionDefinitions',                'OptionValues',                'Filters'            )            foreach ($ChildNode in $NodesToRemove) {                $Node = $xml.SelectSingleNode("//$ChildNode")                $Node.ParentNode.RemoveChild($Node) | Out-Null            }

            # Save backup of current scope configuration in case restore fails after removing the scope
            $Xml.Save($RestoreXml)

            $Xml.DHCPServer.IPv4.Scopes.Scope.SubnetMask = $SubnetMask
            $Xml.DHCPServer.IPv4.Scopes.Scope.StartRange = $StartRange
            $Xml.DHCPServer.IPv4.Scopes.Scope.EndRange   = $EndRange
            $Xml.Save($XmlFile)

            $ImportScopeProperties = @{
                BackupPath   = $BackupPath
                File         = $XmlFile
            }
            
            Write-Verbose 'Checking if scope is part of a failover relationship...'
            $FailoverRelationship = Get-DhcpServerv4Failover @ComputerAndScope -ErrorAction SilentlyContinue

            if ($FailoverRelationship) {
                Write-Verbose "Failover relationship found. Removing it from the partner server $($FailoverRelationship.PartnerServer)."
                Remove-DhcpServerv4FailoverScope @ComputerAndScope -Name $FailoverRelationship.Name

                if ($?) { $FailoverRemoved = $true }

            } else {
                Write-Verbose "No failover relationship found."
            }

            Remove-DhcpServerv4Scope @ComputerAndScope
            if ($?) { $ScopeRemoved = $true }
            Import-DhcpServer @ImportScopeProperties @ComputerAndScope

            if ($FailoverRelationship) {
                Add-DhcpServerv4FailoverScope @ComputerAndScope -Name $FailoverRelationship.Name
            }
        }
        catch {
            # If something failed, reimport the scope and restore the failover relationship
            Write-Verbose 'Restoring scope'

            if ($ScopeRemoved) {
                Import-DhcpServer @ComputerAndScope -BackupPath $BackupPath -File $RestoreXml
            }

            if ($FailoverRemoved) {
                Add-DhcpServerv4FailoverScope @ComputerAndScope -Name $FailoverRelationship.Name
            }

            throw $Error[0]

        }
        finally {
            Remove-Item $XmlFile, $RestoreXml
        }
    } else {
        throw "Unable to contact $ComputerName."
    }
}