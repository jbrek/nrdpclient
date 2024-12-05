# Check Result Example
# OK : Average CPU Usage 0.47 % 
# OK is from Get-State(LE or GE) called the $returnstring
# Average CPU Usage 0.47 %  is from $datastring
# $returnstring + $datastring = OK : Average CPU Usage 0.47 % 
# 6-5-2024 
# fix check-nic 11-20-2024
# fix formating and logging 12/5/2024

#stopwatch
$stopwatch1 = [System.Diagnostics.Stopwatch]::StartNew()

# Define constant variables
$global:NagiosServerUrl = "http://nagios.lan/nrdp"
$global:Token = "Uc1#kk^Ns%xV--t@+sbc&@=!Onc%qSPh"
$global:nrdppath = "C:\scripts\git\nscp-checks\ps_nrdp.ps1"
$global:Hostname = $env:COMPUTERNAME
#$global:Hostname = "computernameoverride"


# Enable debug messages
 $DebugPreference = "Continue"
# Disable debug messages
$DebugPreference = "SilentlyContinue"

function Check-Firewall{
    
    param (
        [string]$ServiceName="FIREWALL"
    )
    start-transcript -path ./log-$ServiceName.txt -append
    $stopwatch = [System.Diagnostics.Stopwatch]::StartNew()
    $nagioswarn = 1
    $nagioscrit = 2
    $returnStateOK = 0
    $returnStateWarning = 1
    $returnStateCritical = 2
    $returnStateUnknown = 3
    $exitcode = $returnStateUnknown
    $returnarray = @()

    $results = netsh advfirewall show currentprofile


    if ($results -like "Domain Profile*") {
        $returnarray = "Domain Profile"
    }
    elseif ($results -like "Private Profile*") {
        $returnarray = "Private Profile"
    }
    elseif ($results -like "Public Profile*") {
        $returnarray = "Public Profile"
    }
    if ($results -like "State                                 ON") {
        $exitcode = $returnStateOK
        $returnarray = "OK: Firewall ON $returnarray"
    }
    else {
        $exitcode = $returnStateCritical
        $returnarray = "CRITICAL: Firewall OFF $returnarray"
    }
    if ($exitcode -eq "3") {
        $returnarray = "Unknown Error"
    }

    $OutputPerfdata = " | exitcode=0"
    #$exitcode"
    Write-Host $OutputPerfdata

    $statusString = switch ($exitcode) {
        0 { "OK" }
        1 { "WARNING" }
        2 { "CRITICAL" }
        default { "UNKNOWN" }
    }

    # Call ps_nrdp.ps1 script to send the check result
    & $nrdppath -url $NagiosServerUrl -token $Token -hostname $Hostname -state $statusString -service $ServiceName -output "$returnarray $OutputPerfdata"
    Write-Host "-url $NagiosServerUrl -token $Token -hostname $Hostname -state $statusString -service $ServiceName -output $returnarray $OutputPerfdata" 
     # Exit with the appropriate status code
    $stopwatch.Stop()
    Write-Host "Total seconds: $($stopwatch.Elapsed.TotalSeconds)" -foregroundcolor Blue
    Stop-transcript

}

