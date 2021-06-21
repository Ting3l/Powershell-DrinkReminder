# Drink Reminder by Ting3l
# Version 1.0
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

#region VarDefinitions
$BasePath = Split-Path $MyInvocation.MyCommand.Path # Get Basepath

$Warning = "$BasePath\warn.mp3" # "Warning"-sound (first one played)
$Critical = "$BasePath\crit.mp3" # "Critical"-sound (played after some warnings)

$mediaPlayer = New-Object system.windows.media.mediaplayer

# Config
$config = Get-Content -Path "$BasePath\config.txt" | ConvertFrom-Json # Get Config-File
$DrinkTimespan = $config.timespan
$RepeatWarning = $config.repeatwarning
$CriticalThreshold = $config.criticalthreshold
$HideWindow = [bool]$config.hidewindow
$debug = [bool]$config.debug

if ($debug){
    $DrinkTimespan = 1
    $RepeatWarning = 1
    $CriticalThreshold = 2
    $HideWindow = $false
}

$global:Timer = Get-Date
$global:LastWarn = $global:Timer
$global:WarnCount = 0
#endregion

#region CustomFunctions
function Play ($Path, $Length, $Volume){
    $mediaPlayer.open($Path)
    $mediaPlayer.Volume = $Volume
    $mediaPlayer.Play()
    Start-Sleep -Milliseconds $Length
    $mediaPlayer.Close()
}
function Hide-Window(){
    $windowcode = '[DllImport("user32.dll")] public static extern bool ShowWindowAsync(IntPtr hWnd, int nCmdShow);'
    $asyncwindow = Add-Type -MemberDefinition $windowcode -name Win32ShowWindowAsync -namespace Win32Functions -PassThru
    $null = $asyncwindow::ShowWindowAsync((Get-Process -PID $pid).MainWindowHandle, 0)
}
#endregion

#region GUI
$Main_Tool_Icon = New-Object System.Windows.Forms.NotifyIcon
$Main_Tool_Icon.Text = "Fluid Intake"
$Main_Tool_Icon.Icon = "$BasePath\icon.ico"
$Main_Tool_Icon.Visible = $true

$timestamp = New-Object System.Windows.Forms.MenuItem
$timestamp.Text = $global:Timer

$drink = New-Object System.Windows.Forms.MenuItem
$drink.Text = "Getrunken!"
$drink.Add_Click({ 
    $global:Timer = Get-Date
    $global:LastWarn = $global:Timer
    $timestamp.Text = $global:Timer
    $global:WarnCount = 0
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
    $window.Close()
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
    $t = Get-Date
    $td = ($t - $global:Timer)
    Write-Host "(current time $t) - (timer time $global:Timer) = (time difference $td)"
    if ($td.Minutes -ge $DrinkTimespan){
        Write-host " (current time $t) - (last warn time $global:LastWarn) = (time difference $($t - $global:LastWarn))"
        if (($t - $global:LastWarn).Minutes -ge $RepeatWarning){
            $text = "Last drink $($td.Hours)h, $($td.Minutes)m ago"
            if ($global:WarnCount -lt $CriticalThreshold){
                Write-Host "Playing warning (previous warn count: $global:WarnCount)"
                $Main_Tool_Icon.ShowBalloonTip(7000, "Seek fluid intake.", $text, 'None')
                Play $Warning 2200 0.3
            }
            else{
                Write-Host "Playing critical warning (warn count: $global:WarnCount)"
                $Main_Tool_Icon.ShowBalloonTip(7000, "Seek fluid intake immediately!", $text, 'None')
                Play $Critical 3000 1
            }
            $global:LastWarn = Get-Date
            $global:WarnCount++
        }
    }
})
#endregion

if ($HideWindow){Hide-Window}
[System.GC]::Collect() # Use a Garbage colector to reduce RAM-usage. See: https://dmitrysotnikov.wordpress.com/2012/02/24/freeing-up-memory-in-powershell-using-garbage-collector/
$myTimer.Start()
$appContext = New-Object System.Windows.Forms.ApplicationContext
[void][System.Windows.Forms.Application]::Run($appContext)
