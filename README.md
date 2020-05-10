# Get-Offline-Scout-Data
Get Offline Scout Data

Creates an offline Scout data file for a Citrix 7.x/18xx/19xx/20xx Site.

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

This script must be run on a Delivery Controller, or a VDA with either Call Home enabled or the Broker_PowerShell_SnapIn_x64 installed. That snapin's installer is located on the installation media at
x64Citrix Desktop Delivery ControllerBroker_PowerShell_SnapIn_x64.msi

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