function Check-MEM {

    param (
        [string]$ServiceName = "MEM"
    )
    $stopwatch = [System.Diagnostics.Stopwatch]::StartNew()
    start-transcript -path ./log-$ServiceName.txt -append
    $nagioswarn = 85  # Set warning threshold to 80%
    $nagioscrit = 95  # Set critical threshold to 90%
    $returnStateOK = 0
    $returnStateWarning = 1
    $returnStateCritical = 2
    $returnStateUnknown = 3
    $exitcode = $returnStateUnknown
    $returnarray = @()

    # Get memory usage
    $computerInfo = Get-CimInstance -ClassName CIM_OperatingSystem
    $totalMemory = $computerInfo.TotalVisibleMemorySize * 1KB  # Convert to bytes
    $freeMemory = $computerInfo.FreePhysicalMemory * 1KB       # Convert to bytes
    $usedMemory = $totalMemory - $freeMemory
    $usedMemoryPercent = [math]::Round(($usedMemory / $totalMemory) * 100, 2)
    
 
    # Convert memory size from Bytes to GB
    $totalMemoryGB = [math]::Round($totalMemory / 1GB, 2)
    $freeMemoryGB = [math]::Round($freeMemory / 1GB, 2)
    $usedMemoryGB = [math]::Round($usedMemory / 1GB, 2)
    $warn = $nagioswarn *  $totalMemoryGB
    $crit = $nagioscrit *  $totalMemoryGB
 
    # Create a custom object to hold the memory information
    $memoryUsage = [PSCustomObject]@{
        TotalMemoryGB      = $totalMemoryGB
        UsedMemoryGB       = $usedMemoryGB
        FreeMemoryGB       = $freeMemoryGB
        UsedMemoryPercent  = $usedMemoryPercent
    }

    # Determine Nagios exit code
    if ($usedMemoryPercent -ge $nagioscrit) {
        $exitcode = $returnStateCritical
        $returnarray = "CRITICAL: Memory Usage $usedMemoryPercent% - Total: $totalMemoryGB GB, Used: $usedMemoryGB GB, Free: $freeMemoryGB GB"
    }

    elseif ($usedMemoryPercent -ge $nagioswarn) {
        $exitcode = $returnStateWarning
        $returnarray = "WARNING: Memory Usage $usedMemoryPercent% - Total: $totalMemoryGB GB, Used: $usedMemoryGB GB, Free: $freeMemoryGB GB"
    }

    else {
        $exitcode = $returnStateOK
        $returnarray = "OK: Memory Usage $usedMemoryPercent% - Total: $totalMemoryGB GB, Used: $usedMemoryGB GB, Free: $freeMemoryGB GB"
    } 

    $OutputPerfdata = " | used_memory_percent=$usedMemoryPercent;$nagioswarn;$nagioscrit;0;100 MemoryUsed=$($usedMemoryGB)GB;$warn;$crit"
    Write-Host $OutputPerfdata 

    $statusString = switch ($exitcode) {
        0 { "OK" }
        1 { "WARNING" }
        2 { "CRITICAL" }
        default { "UNKNOWN" }

    }
    # Call ps_nrdp.ps1 script to send the check result
    & $nrdppath -url $NagiosServerUrl -token $Token -hostname $Hostname -state $statusString -service $ServiceName -output "$returnarray $OutputPerfdata"

    Write-Host "-state $statusString -service $ServiceName -output $returnarray $OutputPerfdata"
    $stopwatch.Stop()
    Write-Host "Total seconds: $($stopwatch.Elapsed.TotalSeconds)" -foregroundcolor Blue
    Stop-transcript

} 

function Check-CPU {
    param (
        [string]$ServiceName = "CPU",
        [int]$NagiosWarn = 90,
        [int]$NagiosCrit = 95,
        [int]$sampleInterval = 2,
        [int]$totalSamples = 2
            )
    start-transcript -path ./log-$servicename.txt -append
    $stopwatch = [System.Diagnostics.Stopwatch]::StartNew()
    # Initialize an array to store CPU usage samples
    $cpuSamples = @{}

# Run the Get-Counter command
$counterData = Get-Counter -Counter "\Processor(_Total)\% Processor Time" -SampleInterval $sampleInterval  -MaxSamples $totalSamples

# Extract the CPU usage values from the counter data
$cpuUsages = $counterData.CounterSamples | Select-Object -ExpandProperty CookedValue

# Calculate the average CPU usage
$totalCPUUsage = ($cpuUsages | Measure-Object -Sum).Sum
$cpuavg = [Math]::Round($totalCPUUsage / $cpuUsages.Count)


    # Define exit codes for Nagios
    $returnStateOK = 0
    $returnStateWarning = 1
    $returnStateCritical = 2
    $returnStateUnknown = 3

    # Determine the state based on thresholds
    if ($cpuavg -ge $NagiosCrit) {
        $state = "CRITICAL"
        $exitcode = $returnStateCritical
    } elseif ($cpuavg -ge $NagiosWarn) {
        $state = "WARNING"
        $exitcode = $returnStateWarning
    } else {
        $state = "OK"
        $exitcode = $returnStateOK
    }

    # Define the performance data label for Nagios
    $perfdata_label = "CPU_Usage_Percentage"

    # Output the average CPU usage
    $output = "$state : Average CPU Usage $cpuavg %"
    $perfdata = "'$perfdata_label'=$($cpuavg)%;$NagiosWarn;$NagiosCrit;0;100"

    $status = switch ($exitcode) {
        0 { "OK" }
        1 { "WARNING" }
        2 { "CRITICAL" }
        default { "UNKNOWN" }
    }

    # Format the output for Nagios
    $statusmsg = "$output | $perfdata"

    
    & $nrdppath -url $NagiosServerUrl -token $Token -hostname $Hostname -state $status -service $ServiceName -output $statusmsg
    Write-Host "-state $status -service $ServiceName -output $statusmsg"
    $stopwatch.Stop()
    Write-Host "Total function - seconds: $($stopwatch.Elapsed.TotalSeconds)" -foregroundcolor Blue
    stop-transcript
}

