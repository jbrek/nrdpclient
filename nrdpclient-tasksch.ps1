$global:nrdppath = "C:\scripts\tasksch\nrdpclient-beta.ps1"

$stopwatch1 = [System.Diagnostics.Stopwatch]::StartNew()

# Dot-source the to load function
. $nrdppath 


# Start jobs to run the functions

$cpuJob = Start-Job -ScriptBlock { 
# Dot-source load function
. "C:\scripts\tasksch\nrdpclient-beta.ps1"
Check-CPU -totalsamples 4 -sampleInterval 4 
}


$nicJob = Start-Job -ScriptBlock { 
# load function
. "C:\scripts\tasksch\nrdpclient-beta.ps1"
# Call the Check-NIC function
# RUn Get-Counter to get NIC NAME.
Check-Nic -NicName "realtek pcie 2.5gbe family controller" -LinkSpeedMbps 2500 
}

# Collect the jobs into an array
$jobs = @($cpuJob, $nicJob)

#lets run the other function
check-service -servicename "SERVICE: W32Time"
check-service 
check-process -servicename "PROCCES: JAVA"
check-process -servicename "PROCCES: KVIRC"
check-process
Check-Firewall
Check-MEM
Check-DriveSpace 
check-uptime
check-defenderasr -ServiceName "ASR"
check-osverison
check-defender

# Wait for all jobs to complete
foreach ($job in $jobs) {
    while ($job.State -eq 'Running') {
        Start-Sleep -Seconds 2
        Write-host "Waiting for Jobs To finish"
    }
}

# Retrieve and output the results
Write-Output "*******************************************"
$cpuResult = Receive-Job -Job $cpuJob
$nicResult = Receive-Job -Job $nicJob
Write-Output "CPU JOB" 
Write-Output $cpuResult
Write-Output "NIC JOB"
Write-Output $nicResult
Write-Output "*******************************************"

# Clean up jobs
Remove-Job -Job $cpuJob
Remove-Job -Job $nicJob


$stopwatch1.Stop()
Write-Host "TaskSch in seconds: $($stopwatch1.Elapsed.TotalSeconds)" -ForegroundColor Blue

