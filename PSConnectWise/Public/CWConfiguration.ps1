<#
.SYNOPSIS
    Gets ConnectWise configuration information. 
.PARAMETER ID
    ConnectWise configuration ID
.PARAMETER Identifier
    ConnectWise configuration identifier name
.PARAMETER Name
    ConnectWise configuration friendly name
.PARAMETER Filter
    Query String 
.PARAMETER Property
    Name of the properties to return
.PARAMETER SizeLimit
    Max number of items to return
.PARAMETER Descending
    Changes the sorting to descending order by IDs
.PARAMETER Server
    Variable to the object created via Get-CWConnectWiseInfo
.EXAMPLE
    $CWServer = Set-CWSession -Domain "cw.example.com" -CompanyName "ExampleInc" -PublicKey "VbN85MnY" -PrivateKey "ZfT05RgN";
    Get-CWConfiguration -ID 1 -Server $CWServer;
.EXAMPLE
    $CWServer = Set-CWSession -Domain "cw.example.com" -CompanyName "ExampleInc" -PublicKey "VbN85MnY" -PrivateKey "ZfT05RgN";
    Get-CWConfiguration -Identifier "LabTechSoftware" -Server $CWServer;
.EXAMPLE
    $CWServer = Set-CWSession -Domain "cw.example.com" -CompanyName "ExampleInc" -PublicKey "VbN85MnY" -PrivateKey "ZfT05RgN";
    Get-CWConfiguration -Query "ID in (1, 2, 3, 4, 5)" -Server $CWServer;