function Check-DriveSpace {
    param (
        [string]$ServiceName = "DRIVE",
        [int]$NagiosWarn = 85,
        [int]$NagiosCrit = 95
    )
    start-transcript -path ./log-$ServiceName.txt -append
    $stopwatch = [System.Diagnostics.Stopwatch]::StartNew()

    $driveType = 'Fixed'
    $returnStateOK = 0
    $returnStateWarning = 1
    $returnStateCritical = 2
    $returnStateUnknown = 3
    $exitcode = $returnStateUnknown

    foreach ($drive in [System.IO.DriveInfo]::GetDrives()) {
        if ($drive.DriveType -eq $driveType) {
            $percent = [math]::Floor((100 - ($drive.AvailableFreeSpace / $drive.TotalSize * 100)))
            
            if ([Math]::Round($drive.AvailableFreeSpace / 1TB, 2) -ge 1) {
                $output = "$($drive.VolumeLabel) $($drive.Name) is $percent% used. $([math]::Round($drive.AvailableFreeSpace / 1TB, 2))TB free of $([math]::Round($drive.TotalSize / 1TB, 1))TB"
            } elseif ([Math]::Round($drive.TotalSize / 1TB, 1) -ge 1) {
                $output = "$($drive.VolumeLabel) $($drive.Name) is $percent% used. $([math]::Round($drive.AvailableFreeSpace / 1GB, 0))GB free of $([math]::Round($drive.TotalSize / 1TB, 1))TB"
            } else {
                $output = "$($drive.VolumeLabel) $($drive.Name) is $percent% used. $([math]::Round($drive.AvailableFreeSpace / 1GB, 0))GB free of $([math]::Round($drive.TotalSize / 1GB, 0))GB"
            }
            
            $OutputPerfdata = " | $($drive.Name)_used_%=$percent%;$NagiosWarn;$NagiosCrit $($drive.Name)_used_GB=$([math]::Round(($drive.TotalSize / 1GB) - ($drive.AvailableFreeSpace / 1GB)))GB;$([math]::Round(($NagiosWarn * 0.01) * ($drive.TotalSize / 1GB), 2));$([math]::Round(($NagiosCrit * 0.01) * ($drive.TotalSize / 1GB), 2));0;$([math]::Round($drive.TotalSize / 1GB, 2))"
            
            $datastring = $output + $OutputPerfdata
            
            #function call
            $state = Get-Statege -value $percent -NagiosCrit $NagiosCrit -NagiosWarn $NagiosWarn    
            #function call
            $status = Get-exitstatus -exitstatus $state["exitcode"]

            #this changes service name to DRIVE C:\ D:\....
            $currentServiceName = "$ServiceName $($drive.Name -replace '\\', '')"

            #$status = Get-exitstatus -exitstatus $state["exitcode"]
            $returnstring = $state["returnstring"] + $datastring
            wRITE-DEBUG  "return string $returnstring"
            # Define parameters in a hashtable
            $notificationParams = @{
            returnstring = $returnstring
            ServiceName = $currentServiceName
            status = $status }
            # Call the function with splatting
            Send-NagiosNotification @notificationParams
            Write-host  @notificationParams
            }
    }

   $stopwatch.Stop()
    Write-Host "Total function - seconds: $($stopwatch.Elapsed.TotalSeconds)" -foregroundcolor Blue
     stop-transcript
}

