#Requires -Version 3.0

<#
.SYNOPSIS
	Creates an offline Scout data file for a Citrix 7.x/18xx/19xx Site.
.DESCRIPTION
	Creates an offline Scout data file for a Citrix 7.x/18xx/19xx Site.

	If run on a Delivery Controller: creates a zip file named:
	Site Name_DDC_DDC Name_yyyy-MM-dd_HHmm_ScoutData.zip
	
	If run on a VDA, attempts to find the VDA's registered delivery controller 
	and then attempts to find the Site Name.
	
		If the Site name is found, creates a zip file named:
		Site Name_VDA_VDA Name_yyyy-MM-dd_HHmm_ScoutData.zip
		
		If the Site name is not found, creates a zip file named:
		VDA_VDA_VDA Name_yyyy-MM-dd_HHmm_ScoutData.zip
		
		If there are registry access issues on the VDA, creates a zip file named:
		Unable to Determine_VDA_VDA Name_yyyy-MM-dd_HHmm_ScoutData.zip

	This script must be run on a Delivery Controller, or a VDA with either Call Home 
	enabled or the Broker_PowerShell_SnapIn_x64 installed. That snapin's installer is 
	located on the installation media at 
	\x64\Citrix Desktop Delivery Controller\Broker_PowerShell_SnapIn_x64.msi
	
	This script does not require an elevated PowerShell session.

	This script can be run by a Read-Only Site Administrator.

	This script requires PowerShell version 3 or later.

	For full health information, you should run this script on every Delivery 
	Controller in a Site and at least one of each VDA in a Machine Catalog.

	The Start-CitrixCallHomeUpload cmdlet does not have a parameter to run 
	against a remote Delivery Controller or VDA. The cmdlet will also not overwrite 
	a Zip file if it exists which is why the time is added to the Zip file name.

	Once the script has created the Zip file, the file can be copied to another 
	computer and then uploaded to https://cis.citrix.com as 
	"Upload for self-diagnostics"

.PARAMETER Folder
	Specifies the optional output folder to save the output report. 
.EXAMPLE
	PS C:\PSScript > .\Get-OfflineScoutData.ps1
	
	Saves the Scout data in a zip file in the folder from where the script was run.
.EXAMPLE
	PS C:\PSScript > .\Get-OfflineScoutData.ps1 -Folder \\ServerName\Share
	
	Saves the Scout data in a zip file in the folder \\ServerName\Share.
.INPUTS
	None.  You cannot pipe objects to this script.
.OUTPUTS
	No objects are output from this script.  This script creates a zip file.
.NOTES
	NAME: Get-OfflineScoutData.ps1
	VERSION: 1.01
	AUTHOR: Carl Webster
	LASTEDIT: April 3, 2019
#>

[CmdletBinding(SupportsShouldProcess = $False, ConfirmImpact = "None", DefaultParameterSetName = "") ]

Param(
	[parameter(Mandatory=$False)] 
	[string]$Folder=""

	)

#region script change log	
#webster@carlwebster.com
#@carlwebster on Twitter
#http://www.CarlWebster.com
#Created on March 8, 2019
#
#V1.01 3-Apr-2019
#	Fix an issue where the ListOfDDCs regkey value isn't seen by humans but PoSH "sees" it and creates 
#		an array with one element with a value of one space. Added additional tests to check if ListOfDDCs 
#		is Null or an empty string are a string of one space, then go to the test for RegisteredDdcFqdn. 
#		Thanks to Rene Bigler for finding another bug in this script.
#
#V1.00 2-Apr-2019
#	Initial release
#endregion

#region initial variable testing and setup
Set-StrictMode -Version 2

#force on
$PSDefaultParameterValues = @{"*:Verbose"=$True}
$SaveEAPreference = $ErrorActionPreference
$ErrorActionPreference = 'SilentlyContinue'

If($Folder -ne "")
{
	Write-Verbose "$(Get-Date): Testing folder path"
	#does it exist
	If(Test-Path $Folder -EA 0)
	{
		#it exists, now check to see if it is a folder and not a file
		If(Test-Path $Folder -pathType Container -EA 0)
		{
			#it exists and it is a folder
			Write-Verbose "$(Get-Date): Folder path $Folder exists and is a folder"
		}
		Else
		{
			#it exists but it is a file not a folder
			Write-Error "Folder $Folder is a file, not a folder.  Script cannot continue"
			Exit
		}
	}
	Else
	{
		#does not exist
		Write-Error "Folder $Folder does not exist.  Script cannot continue"
		Exit
	}
}