#>
function Get-CWConfiguration
{
    
    [CmdLetBinding()]
    [OutputType("PSObject", ParameterSetName="Normal")]
    [OutputType("PSObject[]", ParameterSetName="Identifier")]
    [OutputType("PSObject[]", ParameterSetName="Name")]
    [OutputType("PSObject[]", ParameterSetName="Query")]
    [OutputType("PSObject[]", ParameterSetName="CompanyName")]
    [OutputType("PSObject[]", ParameterSetName="CompanyId")]
    [CmdletBinding(DefaultParameterSetName="Normal")]
    param
    (
       
        [Parameter(ParameterSetName='CompanyName', Position=0, Mandatory=$true)]
        [ValidateNotNullOrEmpty()]
        [string[]]$CompanyName,
		
		[Parameter(ParameterSetName='CompanyId', Position=0, Mandatory=$true)]
        [ValidateNotNullOrEmpty()]
        [string[]]$CompanyId,
		
		[Parameter(ParameterSetName='Normal', Position=0, Mandatory=$true, ValueFromPipeline=$true)]
        [ValidateNotNullOrEmpty()]
        [uint32[]]$ID,
		
        [Parameter(ParameterSetName='Identifier', Position=0, Mandatory=$true)]
        [ValidateNotNullOrEmpty()]
        [string[]]$Identifier,
		
        [Parameter(ParameterSetName='Name', Position=0, Mandatory=$true)]
        [ValidateNotNullOrEmpty()]
        [string[]]$Name,
		
        [Parameter(ParameterSetName='Query', Position=0, Mandatory=$true)]
        [ValidateNotNullOrEmpty()]
        [string]$Filter,
		
        [Parameter(ParameterSetName='Normal', Position=1, Mandatory=$false)]
        [Parameter(ParameterSetName='Identifier', Position=1, Mandatory=$false)]
        [Parameter(ParameterSetName='Name', Position=1, Mandatory=$false)]
        [Parameter(ParameterSetName='Query', Position=1, Mandatory=$false)]
        [ValidateNotNullOrEmpty()]
        [string[]]$Property,
		
        [Parameter(ParameterSetName='Identifier', Position=1, Mandatory=$false)]
        [Parameter(ParameterSetName='Name', Position=1, Mandatory=$false)]
        [Parameter(ParameterSetName='Query', Mandatory=$false)]
        [Parameter(ParameterSetName='CompanyName', Mandatory=$false)]
        [Parameter(ParameterSetName='CompanyId', Mandatory=$false)]
        [ValidateRange(1, 1000)]
        [uint32]$SizeLimit = 100,
		
        [Parameter(ParameterSetName='Identifier')]
        [Parameter(ParameterSetName='Name')]
        [Parameter(ParameterSetName='Query')]
        [Parameter(ParameterSetName='CompanyName', Mandatory=$false)]
        [Parameter(ParameterSetName='CompanyId', Mandatory=$false)]
        [switch]$Descending,
		
        [Parameter(ParameterSetName='Normal', Mandatory=$false)]
        [Parameter(ParameterSetName='Identifier', Mandatory=$false)]
        [Parameter(ParameterSetName='Name', Mandatory=$false)]
        [Parameter(ParameterSetName='Query', Mandatory=$false)]
        [Parameter(ParameterSetName='CompanyName', Mandatory=$false)]
        [Parameter(ParameterSetName='CompanyId', Mandatory=$false)]
        [ValidateNotNullOrEmpty()]
        [PSObject]$Session = $script:CWSession
    )
    
    Begin
    {
        $MAX_ITEMS_PER_PAGE = 50;
        [string]$OrderBy = [String]::Empty;
        
        # get the service
        $ConfigurationSvc = $null;
        if ($Session -ne $null)
        {
            $ConfigurationSvc = [CwApiConfigurationSvc]::new($Session);
        } 
        else 
        {
            Write-Error "No open ConnectWise session. See Set-CWSession for more information.";
        }
        
        [uint32] $configurationCount = $MAX_ITEMS_PER_PAGE;
        [uint32] $pageCount  = 1;
        
        # get the number of pages of ticket to request and total ticket count
        if (![String]::IsNullOrWhiteSpace($Filter) -or ![String]::IsNullOrWhiteSpace($Identifier) -or ![String]::IsNullOrWhiteSpace($Name) -or ![String]::IsNullOrWhiteSpace($CompanyName) -or ![String]::IsNullOrWhiteSpace($CompanyId))
        {
            if (![String]::IsNullOrWhiteSpace($Identifier))
            {
                $Filter = "identifier='$Identifier'";
                if ([RegEx]::IsMatch($Identifier, "\*"))
                {
                    $Filter = "identifier like '$Identifier'";

                }
                Write-Verbose "Created a Filter String Based on the Identifier Value ($Identifier): $Filter";
            }
            elseif (![String]::IsNullOrWhiteSpace($Name))
            {
                $Filter = "name='$Name'";
                if ($Name -contains "*")
                {
                    $Filter = "name like '$Name'";
                }
                Write-Verbose "Created a Filter String Based on the Identifier Value ($Identifier): $Filter";
            }
            elseif (![String]::IsNullOrWhiteSpace($CompanyName))
            {
                $Filter =  'company/name = "' + $CompanyName + '"';
                if ($CompanyName -contains "*")
                {
                    $Filter = 'company/name like "' + $CompanyName + '"';
                }
                Write-Verbose "Created a Filter String Based on the CompanyName Value ($CompanyName): $Filter";
            }
            elseif (![String]::IsNullOrWhiteSpace($CompanyId))
            {
                $Filter =  "company/id = $CompanyId"
                Write-Verbose "Created a Filter String Based on the CompanyName Value ($CompanyName): $Filter";
            }
			
            
            $configurationCount = $ConfigurationSvc.GetConfigurationCount($Filter);
            Write-Debug "Total Count Configuration using Filter ($Filter): $configurationCount";
            
            if ($SizeLimit -ne $null -and $SizeLimit -gt 0)
            {
                Write-Verbose "Total Company Count Excess SizeLimit; Setting Company Count to the SizeLimit: $SizeLimit"
                $configurationCount = [Math]::Min($configurationCount, $SizeLimit);
            }
            
            $pageCount = [Math]::Ceiling([double]($configurationCount / $MAX_ITEMS_PER_PAGE));
            Write-Debug "Total Number of Pages ($MAX_ITEMS_PER_PAGE Configurations Per Pages): $pageCount";
        } # end if for filter/identifier check
        
        #specify the ordering
        if ($Descending)
        {
            $OrderBy = " id desc";
        }
        
        # determines if to select all fields or specific fields
        [string[]] $Properties = $null;
        if ($null -ne $Property)
        {
            if (!($Property.Length -eq 1 -and $Property[0].Trim() -ne "*"))
            {
                # TODO add parser for valid fields only
                $Properties = $Property;
            }
        }
    }
    Process
    {
        
        for ($pageNum = 1; $pageNum -le $pageCount; $pageNum++)
        {
            if (![String]::IsNullOrWhiteSpace($Filter) -or ![String]::IsNullOrWhiteSpace($Identifier))
            {
                
                if ($null -ne $configurationCount -and $configurationCount -gt 0)
                {
                    # find how many configurations to retrieve
                    $itemsRemainCount = $configurationCount - (($pageNum - 1) * $MAX_ITEMS_PER_PAGE);
                    $itemsPerPage = [Math]::Min($itemsRemainCount, $MAX_ITEMS_PER_PAGE);
                }
                
                Write-Debug "Requesting Configuration IDs that Meets this Filter: $Filter";
                $queriedCompanies = $ConfigurationSvc.ReadConfigurations($Filter, $Properties, $OrderBy, $pageNum, $itemsPerPage);
                [psobject[]] $Configurations = $queriedCompanies;
                
                foreach ($Configuration in $Configurations)
                {
                    $Configuration;
                }
                
            } 
            else 
            {
                
                Write-Debug "Retrieving ConnectWise Configurations by Configuration ID"
                foreach ($ConfigurationId in $ID)
                {
                    Write-Verbose "Requesting ConnectWise Configuration Number: $ConfigurationId";
                    if ($null -eq $Properties -or $Properties.Length -eq 0)
                    {
                        $ConfigurationSvc.ReadConfiguration([uint32] $ConfigurationId);
                    }
                    else 
                    {
                        $ConfigurationSvc.ReadConfiguration($ConfigurationId, $Properties);
                    }
                }
                           
            } #end if
            
        } #end foreach for pagination   
    }
    End
    {
        # do nothing here
    }
}