function check-uptime {
     param (
        [int]$NagiosWarn=4, #hours
        [int]$NagiosCrit=8, #hour must be greater than Warning
        [string]$ServiceName = "UPTIME" 
          )
        $stopwatch = [System.Diagnostics.Stopwatch]::StartNew()
        start-transcript -path ./log-$ServiceName.txt -append
        $lastBootTime = (Get-CimInstance -ClassName Win32_OperatingSystem).LastBootUpTime 
        $currentDate = Get-Date
        #pwsh7 only  for time span
        $timeSpan = New-TimeSpan -Start $lastBootTime -End $currentDate
        $hoursup = [Math]::Round($timeSpan.totalhours, 2)

    
        $datastring = "Uptime: $((Get-Date) - $lastBootTime | Format-TimeSpan) Last Boot: $lastBootTime | hours=$hoursup"
        #get state function
        $state = Get-Statele -value $hoursup -NagiosCrit $NagiosCrit -NagiosWarn $NagiosWarn

        # Define parameters in a hashtable
        $notificationParams = @{
         returnstring = $state["returnstring"] + $datastring
         ServiceName = $ServiceName
         status = $state["exitcodetxt"]
         }
 
        # Call the function with splatting
        Send-NagiosNotification @notificationParams
        Write-host @notificationParams
        $stopwatch.Stop()
        Write-Host "Total function - seconds: $($stopwatch.Elapsed.TotalSeconds)" -foregroundcolor Blue
        Stop-Transcript
}#function check-uptime

function check-osverison{
    $stopwatch = [System.Diagnostics.Stopwatch]::StartNew()
    $Caption= (Get-CimInstance -ClassName Win32_OperatingSystem).Caption 
    $build = (Get-CimInstance -ClassName Win32_OperatingSystem).BuildNumber
    $datastring = "$caption $build | build=$build;"
   
    # Define parameters in a hashtable
    $notificationParams = @{
    returnstring = $datastring 
    ServiceName = "OS"
    status = "OK"}
 
  # Call the function with splatting
    Send-NagiosNotification @notificationParams
    Write-host @notificationParams
    Write-Host "Total function - seconds: $($stopwatch.Elapsed.TotalSeconds)" -foregroundcolor Blue
    $stopwatch.Stop()
}

function check-defenderasr{
    param (
        [string]$ServiceName = "ASR Rules",
        [int]$NagiosWarn = 10,
        [int]$NagiosCrit = 12
            )
        start-transcript -path ./log-$servicename.txt -append
        $stopwatch = [System.Diagnostics.Stopwatch]::StartNew()
        #command
        $asr = (Get-MPPreference | Select-Object -ExpandProperty AttackSurfaceReductionRules_Ids).Count
        $datastring = "$asr asr rules enabled | ASR_Rules=$asr;"

        # Nagios part
        $state = get-statege -NagiosCrit $NagiosCrit -NagiosWarn $NagiosWarn

        # Define parameters in a hashtable
        $notificationParams = @{
        returnstring = $datastring 
        ServiceName = $ServiceName
        status = $state['exitcodetxt']}
       
         # Call the function with splatting
        Send-NagiosNotification @notificationParams
        Write-host @notificationParams
        Write-Host "Total function - seconds: $($stopwatch.Elapsed.TotalSeconds)" -foregroundcolor Blue
        $stopwatch.Stop()
        Stop-transcript
}

function check-defender{
    param (
        [string]$ServiceName = "DEFENDER"
            )
    #Paolo Frigo, https://scriptinglibrary.com       
    $stopwatch = [System.Diagnostics.Stopwatch]::StartNew()
    start-transcript -path ./log-$servicename.txt -append
    $defender = $(Get-Service Windefend).Status -eq "Running" -and $(Get-MpComputerStatus).RealTimeProtectionEnabled

    $datastring = "OK: Running with Real Time protection"
    $exitcode = 0
    if ($defender -eq $False){
    $datastring = "CRITICAL: Microsoft Defender is not running or the real-time protection was disabled"
    $Exitcode = 2        
    }
    if ([bool] (Get-MpThreatDetection) -eq $True){
    $datastring = "CRITICAL: Microsoft Defender has detected some threats recently"
    $Exitcode = 2        
    }
    if ([bool]((Get-MpComputerStatus).AntivirusSignatureLastUpdated -lt (Get-date).AddDays(-7)) -eq $True) {
    $datastring= "CRITICAL: Microsoft Defender AV Definitions are older than a week"
    $Exitcode  = 2 
    }
  # Define parameters in a hashtable
   $status = Get-exitstatus -exitstatus $Exitcode

  $notificationParams = @{
  returnstring = $datastring 
  ServiceName = $ServiceName
  status = $status}
  # Call the function with splatting
  Send-NagiosNotification @notificationParams
  Write-host @notificationParams
  Write-Host "Total function - seconds: $($stopwatch.Elapsed.TotalSeconds)" -foregroundcolor Blue
  $stopwatch.Stop()
  # Exit with the appropriate status code
  Stop-transcript
}