If($Folder -eq "")
{
	$pwdpath = $pwd.Path
}
Else
{
	$pwdpath = $Folder
}

If($pwdpath.EndsWith("\"))
{
	#remove the trailing \
	$pwdpath = $pwdpath.SubString(0, ($pwdpath.Length - 1))
}
#endregion

#region validation functions
Function Check-NeededPSSnapins
{
	Param([parameter(Mandatory = $True)][alias("Snapin")][string[]]$Snapins)

	#Function specifics
	$MissingSnapins = @()
	[bool]$FoundMissingSnapin = $False
	$LoadedSnapins = @()
	$RegisteredSnapins = @()

	#Creates arrays of strings, rather than objects, we're passing strings so this will be more robust.
	$loadedSnapins += Get-PSSnapin | ForEach-Object {$_.name}
	$registeredSnapins += Get-PSSnapin -Registered | ForEach-Object {$_.name}

	ForEach($Snapin in $Snapins)
	{
		#check if the snapin is loaded
		If(!($LoadedSnapins -like $snapin))
		{
			#Check if the snapin is missing
			If(!($RegisteredSnapins -like $Snapin))
			{
				#set the flag if it's not already
				If(!($FoundMissingSnapin))
				{
					$FoundMissingSnapin = $True
				}
				#add the entry to the list
				$MissingSnapins += $Snapin
			}
			Else
			{
				#Snapin is registered, but not loaded, loading it now:
				Add-PSSnapin -Name $snapin -EA 0 *>$Null
			}
		}
	}

	If($FoundMissingSnapin)
	{
		Write-Warning "Missing Windows PowerShell snap-ins Detected:"
		$missingSnapins | ForEach-Object {Write-Warning "($_)"}
		Return $False
	}
	Else
	{
		Return $True
	}
}
#endregion

$StartTime = Get-Date

#check for required Citrix snapin
If(!(Check-NeededPSSnapins "Citrix.Broker.Admin.V2"))
{
	#We're missing Citrix Snapins that we need
	$ErrorActionPreference = $SaveEAPreference
	Write-Error "`nMissing Citrix PowerShell Snap-ins Detected, check the console above for more information. 
	`nAre you sure you are running this script against a XenDesktop 7.0 or later Delivery Controller or VDA? 
	`nIf running on a VDA, make sure the Broker_PowerShell_SnapIn_x64 is installed.
	`n`nScript will now close."
	Exit
}

#is the Citrix Telementry Service running
$CitrixTelemetryService = Get-Service -EA 0 | Where-Object {$_.DisplayName -like "*Citrix Telemetry Service*"}

If($CitrixTelemetryService.Status -ne "Running")
{
	Write-Warning "The Citrix Telemetry Service is not Started"
	Write-Error "Script cannot continue.  See message above."
	Exit
}
Else
{
	Write-Host "Citrix Telemetry Service is running"
}

#check if C:\Program Files\Citrix\Telemetry Service\ is in PSModulePath
$CurrentValue = [Environment]::GetEnvironmentVariable("PSModulePath", "Machine")

If(-not $currentvalue -like "*Citrix\Telemetry Service\*")
{
	Write-Host "Adding C:\Program Files\Citrix\Telemetry Service\ to PSModulePath"
	[Environment]::SetEnvironmentVariable("PSModulePath", $CurrentValue + ";C:\Program Files\Citrix\Telemetry Service\", "Machine")	
}
Else
{
	Write-Host "C:\Program Files\Citrix\Telemetry Service\ was found in PSModulePath"
}

#get Site name
$XDSiteName = "Unable to determine"
$ComputerType = "Unable to determine"

try 
{
	$XDSiteName = (Get-BrokerSite -EA 0).Name
	$ComputerType = "DDC"
}

catch 
{
	#assume we are on a VDA. Check ListOfDDCs regkey
	$ComputerType = "VDA"
	$key = [Microsoft.Win32.RegistryKey]::OpenBaseKey([Microsoft.Win32.RegistryHive]::LocalMachine, [Microsoft.Win32.RegistryView]::Registry64)
	$subKey =  $key.OpenSubKey("SOFTWARE\Citrix\VirtualDesktopAgent")
	
	If($Null -eq $subKey)
	{
		#must have selected the option "Let MCS register the VDA"
		#HKEY_LOCAL_MACHINE\SOFTWARE\Citrix\MachineIdentityServiceAgent\VdaStateMirror
		$subKey =  $key.OpenSubKey("SOFTWARE\Citrix\MachineIdentityServiceAgent\VdaStateMirror")
		If($Null -eq $subKey)
		{
			$XDSiteName = "VDA"
		}
		Else
		{
			$AA = $subKey.GetValue("RegisteredDdcFqdn")
			#RegisteredDdcFqdn is the DDC the VDA registered with
			If($Null -eq $AA -or $AA -eq "")
			{
				$XDSiteName = "VDA"
			}
			Else
			{
				try 
				{
					$XDSiteName = (Get-BrokerSite -AdminAddress $AA -EA 0).Name
				}

				catch 
				{
					$XDSiteName = "VDA"
				}
			}
		}
	}
	Else
	{
		$XDSiteName = "VDA"
	
		try
		{
			#trying because not every VDA has the ListOfDDCs value
			#thanks to fellow CTP Rene Bigler for finding this logic flaw for me
			$value = $subKey.GetValue("ListOfDDCs").Split(" ")
			
			If($Null -eq $value -or $value -eq "" -or $value -eq " ")
			{
				#ListOfDdcs exists but contains nothing
				#now check for HKEY_LOCAL_MACHINE\SOFTWARE\Citrix\MachineIdentityServiceAgent\VdaStateMirror
				$subKey =  $key.OpenSubKey("SOFTWARE\Citrix\MachineIdentityServiceAgent\VdaStateMirror")
				If($Null -eq $subKey)
				{
					$XDSiteName = "VDA"
				}
				Else
				{
					$AA = $subKey.GetValue("RegisteredDdcFqdn")
					#RegisteredDdcFqdn is the DDC the VDA registered with
					If($Null -eq $AA -or $AA -eq "")
					{
						$XDSiteName = "VDA"
					}
					Else
					{
						try 
						{
							$XDSiteName = (Get-BrokerSite -AdminAddress $AA -EA 0).Name
						}

						catch 
						{
							$XDSiteName = "VDA"
						}
					}
				}
			}
		}
		
		catch
		{
			#ListOfDDCs is space delimited. Even with one entry, using split creates an array
			#only the first array element is needed
			$AA = $Null
			If($Null -eq $AA -or $AA -eq "")
			{
				#must have selected the option "Let MCS register the VDA"
				#HKEY_LOCAL_MACHINE\SOFTWARE\Citrix\MachineIdentityServiceAgent\VdaStateMirror
				$subKey =  $key.OpenSubKey("SOFTWARE\Citrix\MachineIdentityServiceAgent\VdaStateMirror")
				If($Null -eq $subKey)
				{
					$XDSiteName = "VDA"
				}
				Else
				{
					$AA = $subKey.GetValue("RegisteredDdcFqdn")
					#RegisteredDdcFqdn is the DDC the VDA registered with
					If($Null -eq $AA -or $AA -eq "")
					{
						$XDSiteName = "VDA"
					}
					Else
					{
						try 
						{
							$XDSiteName = (Get-BrokerSite -AdminAddress $AA -EA 0).Name
						}

						catch 
						{
							$XDSiteName = "VDA"
						}
					}
				}
			}
			Else
			{
				try 
				{
					$XDSiteName = (Get-BrokerSite -AdminAddress $AA -EA 0).Name
				}

				catch 
				{
					$XDSiteName = "VDA"
				}
			}
		}
	}
}

Write-Host "Site name is $XDSiteName"

$OutputFile = "$($pwdpath)\$($XDSiteName)_$($ComputerType)_$($Env:ComputerName)_$(Get-Date -f yyyy-MM-dd_HHmm)_ScoutData.zip"

Write-Host "Gathering Scout data and saving to $OutputFile"
Start-CitrixCallHomeUpload -OutputPath $OutputFile `
#These three items are not used by the CIS site
-Description "Scout data for Site $XDSiteName" `
-IncidentTime Get-Date `
-Name "Scout data for Site $XDSiteName" `
-EA 0

Write-Verbose "$(Get-Date): Script started: $($StartTime)"
Write-Verbose "$(Get-Date): Script ended: $(Get-Date)"
$runtime = $(Get-Date) - $StartTime
$Str = [string]::format("{0} days, {1} hours, {2} minutes, {3}.{4} seconds",
	$runtime.Days,
	$runtime.Hours,
	$runtime.Minutes,
	$runtime.Seconds,
	$runtime.Milliseconds)
Write-Verbose "$(Get-Date): Elapsed time: $($Str)"




