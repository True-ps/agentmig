<#Agent and NC migtration script developed independently by Andrei Mihai Iulian from the Naverisk Customer Success Team

This script is proof of concept material.

This script is indended to be used either from Naverisk, or by being ran on devices directly.
Careful consideration and attention to detail is to be used when planning to run this script

This script is NOT intended for public/production use. 
It has not been authorized by any senior members of the Naverisk management & development teams.

This script is NOT to be given to partners without their understanding of the above statements.

Tests have been successully performed from client to client, locally on the same network and same Naverisk installation.
Tests have been successfully performed from Andrei's Naverisk server, hosted on his windows10 workstation to migrate a Windows 7 VM to the Naverisk Support NitroIT client.

Scope: Migrate Agents with or without NC package from one site to another.

Design: Engineer must provide the correct parameters in order to migrate an agent, as instructed.

Design addendum: optional parameters are:
NCtable - Can be left empty as it will auto-populate with values from External & Internal addressing.

restart - will attempt to restart the agent, so that it connects to the new server once the configs are updated. 
 - This will not return a result, if ran in naverisk and script will remain as "In Progress"
norestart - will skip restarting the agent. provides output with what was passed. Requires manual restart.

#>

$_original_NAS_ = "C:\ProgramData\Naverisk\Agent\Nas.cfg" 
$_original_NC_ = "C:\ProgramData\Naverisk\Network Controller\NC.cfg"

$_new_NAS = "C:\ProgramData\Naverisk\NAS.cfg"
$_new_NC = "C:\programdata\naverisk\NC.cfg"

$_backup_NAS = "c:\programdata\Naverisk\Backups\NAS.cfg"
$_backup_NC = "C:\ProgramData\Naverisk\Backups\NC.cfg"
# ^ define all known locations where we want to check/copy/change config files.

$agentID = "-1"
$clientID = $args[0] #->Check Devices Page, clients list(left), by hovering your mouse on the client Name, make a note of the ID.
$fqdn = "sc.external.addrss" #->check Settings->Network Controllers -> Global NC->Hostname FQDN
$srvHost = "schostname" #->check Settings->Network Controllers-> Global NC->Hostname HOSTNAME
$sysID = "yourSysID" #->check Settings->System Settings->SystemID
$ncTable = ""
$checkForRestart = $args[1]
#^allows the ClientID to be passed as parameter. checkforrestart accepts restart or norestart as parameters.

$hostname = hostname
$ip = (Get-WmiObject -Class Win32_NetworkAdapterConfiguration | where {$_.DefaultIPGateway -ne $null}).IPAddress | Select-Object -First 1
#^gets some info about the device, to pretty up the output.

Write-Host "`n`n`n`###########################################`n`nStarting Agent Migration now, on:`nDevice Name - $hostname`nIP - $ip `n`n###########################################`n"

function _serviceDispatch{

[string[]]$_services = "NaveriskAgent","NaveriskServiceMonitor"

foreach ($_service in $_services)
{
start-sleep -Seconds 2

$_svcControl = Get-Service $_service -ErrorAction SilentlyContinue

    if ($_svcControl)
        {
        Write-Host "$_service Exists! Agent is installed!"
       
            if ( $_svcControl.Status -eq "Stopped")
            {
                Write-Host "Starting the $_service Service..."
                $_svcControl.Start()
                $_svcControl.WaitForStatus("Running")
            }
            else {Write-Host "$_service is already running!"}
        }
        else
        { 
        Write-Host "$_service not found! Agent is not installed or partially installed. Program will exit!"
        break; 
        }
}

}
#^the above function will check if the Agent services are there. If they are not, you are informed.
function _configRestore{

Write-Host "You have chosen to restore the orignal configuration files from backup. Restoring..."
    
if((Test-Path $_backup_NAS ) -eq $true)
        {
        $showOriginalNAS = Get-Content $_original_NAS_
$showBackupNAS = Get-Content $_backup_NAS 

        
        Copy-Item $_backup_NAS $_original_NAS_ 
        Write-Host "We have replaced`n`n$showOriginalNAS`n`nwith`n`n$showBackupNAS"
        }
else {Write-Host "Error! $_backup_NAS not found! What are you trying to do?!"}

if((Test-Path $_backup_NC) -eq $true)
        {
        $showOriginalNC = Get-Content $_original_NC_
$showBackupNC = Get-Content $_backup_NC

         Copy-Item $_backup_NC $_original_NC_ 
         Write-Host "We have replaced`n`n$showOriginalNC`n`nwith`n`n$showBackupNC"

        }

else {Write-Host "Warning! $_backup_NC not found! Is this a Network Controller?"}


if (([string]::IsNullOrEmpty($checkForRestart)) -or ($checkForRestart -eq "norestart"))

{
Write-Host "`n`nYou have chosen the norestart way. Please check the $_original_NAS_ values are correct."
}
elseif (([string]::IsNullOrEmpty($checkForRestart)) -or ($checkForRestart -eq "norestart"))
 {  [string[]]$_ProcList = "NAS", "ServiceMonitor"

        foreach ($_proc in $_ProcList)
        {

            $_ProCtrl = Get-Process $_proc

            if ($_ProCtrl.ProcessName -eq "NAS")
                {
                Write-Host "`n`n`n`###########################################`n`nKilling Naverisk Agent. Please check your original Agent in a couple of minutes.`n`n###########################################`n"
                    $_ProCtrl.Kill()
                    $_ProCtrl.WaitForExit()
                    Write-Host "If you can see this message, then you have used the OS version of the script. Your agent was restarted."
                }
        }
   }
  
}