function check-nic {
    param (
        [string]$ServiceName = "NIC",
        [int]$NagiosWarn = 75,
        [int]$NagiosCrit = 85,
        [string]$NicName = "realtek pcie 2.5gbe family controller",
        [int]$linkspeedmbps = "2500",
        [int]$sampleInterval = 2,
        [int]$totalSamples = 5
    )   
    start-transcript -path "./log-$ServiceName.txt" -append
    $stopwatch = [System.Diagnostics.Stopwatch]::StartNew()

    # Get the CounterSamples and filter for the specified network instance
    $counterSample = $null
    $counterSample = (Get-Counter -SampleInterval $sampleInterval -MaxSamples $totalSamples |
        Select-Object -ExpandProperty CounterSamples |
        Where-Object { $_.InstanceName -match $NicName })

    # Check if $counterSample is null, some network cards have special chars in names
    if (-not $counterSample) {
        $counterSample = (Get-Counter -SampleInterval $sampleInterval -MaxSamples $totalSamples |
            Select-Object -ExpandProperty CounterSamples |
            Where-Object { $_.InstanceName -eq $NicName })
    }

    if ($counterSample) {
        Write-Debug "CounterSample Count: $($counterSample.Count)"
        $counterSample | ForEach-Object {
            Write-Debug "Instance Name: $($_.InstanceName)"
            Write-Debug "Cooked Value: $($_.CookedValue)"
            Write-Debug "Timestamp: $($_.Timestamp)"
        }

        # Process cooked values
        $cookedValueMbps = $counterSample | ForEach-Object {
            ($_ | Select-Object -ExpandProperty CookedValue) * 8 / 1e6
        }

        # Ensure $cookedValueMbps is not empty before proceeding
        if ($cookedValueMbps) {
            # Get maximum cooked value
            $maxCookedValueMbps = ($cookedValueMbps | Measure-Object -Maximum).Maximum

            # Calculate percent utilization
            $percent = [math]::Round(($maxCookedValueMbps / $linkspeedmbps) * 100, 0)
            $state = Get-Statege -value $percent -NagiosCrit $NagiosCrit -NagiosWarn $NagiosWarn

            Write-Debug "Cooked Values (Mbps): $cookedValueMbps"
            Write-Debug "Max Cooked Value (Mbps): $maxCookedValueMbps"
            Write-Debug "Percent Utilization: $percent"

            $datastring = "$percent% used. $([math]::Round($maxCookedValueMbps, 0)) Mbps | percent=$percent;mbps=$([math]::Round($maxCookedValueMbps, 0))"
        } else {
            Write-Debug "No valid cooked values found."
            $datastring = "No valid cooked values found."
            $state = Get-Statege -value 0 -NagiosCrit $NagiosCrit -NagiosWarn $NagiosWarn
        }
    } else {
        Write-Debug "No matching network instance found."
        $datastring = "No matching network instance found."
        $state = Get-Statege -value 0 -NagiosCrit $NagiosCrit -NagiosWarn $NagiosWarn
    }

    # Define parameters in a hashtable
    $notificationParams = @{
        returnstring = "$($state['returnstring']) $datastring"
        ServiceName = $ServiceName
        status = $state['exitcodetxt']
    }

    # Call the function with splatting
    Send-NagiosNotification @notificationParams
    Write-host $notificationParams
    $stopwatch.Stop()
    Write-Host "Total function time in seconds: $($stopwatch.Elapsed.TotalSeconds)" -ForegroundColor Blue
    Stop-Transcript
}



function check-service {
        param (
        [string]$ServiceName = "SERVICE: SPOOLER"
            )
    $stopwatch = [System.Diagnostics.Stopwatch]::StartNew()
    $WindowServiceName = $ServiceName.Replace("SERVICE: ", "")        
    start-transcript -path ./log-$WindowServiceName.txt -append            
    $check = Get-Service $WindowServiceName 
    if($check.status -match "Running"){
        $status = "OK"
        $perfdata = 1
    }else
    {$status = "CRITICAL"
    $perfdata = 0}
   
    # Define parameters in a hashtable
    $notificationParams = @{
    returnstring = "$status`: $($check.DisplayName) is $($check.status) - $($check.ServiceName)  | running=$perfdata"
    ServiceName = $ServiceName
    status = $status}
 
  # Call the function with splatting
    Send-NagiosNotification @notificationParams
    Write-host @notificationParams
    $stopwatch.Stop()
    Write-Host "Total function - seconds: $($stopwatch.Elapsed.TotalSeconds)" -foregroundcolor Blue
    stop-transcript
}

