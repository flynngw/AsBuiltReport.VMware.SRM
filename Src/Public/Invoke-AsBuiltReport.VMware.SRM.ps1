function Invoke-AsBuiltReport.VMware.SRM {
    <#
    .SYNOPSIS
        PowerShell script to document the configuration of VMware SRM in Word/HTML/Text formats
    .DESCRIPTION
        Documents the configuration of VMware SRM in Word/HTML/Text formats using PScribo.
    .NOTES
        Version:        0.3.2
        Author:         Matt Allford (@mattallford)
        Editor:         Jonathan Colon
        Twitter:        @jcolonfzenpr
        Github:         @rebelinux
        Credits:        Iain Brighton (@iainbrighton) - PScribo module
    .LINK
        https://github.com/AsBuiltReport/AsBuiltReport.VMware.SRM
    #>

	# Do not remove or add to these parameters
    param (
        [String[]] $Target,
        [PSCredential] $Credential
    )
    # Check if the required version of VMware PowerCLI is installed
    Get-AbrSRMRequiredModule -Name 'VMware.PowerCLI' -Version '12.3'

    # Import Report Configuration
    $Report = $ReportConfig.Report
    $InfoLevel = $ReportConfig.InfoLevel
    $Options = $ReportConfig.Options

    # Used to set values to TitleCase where required
    $TextInfo = (Get-Culture).TextInfo

    #region foreach loop
    #---------------------------------------------------------------------------------------------#
    #                                 Connection Section                                          #
    #---------------------------------------------------------------------------------------------#
    foreach ($VIServer in $Target) {
        #region Protect Site vCenter connection
        try {
            Write-PScriboMessage "Connecting to SRM protected site vCenter: $($VIServer) with provided credentials."
            $LocalvCenter = Connect-VIServer $VIServer -Credential $Credential -Port 443 -Protocol https -ErrorAction Stop
            if ($LocalvCenter) {
                Write-PScriboMessage "Successfully connected to SRM protected site vCenter: $($LocalvCenter.Name)."
            }
        }
        catch {
            Write-PScriboMessage -IsWarning  "Unable to connect to SRM protected site vCenter Server $($VIServer))."
            Write-Error "$($_) (Protected vCenter Connection)."
            throw
        }
        #endregion Protect Site vCenter connection

        #region Protect Site SRM connection
        try {
            Write-PScriboMessage "Connecting to SRM server at protected site with provided credentials."
            $LocalSRM = Connect-SrmServer -IgnoreCertificateErrors -ErrorAction Stop -Port 443 -Protocol https -Credential $Credential -Server $LocalvCenter
            if ($LocalSRM) {
                Write-PScriboMessage "Successfully connected to SRM server at protected site: $($LocalSRM.Name) with provided credentials."
                $global:ProtectedSiteName = $LocalSRM.ExtensionData.GetLocalSiteInfo().SiteName
                $global:RecoverySiteName = $LocalSRM.ExtensionData.GetPairedSite().Name
            }
        } catch {
            Write-PScriboMessage -IsWarning  "Unable to connect to SRM server at protected site."
            Write-Error "$($_) (Local SRM Connection)."
            throw
        }
        #endregion Protect Site SRM connection

        #region Recovery Site vCenter connection
        try {
            $RemotevCenter = Connect-VIServer $LocalSRM.ExtensionData.GetPairedSite().vcHost -Credential $Credential -Port 443 -Protocol https -ErrorAction SilentlyContinue
            if ($RemotevCenter) {
                Write-PScriboMessage "Connected to $((Get-AdvancedSetting -Entity $RemotevCenter | Where-Object {$_.name -eq 'VirtualCenter.FQDN'}).Value)."
                try {
                    Write-PScriboMessage "Connecting to SRM server at recovery site with provided credentials."
                    $RemoteSRM = Connect-SrmServer -IgnoreCertificateErrors -Server $RemotevCenter -Credential $Credential -Port 443 -Protocol https -RemoteCredential $Credential
                    if ($RemoteSRM) {
                        Write-PScriboMessage "Successfully connected to SRM server at recovery site: $($RemoteSRM.Name) with provided credentials."
                    }
                }
                catch {
                    Write-PScriboMessage -IsWarning  "Unable to connect to SRM server at recovery site."
                    Write-Error $_
                    throw
                }
            }
            <#
            if (!$RemotevCenter) {
                try {
                    $Credential = (Get-Credential -Message "Can not connect to the recovery vCenter with the provided credentials.`r`nEnter $($LocalSRM.ExtensionData.GetPairedSite().vcHost) valid credentials")
                    $RemotevCenter = Connect-VIServer $LocalSRM.ExtensionData.GetPairedSite().vcHost -Credential $Credential -Port 443 -Protocol https -ErrorAction Stop
                    if ($RemotevCenter) {
                        Write-PScriboMessage "Connected to $((Get-AdvancedSetting -Entity $RemotevCenter | Where-Object {$_.name -eq 'VirtualCenter.FQDN'}).Value)"
                        try {
                            $RemoteSRM = Connect-SrmServer -IgnoreCertificateErrors -Server $RemotevCenter -Credential $Credential -Port 443 -Protocol https -RemoteCredential $Credential
                            if ($RemoteSRM) {
                                Write-PScriboMessage "Successfully connected to recovery site SRM with provided credentials"
                            }
                        }
                        catch {
                            Write-PScriboMessage -IsWarning  "Unable to connect to recovery site SRM Server"
                            Write-Error $_
                            throw
                        }
                    }
                }
                catch {
                    Write-PScriboMessage -IsWarning  "Unable to connect to recovery site vCenter Server: $($TempSRM.ExtensionData.GetPairedSite().vcHost)"
                    Write-Error $_
                    throw
                }
            }
            #>
        }
        catch {
            Write-Error $_
        }
        #endregion Recovery Site vCenter connection

        <#
        try {
            Write-PScriboMessage "Connecting to protected site SRM with updated credentials"
            $LocalSRM = Connect-SrmServer -IgnoreCertificateErrors -ErrorAction Stop -Port 443 -Protocol https -Credential $Credential -Server $LocalvCenter -RemoteCredential $Credential
            if ($LocalSRM) {
                Write-PScriboMessage "Reconnected to protected site SRM: $($LocalSRM.Name)"
            }
        } catch {
            Write-PScriboMessage -IsWarning  "Unable to connect to protected site SRM server"
            Write-Error "$($_) (Local SRM Connection)"
            throw
        }
        #>

        #region VMware SRM As Built Report
        # If Protected Site exists, generate VMware SRM As Built Report
        if ($LocalSRM) {
            Section -Style Heading1 "$($LocalSRM.Name.split(".", 2).toUpper()[0])" {
                if ($Options.ShowDefinitionInfo) {
                    Paragraph "VMware Site Recovery Manager is an extension to VMware vCenter Server that delivers a business continuity and disaster recovery solution that helps you plan, test, and run the recovery of vCenter Server virtual machines."
                    BlankLine
                }

                Write-PScriboMessage "Sites InfoLevel set at $($InfoLevel.Sites)."
                if ($InfoLevel.Sites -ge 1) {
                    Get-AbrSRMSitePairs
                }

                Write-PScriboMessage "vCenter InfoLevel set at $($InfoLevel.vCenter)."
                if ($InfoLevel.vCenter -ge 1) {
                    Get-AbrSRMvCenterServer
                }

                Write-PScriboMessage "License InfoLevel set at $($InfoLevel.License)."
                if ($InfoLevel.License -ge 1) {
                    Get-AbrSRMLicense
                }

                Write-PScriboMessage "Permission InfoLevel set at $($InfoLevel.Permission)."
                if ($InfoLevel.Permission -ge 1) {
                    Get-AbrSRMPermission
                }

                Write-PScriboMessage "SRA InfoLevel set at $($InfoLevel.SRA)."
                if ($InfoLevel.SRA -ge 1) {
                    Get-AbrSRMStorageReplicationAdapter
                }

                Write-PScriboMessage "Array Pairs InfoLevel set at $($InfoLevel.ArrayPairs)."
                if ($InfoLevel.ArrayPairs -ge 1) {
                    Get-AbrSRMArrayPairs
                }

                Write-PScriboMessage "Network Mapping InfoLevel set at $($InfoLevel.NetworkMapping)."
                if ($InfoLevel.NetworkMapping -ge 1) {
                    Get-AbrSRMNetworkMapping
                }

                Write-PScriboMessage "Folder Mapping InfoLevel set at $($InfoLevel.FolderMapping)."
                if ($InfoLevel.FolderMapping -ge 1) {
                    Get-AbrSRMFolderMapping
                }

                Write-PScriboMessage "Resource Mapping InfoLevel set at $($InfoLevel.ResourceMapping)."
                if ($InfoLevel.ResourceMapping -ge 1) {
                    Get-AbrSRMResourceMapping
                }

                Write-PScriboMessage "Placeholder Datastores InfoLevel set at $($InfoLevel.PlaceholderDatastores)."
                if ($InfoLevel.PlaceholderDatastores -ge 1) {
                    Get-AbrSRMPlaceholderDatastore
                }

                Write-PScriboMessage "Protection Group Site InfoLevel set at $($InfoLevel.ProtectionGroup)."
                if ($InfoLevel.ProtectionGroup -ge 1) {
                    Get-AbrSRMProtectionGroup
                }

                Write-PScriboMessage "Recovery Plan InfoLevel set at $($InfoLevel.RecoveryPlan)."
                if ($InfoLevel.RecoveryPlan -ge 1) {
                    Get-AbrSRMRecoveryPlan
                }
                if ($InfoLevel.Summary -ge 1) {
                    Get-AbrVRMSProtection
                }
            }
        }
        #endregion VMware SRM As Built Report
	}
    #endregion foreach loop
}