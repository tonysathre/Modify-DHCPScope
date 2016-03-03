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
            $XmlFile = ("$PSScriptRoot\$ScopeId.xml")
            
            if ($Force) {
                Export-DhcpServer -ComputerName $ComputerName -ScopeId $ScopeId -File $XmlFile -Leases -Verbose -Force -ErrorAction Stop
            } else {
                Export-DhcpServer -ComputerName $ComputerName -ScopeId $ScopeId -File $XmlFile -Leases -Verbose -ErrorAction Stop    
            }

            [xml]$Xml = Get-Content -Path "$ScopeId.xml"

            $NodesToRemove = @( 'Classes',                                'OptionDefinitions',                                'OptionValues',                                'Filters'                              )            foreach ($ChildNode in $NodesToRemove) {                $Node = $xml.SelectSingleNode("//$ChildNode")                $Node.ParentNode.RemoveChild($Node) | Out-Null            }

            $Xml.DHCPServer.IPv4.Scopes.Scope.SubnetMask = $SubnetMask
            $Xml.DHCPServer.IPv4.Scopes.Scope.StartRange = $StartRange
            $Xml.DHCPServer.IPv4.Scopes.Scope.EndRange   = $EndRange
            $Xml.Save($XmlFile)

            if ($Force) {
                Remove-DhcpServerv4Scope -ComputerName $ComputerName -ScopeId $ScopeId -Verbose -Force -ErrorAction Stop
                Import-DhcpServer -ComputerName $ComputerName -File $XmlFile -ScopeId $ScopeId -BackupPath $BackupPath -Leases -Verbose -Force -ErrorAction Stop
            } else {
                Remove-DhcpServerv4Scope -ComputerName $ComputerName -ScopeId $ScopeId -Verbose -ErrorAction Stop
                Import-DhcpServer -ComputerName $ComputerName -File $XmlFile -ScopeId $ScopeId -BackupPath $BackupPath -Leases -Verbose -ErrorAction Stop
            }
        }
        catch {
            throw $Error[0]
        }
    } else {
        throw "Unable to contact $ComputerName"
    }
}

Modify-DHCPScope -ComputerName comdhcpp01 -ScopeId 192.168.16.0 -SubnetMask 255.255.252.0 -StartRange 192.168.16.5 -EndRange 192.168.19.250 -BackupPath 192.168.16.0.bak