FUNCTION check-process {
    param (
        [string]$ServiceName = "PROCCES: EXPLORER",
        [int]$NagiosWarn = 75,
        [int]$NagiosCrit = 85
    )
    $stopwatch = [System.Diagnostics.Stopwatch]::StartNew()
    $WindowProccessName = $ServiceName.Replace("PROCCES: ", "")

    start-transcript -path "./log-$WindowProccessName.txt" -append

    # Get the current time
    $currentTime = Get-Date

    # Get all processes running on the system
    $processes = [System.Diagnostics.Process]::GetProcesses()

    # Initialize variables to store output and perfdata
    $output = @()

    # Iterate through all processes and find the specified process
    foreach ($process in $processes) {
        if ($process.ProcessName -eq $WindowProccessName) {
            # Calculate the time difference in hours and round to 1 decimal place
            $timeDifference = $currentTime - $process.StartTime
            if ($timeDifference.TotalHours -ge 0) {
                $hoursRunning = [Math]::Round($timeDifference.TotalHours, 1)
            }
            else {
                $hoursRunning = 0  # Set to 0 if negative value encountered
            }
            # Build the message and status
            $message = "OK: $WindowProccessName is running with PID $($process.Id). Running for: $hoursRunning hours"
            $status = "OK"
            # Add the calculated hours to the output
            $output += [PSCustomObject]@{
                Message   = $message
                PerfData  = "$($process.Id)=$hoursRunning"
            }
        }
    }

    # If no instances were found, set appropriate output
    if (-not $output) {
        $status = "CRITICAL"
        $dataString = "CRITICAL: $WindowProccessName not found" 

    
    }else{
    $dataString = ""
    $perfString = ""
    
    # Iterate through each entry in $output and concatenate the Message and PerfData properties
    foreach ($entry in $output) {
        $dataString += $entry.Message + " "
        $perfString += $entry.PerfData + " "
    }

    # Output the concatenated data string and perfdata together
    $datastring = "$dataString | $perfString"
    }

    

    # Define parameters in a hashtable for notification
    $notificationParams = @{
        returnstring = $dataString
        ServiceName = $ServiceName
        status = $status
    }

    # Call the function with splatting
    Send-NagiosNotification @notificationParams
    Write-Host "Total function - seconds: $($stopwatch.Elapsed.TotalSeconds)" -foregroundcolor Blue
    $stopwatch.Stop()
    Stop-Transcript
}


function check-windowsupdates {
    param (
        [string]$ServiceName = "Windows Update",
        [int]$NagiosWarn = 2,
        [int]$NagiosCrit = 4
            )
    
    $stopwatch = [System.Diagnostics.Stopwatch]::StartNew()

    # Create Update Session
    $updateSession = New-Object -ComObject Microsoft.Update.Session
    $updateSession.ClientApplicationID = "Nagios Check Script"

    # Create Update Searcher
    $updateSearcher = $updateSession.CreateUpdateSearcher()
    #Write-Output "Searching for updates..."

    # Search for updates
    $searchResult = $updateSearcher.Search("IsInstalled=0 and Type='Software' and IsHidden=0")
    
    # Initialize status and message
    $status = "OK"
    $updatesFound = $searchResult.Updates.Count
    $returnString = ""

    if ($updatesFound -eq 0) {
        $returnString = "No updates available | updates=$updatesFound;"
    } else {
        $status = "CRITICAL" # Status if updates are found
        $updateTitles = @()
        for ($i = 0; $i -lt $updatesFound; $i++) {
            $update = $searchResult.Updates.Item($i)
            $updateTitles += $update.Title
        }
        $returnString = "Updates available $($updatesFound): $($updateTitles -join ', ') | updates=$updatesFound;"
    }

    # Call the Nagios notification function
    Send-NagiosNotification -returnstring $returnString -ServiceName $ServiceName -status $status
    Write-host "-returnstring $returnString -ServiceName $ServiceName -status $status"
    Write-Host "Total function runtime - seconds: $($stopwatch.Elapsed.TotalSeconds)" -ForegroundColor Blue
    $stopwatch.Stop()
}

