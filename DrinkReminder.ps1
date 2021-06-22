# Drink Reminder by Ting3l
# Version 1.3
# Description:
<#
    Reminds you to drink by playing a sound (custom) and showing a notification after a set time.
#>

#region imports
Add-Type -AssemblyName presentationCore
[System.Reflection.Assembly]::LoadWithPartialName('System.Windows.Forms') | out-null
[System.Reflection.Assembly]::LoadWithPartialName('presentationframework') | out-null
[System.Reflection.Assembly]::LoadWithPartialName('System.Drawing') | out-null
[System.Reflection.Assembly]::LoadWithPartialName('WindowsFormsIntegration') | out-null
#endregion

#region CustomFunctions
function Refresh-Config ($filepath){
    Write-Host Refreshing configuration...

    $config = Get-Content -Path $filepath | ConvertFrom-Json # Get Config-File
    $global:DrinkTimespan = $config.timespan
    $global:RepeatWarning = $config.repeatwarning
    $global:CriticalThreshold = $config.criticalthreshold
    $global:WarnVolume = (($config.warnvolume) / 100)
    $global:CritVolume = (($config.critvolume) / 100)
    $global:debug = [bool]$config.debug

    $global:HideWindow = $true
    if ($global:debug){$global:HideWindow = $false}
    
    $global:LastConfigChange = (Get-Item $filepath).LastWriteTime

    Write-host $config
}
function Play ($Path, $Volume){
    $mediaPlayer.open($Path)
    $sleeptime = ([int]$mediaPlayer.NaturalDuration.TimeSpan.TotalMilliseconds) + 200
    $mediaPlayer.Volume = $Volume
    $mediaPlayer.Play()
    Start-Sleep -Milliseconds $sleeptime
    $mediaPlayer.Close()
}
function Hide-Window(){
    $windowcode = '[DllImport("user32.dll")] public static extern bool ShowWindowAsync(IntPtr hWnd, int nCmdShow);'
    $asyncwindow = Add-Type -MemberDefinition $windowcode -name Win32ShowWindowAsync -namespace Win32Functions -PassThru
    $null = $asyncwindow::ShowWindowAsync((Get-Process -PID $pid).MainWindowHandle, 0)
}
#endregion

#region VarDefinitions
$BasePath = Split-Path $MyInvocation.MyCommand.Path # Get Basepath

$Warning = "$BasePath\warn.mp3" # "Warning"-sound (first one played)
$Critical = "$BasePath\crit.mp3" # "Critical"-sound (played after some warnings)

$mediaPlayer = New-Object system.windows.media.mediaplayer

$configfilepath = "$BasePath\config.txt"

# Icon for Taskbar
$iconfile = Get-ChildItem "$BasePath\icon.*"
if ($iconfile.Count -gt 1){$iconfile = $iconfile[0]}
if ($iconfile.Name.EndsWith(".ico")){$Icon = "$($iconfile.FullName)"}
elseif ($iconfile.Name.EndsWith(".exe")){$Icon = [System.Drawing.Icon]::ExtractAssociatedIcon("$($iconfile.FullName)")}

$Timer = Get-Date
$LastWarn = $Timer
$WarnCount = 0
#endregion

#region GUI
$Main_Tool_Icon = New-Object System.Windows.Forms.NotifyIcon
$Main_Tool_Icon.Text = "Fluid Intake"
$Main_Tool_Icon.Icon = $Icon
$Main_Tool_Icon.Visible = $true

$timestamp = New-Object System.Windows.Forms.MenuItem
$timestamp.Text = $Timer

$drink = New-Object System.Windows.Forms.MenuItem
$drink.Text = "Getrunken!"
$drink.Add_Click({ 
    $Timer = Get-Date
    $LastWarn = $Timer
    $timestamp.Text = $Timer
    $WarnCount = 0
    $myTimer.Stop()
    Start-Sleep -Milliseconds 100
    $myTimer.Start()
    Write-Host Timer reset 
})

$exit = New-Object System.Windows.Forms.MenuItem
$exit.Text = "Beenden"
$exit.add_Click({
    $myTimer.Enabled = $false
    $Main_Tool_Icon.Visible = $false
    Stop-Process $pid
})

$contextmenu = New-Object System.Windows.Forms.ContextMenu
$contextmenu.MenuItems.Add($timestamp) | Out-Null
$contextmenu.MenuItems.Add($drink) | Out-Null
$contextmenu.MenuItems.Add($exit) | Out-Null
$Main_Tool_Icon.ContextMenu = $contextmenu
$Main_Tool_Icon.add_MouseDown({$Main_Tool_Icon.GetType().GetMethod("ShowContextMenu",[System.Reflection.BindingFlags]::Instance -bor [System.Reflection.BindingFlags]::NonPublic).Invoke($Main_Tool_Icon,$null)})

$myTimer = new-object System.Windows.Forms.Timer
$myTimer.Interval = 60000
$myTimer.add_tick({
    if ($global:LastConfigChange -ne (Get-Item -Path $configfilepath).LastWriteTime){Refresh-Config $configfilepath}
    
    $t = Get-Date
    $td = ($t - $Timer)
    Write-Host "Last drink: $(([String]$t.TimeOfDay).Split(".")[0]) - $(([String]$Timer.TimeOfDay).Split(".")[0]) = $td"
    
    if ($td.TotalMinutes -ge $DrinkTimespan){
        Write-host " Last warn: $(([String]$t.TimeOfDay).Split(".")[0]) - $(([String]$LastWarn.TimeOfDay).Split(".")[0]) = $($t - $LastWarn)"
        
        if (($t - $LastWarn).TotalMinutes -ge $RepeatWarning){
            $text = "Last drink $($td.Hours)h, $($td.Minutes)m ago"
            
            if ($WarnCount -lt $CriticalThreshold){
                Write-Host "Playing warning (previous warn count: $WarnCount)"
                $Main_Tool_Icon.ShowBalloonTip(7000, "Seek fluid intake.", $text, 'None')
                Play $Warning $WarnVolume
            }
            else{
                Write-Host "Playing critical warning (warn count: $WarnCount)"
                $Main_Tool_Icon.ShowBalloonTip(7000, "Seek fluid intake immediately!", $text, 'None')
                Play $Critical $CritVolume
            }
            
            $LastWarn = Get-Date
            $WarnCount++
        }
    }
})
#endregion

if ($HideWindow){Hide-Window}
[System.GC]::Collect() # Use a Garbage colector to reduce RAM-usage. See: https://dmitrysotnikov.wordpress.com/2012/02/24/freeing-up-memory-in-powershell-using-garbage-collector/
$myTimer.Start()
$appContext = New-Object System.Windows.Forms.ApplicationContext
[void][System.Windows.Forms.Application]::Run($appContext)