<#
.SYNOPSIS
    ALL OF THIS IS WRONG ->>> Adds a new note to a ConnectWise ticket. 
.PARAMETER TicketID
    ID of the ConnectWise ticket to update
.PARAMETER Start
    Start time and date of the time entry
.PARAMETER End
    End time and date of the time entry
.PARAMETER Message
    New message to be added to Detailed Description, Internal Analysis, and/or Resolution section.
.PARAMETER AddToDescription
    Instructs the value of `-Message` to the Detailed Description
.PARAMETER AddToInternal
    Instructs the value of `-Message` to the Internal Analysis
.PARAMETER AddToResolution
    Instructs the value of `-Message` to the Resolution
.PARAMETER InternalNote
    Note to be added to the hidden Internal Note field 
.PARAMETER ChargeToType
    Change to type of the time entry
.PARAMETER BillOption
   Type of billing for the time entry
.PARAMETER CompanyID
    Company to charge the time entry against
.PARAMETER MemberID
    ConnectWise memeber ID of the CW user the time entry should be applied against
.EXAMPLE
    $CWServer = Set-CWSession -Domain "cw.example.com" -CompanyName "ExampleInc" -PublicKey "VbN85MnY" -PrivateKey "ZfT05RgN";
    Add-CWTimeEntry -ID 123 -Message "Added ticket note added to ticket via PowerShell." -Server $CWServer;
#>
function New-CWConfiguration
{
    [CmdLetBinding()]
    [OutputType("PSObject[]", ParameterSetName="Normal")]
    [CmdletBinding(DefaultParameterSetName="Normal")]
    param
    (
        [Parameter(ParameterSetName='Normal', Mandatory=$true)]
        [ValidateNotNullOrEmpty()]
        [uint32]$CompanyId,
		
        [Parameter(ParameterSetName='Normal', Mandatory=$true)]
        [ValidateNotNullOrEmpty()]
        [uint32]$ConfigurationTypeId = 0,
		
        [Parameter(ParameterSetName='Normal', Mandatory=$true)]
        [ValidateNotNullOrEmpty()]
        [string]$Name,
		
        [Parameter(ParameterSetName='Normal')]
        [ValidateNotNullOrEmpty()]
        [PSCustomObject]$Session = $script:CWSession
    )
    
    Begin
    {
        # get the service
        $ConfigurationSvc = $null;
        if ($Session -ne $null)
        {
            $ConfigurationSvc = [CwApiConfigurationSvc]::new($Session);
        } 
        else 
        {
            Write-Error "No open ConnectWise session. See Set-CWSession for more information.";
        }
    }
    Process
    {
		[hashtable] $data = @{
			'companyId'           = $companyId
			'configurationTypeId' = $configurationTypeId
			'name'                = $name
		}
        

        $NewConfigurationEntry = $ConfigurationSvc.CreateConfiguration($data);
        return $NewConfigurationEntry
    }
    End
    {
        # do nothing here
    }
}



<#
.SYNOPSIS
    Removes ConnectWise configuration entry information. 
.PARAMETER ID
    ConnectWise configuration entry ID
.PARAMETER Force
    Removes configuration entry without confirmation prompt
.EXAMPLE
    Remove-CWConfiguration -ID 1;
#>
function Remove-CWConfiguration 
{
    [CmdletBinding(SupportsShouldProcess = $true, ConfirmImpact="Medium")]   
    [OutputType("Boolean", ParameterSetName="Normal")]
    param
    (
        [Parameter(ParameterSetName='Normal', Position=0, Mandatory=$true, ValueFromPipeline=$true)]
        [ValidateNotNullOrEmpty()]
        [int[]]$ID,
        [Parameter(ParameterSetName='Normal', Mandatory=$false)]
        [switch]$Force,        
        [Parameter(ParameterSetName='Normal', Mandatory=$false)]
        [ValidateNotNullOrEmpty()]
        [PSCustomObject]$Session = $script:CWSession
    )
    
    Begin
    {
        # get the service
        $ConfigurationSvc = $null;
        if ($Session -ne $null)
        {
            $ConfigurationSvc = [CwApiConfigurationSvc]::new($Session);
        } 
        else 
        {
            Write-Error "No open ConnectWise session. See Set-CWSession for more information.";
        }
    }
    Process
    {
        Write-Debug "Deleting ConnectWise Time Entries by Ticket ID"
        
        foreach ($entry in $ID)
        {
            if ($Force -or $PSCmdlet.ShouldProcess($entry))
            {
                return $ConfigurationSvc.DeleteConfiguration($entry);
            }
            else
            {
                return $true;
            }
        }
    }
    End 
    {
        # do nothing here
    }
}


Export-ModuleMember -Function 'Get-CWConfiguration'
Export-ModuleMember -Function 'New-CWConfiguration' 
Export-ModuleMember -Function 'Remove-CWConfiguration'