function Check-WindowsDefender {
    param (
        [string]$ServiceName = "DEFENDER STATUS",
        [int]$NagiosWarn = 2,
        [int]$NagiosCrit = 4
            )
    # Start timing
    $stopwatch = [System.Diagnostics.Stopwatch]::StartNew()

    # Get Windows Defender Status
    try {
        $defenderStatus = Get-MpComputerStatus
    } catch {
        Write-Error "Unable to retrieve Windows Defender status. Ensure the system has Windows Defender installed and enabled."
        return
    }

    # Extract relevant details
    $definitionVersion = $defenderStatus.AntivirusSignatureVersion
    $lastQuickScanTime = $defenderStatus.QuickScanEndTime
    $QuickScanAge = $defenderStatus.QuickScanAge
    $FullScanAge = $defenderStatus.FullScanAge
    $lastFullScanTime = $defenderStatus.FullScanEndTime 
    $realTimeProtection = $defenderStatus.RealTimeProtectionEnabled 
    $lastUpdateStatus = $defenderStatus.AntivirusSignatureLastUpdated
    $AntivirusSignatureAge = $defenderStatus.AntivirusSignatureAge
    $AntispywareEnabled = $defenderStatus.AntispywareEnabled 
    $antispywareSignatureAge = $defenderStatus.AntispywareSignatureAge
    
    Write-Debug "$lastFullScanTime  $lastQuickScanTime"

    # Logic to check Windows Defender status
    if (-not $lastQuickScanTime -or -not $lastFullScanTime) {
        $status = "CRITICAL"
        $output = "No Quick or Full Scan has been performed on this machine. | AntivirusSignatureAge=$AntivirusSignatureAge; AntiSpywareSignatureAge=$antispywareSignatureAge;"
    } elseif ($QuickScanAge -gt 30) {
        $status = "WARNING"
        $output = "Quick scan is outdated (Last run: $lastQuickScanTime). | AntivirusSignatureAge=$AntivirusSignatureAge; AntiSpywareSignatureAge=$antispywareSignatureAge;"
    } elseif ($FullScanAge -gt 180) {
        $status = "WARNING"
        $output = "Full scan is outdated (Last run: $lastFullScanTime). | AntivirusSignatureAge=$AntivirusSignatureAge; AntiSpywareSignatureAge=$antispywareSignatureAge;"
    } elseif ($AntivirusSignatureAge -gt 2 -or $antispywareSignatureAge -gt $NagiosWarn) {
        $status = "WARNING"
        $output = "Antivirus or antispyware signatures are outdated. Antivirus Age: $AntivirusSignatureAge Days, Antispyware Age: $antispywareSignatureAge Days | AntivirusSignatureAge=$AntivirusSignatureAge; AntiSpywareSignatureAge=$antispywareSignatureAge;"
    } elseif ($AntivirusSignatureAge -le 2 -and $antispywareSignatureAge -le $NagiosWarn) {
        $status = "OK"
        $output = "Windows Defender is running with up-to-date signatures. Quick Scan: $QuickScanAge Days Ago, Full Scan: $FullScanAge Days Ago | AntivirusSignatureAge=$AntivirusSignatureAge; AntiSpywareSignatureAge=$antispywareSignatureAge;"
    } else {
        $status = "UNKNOWN"
        $output = "Unable to determine Windows Defender status. | AntivirusSignatureAge=$AntivirusSignatureAge; AntiSpywareSignatureAge=$antispywareSignatureAge;"
    }

    # Send to Nagios
    Send-NagiosNotification -returnstring $output -ServiceName $ServiceName -status $status

    # Output timing information for debugging
    Write-Host "Function execution time: $($stopwatch.Elapsed.TotalSeconds) seconds" -ForegroundColor Blue
    $stopwatch.Stop()
}


##############################
#
#
#       Scritp function 
#
#
##############################

function Format-TimeSpan {
    process {
      "{0:00} Days {1:00} Hours {2:00} Minutes" -f $_.Days,$_.Hours,$_.Minutes
    }
  }

function Get-exitstatus {
    param (
        [int]$exitstatus
    )

    switch ($exitstatus) {
        0 { return "OK" }
        1 { return "WARNING" }
        2 { return "CRITICAL" }
        default { return "UNKNOWN" }
    }
}