#^restores the original config files from backups. Script must have been ran at least once for this to work.
function _configDispatch{

if((Test-Path $_backup_NAS) -eq $false)
{mkdir "C:\ProgramData\Naverisk\Backups"}
#^test if the backup folder already exists. If not, we create it.

    if((Test-Path $_original_NAS_) -eq $true)
    {
    Copy-Item $_original_NAS_ $_backup_NAS -ErrorAction SilentlyContinue
    $_writeNew_NAS =  Get-Content $_backup_NAS | ForEach-Object {$_ -replace "AgentID=.*", "AgentID=$agentID" -replace "ClientID=.*","ClientID=$clientID" -replace "SiteControllerExternalAddress=.*", "SiteControllerExternalAddress=$fqdn" -replace "SiteControllerInternalAddress=.*", "SiteControllerInternalAddress=$srvHost" -replace "SystemID=.*", "SystemID=$sysID" -replace "NCTable=.*","NCTable=$ncTable"} | Set-Content $_new_NAS
    Copy-Item $_new_NAS $_original_NAS_ ; write-host "`nUpdated Old NAS.cfg with the following new values `n`nAgentID=$agentID`nClientID=$clientID`nSiteControllerExternalAddress=$fqdn`nSiteControllerInternalAddress=$srvhost`nSystemID=$sysID`nNCTable=$nctable"

    }
    if((Test-Path $_original_NC_) -eq $true)
    {Copy-Item $_original_NC_ $_backup_NC
    $_writeNew_NC = Get-Content $_backup_NC | ForEach-Object{$_ -replace "SiteControllerExternalAddress=.*", "SiteControllerExternalAddress=$fqdn" -replace "SiteControllerInternalAddress=.*", "SiteControllerInternalAddress=$srvHost" -replace "SystemID=.*", "SystemID=$sysID"} | Set-Content $_new_NC
    Copy-Item $_new_NC $_original_NC_ ; write-host "`nUpdated Old NC.cfg with the following new values `n`nSiteControllerExternalAddress=$fqdn`nSiteControllerInternalAddress=$srvhost`nSystemID=$sysID`nNCTable=$nctable"

    }


if (([string]::IsNullOrEmpty($checkForRestart)) -or ($checkForRestart -eq "norestart"))
    {

     Write-Host "Default action is to not restart the agent.`nYou may do so manually, from the Agent Options menu.`nThis program has used the following parameters:`n
$agentID
$clientID
$fqdn
$srvHost
$sysID
$ncTable
$checkforrestart
"
    
    }


    elseif ((-not [string]::IsNullOrEmpty($checkForRestart)) -and ($checkForRestart -eq "restart"))

    {
        [string[]]$_ProcList = "NAS", "ServiceMonitor"

        foreach ($_proc in $_ProcList)
        {

            $_ProCtrl = Get-Process $_proc

            if ($_ProCtrl.ProcessName -eq "NAS")
                {
                Write-Host "`n`n`n`###########################################`n`nKilling Naverisk Agent. Please check your migrated instance in a few minutes.`n`n###########################################`n"
                    $_ProCtrl.Kill()
                    $_ProCtrl.WaitForExit()
                    Write-Host "If you can see this message, then you have used the OS version of the script. Your agent was restarted."
                }
        }
    }
    else {

    Write-Host "You have passed an incompatible parameter with the scope of this script!!!`n`nCompatible end of function parameters are `"restart`" and `"norestart`".This program has used the following parameters:

$agentID
$clientID
$fqdn
$srvHost
$sysID
$ncTable
$checkforrestart

`nPlease check your spelling and try again."
}

 
}

#^creates backups form the original configs. creates new configs using the parameters given. replaces original config with new configs.

#^Backed-up NAS & NC cfg remain untouched and can be restored

if ((-not [string]::IsNullOrEmpty($clientID)) -and ($clientID -eq "restore"))

{

$getserviceTime = Measure-Command -Expression {_serviceDispatch}
$totalServiceTime = [math]::round($getserviceTime.TotalSeconds)


Write-host "`n`n##############################`n`nServices dispatch completed in $totalservicetime seconds.`n`nPerforming config updates!`n`n##############################`n"


$getrestoreTime = Measure-Command -Expression {_configRestore}
$totalrestoreTime = [math]::round($getrestoreTime.TotalMilliseconds)

Write-Host "`n`n`n`###########################################`n`nConfiguration restore completed in $totalrestoretime milliseconds.`n`n###########################################`n"


}
else
{

$getserviceTime = Measure-Command -Expression {_serviceDispatch}
$totalServiceTime = [math]::round($getserviceTime.TotalSeconds)


Write-host "`n`n##############################`n`nServices dispatch completed in $totalservicetime seconds.`n`nPerforming config updates!`n`n##############################`n"


$getconfigTime = Measure-Command -Expression {_configDispatch}
$totalconfigTime = [math]::round($getconfigTime.TotalMilliseconds)

Write-Host "`n`n`n`###########################################`n`nConfiguration changes completed in $totalconfigTime milliseconds.`n`n###########################################`n"

}