function get-statege {
    param (
        [double]$value,
        [int]$NagiosCrit,
        [int]$NagiosWarn
    )

    $returnStateOK = 0
    $returnStateWarning = 1
    $returnStateCritical = 2
    $returnStateUnknown = 3

    $exitcode = $returnStateUnknown
    $returnstring = "UNKNOW"
    $exitcodetxt = "UNKNOW"
 
    if ($value -ge $NagiosCrit) {
        $returnstring = "CRITICAL: "
        $exitcode = $returnStateCritical
    } elseif ($value -ge $NagiosWarn) {
        $returnstring = "WARNING: "
        $exitcode = $returnStateWarning
    } else {
        $returnstring = "OK: "
        $exitcode = $returnStateOK
    }

    $exitcodetxt = switch ($exitcode) {
        0 { "OK" }
        1 { "WARNING" }
        2 { "CRITICAL" }
        default { "UNKNOWN" }
    }

    Write-Debug "VALUE $value"
    Write-Debug "CRIT $NagiosCrit" 
    Write-Debug "Warning $NagiosWarn"
    Write-Debug "FUNCTION EXITCODE $exitcode"
    Write-Debug "FUNCTION exitcodetxt $exitcodetxt"
    Write-Debug "FUNCTION returnstring $returnstring"

    return @{
        "exitcode" = $exitcode
        "exitcodetxt" = $exitcodetxt
        "returnstring" = $returnstring
    }
}

function get-statele {
    param (
        [int]$value,
        [int]$NagiosCrit,
        [int]$NagiosWarn
    )

    $returnStateOK = 0
    $returnStateWarning = 1
    $returnStateCritical = 2
    $returnStateUnknown = 3

    $exitcode = $returnStateUnknown
    $returnstring = "UNKNOWN"

    if ($value -le $NagiosCrit) {
        $returnstring = "CRITICAL: "
        $exitcode = $returnStateCritical
    } elseif ($value -le $NagiosWarn) {
        $returnstring = "WARNING: "
        $exitcode = $returnStateWarning
    } else {
        $returnstring = "OK: "
        $exitcode = $returnStateOK
    }
    
    $exitcodetxt = switch ($exitcode) {
        0 { "OK" }
        1 { "WARNING" }
        2 { "CRITICAL" }
        default { "UNKNOWN" }
    }

    Write-Debug "VALUE $value"
    Write-Debug "CRIT $NagiosCrit" 
    Write-Debug "Warning $NagiosWarn"
    Write-Debug "FUNCTION EXITCODE $exitcode"
    Write-Debug "FUNCTION exitcodetxt $exitcodetxt"
    Write-Debug "FUNCTION returnstring $returnstring"

    return @{
        "exitcode" = $exitcode
        "exitcodetxt" = $exitcodetxt
        "returnstring" = $returnstring
    }
}


function Send-NagiosNotificationold {
    param (
        [string]$returnstring,
        [string]$perfdata,
        [string]$ServiceName,
        [string]$status
    )

    # Format the output for Nagios
    $statusmsg = "$output | $perfdata"
    #$nrdppath = "C:\scripts\git\nscp-checks\ps_nrdp.ps1"

    # Call the NRDP script with the provided parameters
    & $nrdppath -url $NagiosServerUrl -token $Token -hostname $Hostname -state $status -service $ServiceName -output $returnstring

    # For testing/debugging purposes, output the command that would be executed
    Write-Host "-url $NagiosServerUrl -token $Token -hostname $Hostname -state $status -service $ServiceName -output $returnstring" -foregroundcolor Green
}

function Send-NagiosNotification {
    param (
        [string]$returnstring,
        [string]$ServiceName,
        [string]$status
    )

    # Define the parameters as a hashtable
    $nrdpParams = @{
        url      = $NagiosServerUrl
        token    = $Token
        hostname = $Hostname
        state    = $status
        service  = $ServiceName
        output   = $returnstring
    }

    # Call the NRDP script with the provided parameters using splatting
    & $nrdppath @nrdpParams

    # For testing/debugging purposes, output the command that would be executed
    foreach ($key in $nrdpParams.Keys) {
    Write-Debug "$key = $($nrdpParams[$key])"
}
}
#the script!
#start-transcript -path "C:\shitshow.log" -append

$stopwatch1.Stop()
Write-Host "Total script in seconds: $($stopwatch1.Elapsed.TotalSeconds)" -foregroundcolor Blue

#stop-transcript
