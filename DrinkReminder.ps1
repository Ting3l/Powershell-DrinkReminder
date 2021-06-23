# Drink Reminder by Ting3l
$Version = "1.6"
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

    if (!(Test-Path $filepath)){
        New-Item $filepath -ItemType File -Value $configdefault -Force | Out-Null
        Write-Host Created default config file
    }

    $config = Get-Content -Path $filepath | ConvertFrom-Json # Get Config-File
 
    $global:DrinkTimespan = $config.timespan
    $global:RepeatWarning = $config.repeatwarning
    $global:CriticalThreshold = $config.criticalthreshold
    $global:WarnVolume = (($config.warnvolume) / 100)
    $global:CritVolume = (($config.critvolume) / 100)
    $global:debug = [bool]$config.debug

    if ($global:lang -ne $config.lang){
        $global:lang = $config.lang

        if ($Global:lang -like "de"){
            $Global:drinktext = "Getrunken!"
            $Global:conftext = "Einstellungen.."
            $Global:autostarttext = "Mit Windows starten"
            $Global:helptext = "Hilfe.."
            $Global:abouttext = "Über.."
            $Global:exittext = "Beenden"
            $Global:balloontiptext = "Letztes mal getrunken: "
            $Global:warntext = "Seek fluid intake"
            $Global:crittext = "Seek fluid intake immediately!"
        }
        else { #default to english
            $Global:drinktext = "Drank!"
            $Global:conftext = "Options.."
            $Global:autostarttext = "Start with Windows"
            $Global:helptext = "Help.."
            $Global:abouttext = "About.."
            $Global:exittext = "Exit"
            $Global:balloontiptext = "Last drink: "
            $Global:warntext = "Seek fluid intake"
            $Global:crittext = "Seek fluid intake immediately!"
        }

        $timestamp.Text = $Timer
        $drink.Text = $drinktext
        $conf.Text = $conftext
        $autostart.Text = $autostarttext
        $help.Text = $helptext
        $about.Text = $abouttext
        $exit.Text = $exittext
    }

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
$configfilepath = "$BasePath\config.txt"

$Warning = "$BasePath\warn.mp3" # "Warning"-sound (first one played)
$Critical = "$BasePath\crit.mp3" # "Critical"-sound (played after some warnings)

$mediaPlayer = New-Object system.windows.media.mediaplayer

# Icon for Taskbar
$iconfile = Get-ChildItem "$BasePath\icon.*"
if ($iconfile.Count -gt 1){$iconfile = $iconfile[0]}
if ($iconfile.Name.EndsWith(".ico")){$Icon = "$($iconfile.FullName)"}
elseif ($iconfile.Name.EndsWith(".exe")){$Icon = [System.Drawing.Icon]::ExtractAssociatedIcon("$($iconfile.FullName)")}

$Timer = Get-Date
$LastWarn = $Timer
$WarnCount = 0
#endregion

#region Templates default files
$configdefault = @"
{
"version":"$Version",
"lang":"en",
"timespan":30,
"repeatwarning":5,
"criticalthreshold":4,
"warnvolume":100,
"critvolume":100,
"debug":1
}
"@

$cmddefault = '%systemroot%\System32\WindowsPowerShell\v1.0\powershell.exe -executionpolicy bypass -file "DrinkReminder.ps1"'

$readme = @"
PowerShell Drink Reminder by @Ting3l - 2021
https://github.com/Ting3l/Powershell-DrinkReminder

See online ReadMe: https://github.com/Ting3l/Powershell-DrinkReminder/blob/main/README.md
"@

$xml = @"
<?xml version="1.0" encoding="UTF-16"?>
<Task version="1.2" xmlns="http://schemas.microsoft.com/windows/2004/02/mit/task">
  <RegistrationInfo><Author>Ting3l</Author></RegistrationInfo>
  <Triggers><LogonTrigger>
      <Enabled>true</Enabled>
      <UserId>$env:USERDOMAIN\$env:USERNAME</UserId>
  </LogonTrigger></Triggers>
  <Principals><Principal id="Author">
      <UserId>$env:USERDOMAIN\$env:USERNAME</UserId>
      <LogonType>InteractiveToken</LogonType>
  </Principal></Principals>
  <Settings>
    <DisallowStartIfOnBatteries>false</DisallowStartIfOnBatteries>
    <StopIfGoingOnBatteries>false</StopIfGoingOnBatteries>
    <AllowHardTerminate>false</AllowHardTerminate>
  </Settings>
  <Actions Context="Author"><Exec>
      <Command>C:\Windows\System32\cmd.exe</Command>
      <Arguments>/c "$BasePath\DrinkReminder.cmd"</Arguments>
      <WorkingDirectory>$BasePath\</WorkingDirectory>
  </Exec></Actions>
</Task>
"@
#endregion

#region Check default files
if (!(Test-Path "$BasePath\DrinkReminder.cmd")){
    New-Item "$BasePath\DrinkReminder.cmd" -ItemType File -Value $cmddefault -Force | Out-Null
    Write-Host Created default .cmd-startfile
}
if (!(Test-Path "$BasePath\_ReadMe.txt")){
    New-Item "$BasePath\_ReadMe.txt" -ItemType File -Value $readme -Force | Out-Null
    Write-Host Created ReadMe.txt
}
if (Get-ScheduledTask -TaskPath \ -TaskName "Start Drinkreminder" -ErrorAction SilentlyContinue){
    $autostartenabled = $true
}
else{
    $autostartenabled = $false
}
#endregion

#region GUI
$Main_Tool_Icon = New-Object System.Windows.Forms.NotifyIcon
$Main_Tool_Icon.Text = "Fluid Intake"
$Main_Tool_Icon.Icon = $Icon
$Main_Tool_Icon.Visible = $true

$drink = New-Object System.Windows.Forms.MenuItem
$drink.Text = $drinktext
$drink.Add_Click({ 
    $global:Timer = Get-Date
    $global:LastWarn = $Timer
    $timestamp.Text = $Timer
    $global:WarnCount = 0
    $myTimer.Stop()
    Start-Sleep -Milliseconds 100
    $myTimer.Start()
    Write-Host Timer reset 
})

$timestamp = New-Object System.Windows.Forms.MenuItem
$timestamp.Text = $Timer
$timestamp.Enabled = $false

$s1 = New-Object System.Windows.Forms.MenuItem
$s1.text = "-"

$conf = New-Object System.Windows.Forms.MenuItem
$conf.Text = $conftext
$conf.Add_Click({ 
    notepad.exe $BasePath\config.txt
})

$autostart = New-Object System.Windows.Forms.MenuItem
$autostart.Text = $autostarttext
$autostart.Add_Click({ 
    if ($autostartenabled){
        Get-ScheduledTask -TaskPath \ -TaskName "Start Drinkreminder" -ErrorAction SilentlyContinue | Unregister-ScheduledTask -Confirm:$false
        Write-host Removed scheduled task
    }
    else{
        New-Item $BasePath\task.xml -ItemType File -Value $xml -Force | out-null
        SCHTASKS /Create /TN "Start Drinkreminder" /XML "$($BasePath)\task.xml"
        Remove-Item $BasePath\task.xml -Force
        Write-Host Added scheduled task
    }
    $global:autostartenabled = !($autostartenabled)
    $global:autostart.Checked = $autostartenabled
})
$autostart.Checked = $autostartenabled

$help = New-Object System.Windows.Forms.MenuItem
$help.Text = $helptext
$help.Add_Click({ 
    notepad.exe $BasePath\ReadMe.txt
})

$about = New-Object System.Windows.Forms.MenuItem
$about.Text = $abouttext
$about.Add_Click({ 
    $popup = New-Object -ComObject Wscript.Shell
    $popup.Popup("PowerShell Drink Reminder by @Ting3l - 2021`nhttps://github.com/Ting3l/Powershell-DrinkReminder",0,"Über..",64) | Out-Null
})

$s2 = New-Object System.Windows.Forms.MenuItem
$s2.text = "-"

$exit = New-Object System.Windows.Forms.MenuItem
$exit.Text = $exittext
$exit.add_Click({
    $myTimer.Enabled = $false
    $Main_Tool_Icon.Visible = $false
    Stop-Process $pid
})

$contextmenu = New-Object System.Windows.Forms.ContextMenu
$contextmenu.MenuItems.Add($drink) | Out-Null
$contextmenu.MenuItems.Add($timestamp) | Out-Null
$contextmenu.MenuItems.Add($s1) | Out-Null
$contextmenu.MenuItems.Add($conf) | Out-Null
$contextmenu.MenuItems.Add($autostart) | Out-Null
$contextmenu.MenuItems.Add($help) | Out-Null
$contextmenu.MenuItems.Add($about) | Out-Null
$contextmenu.MenuItems.Add($s2) | Out-Null
$contextmenu.MenuItems.Add($exit) | Out-Null
$Main_Tool_Icon.ContextMenu = $contextmenu
$Main_Tool_Icon.add_MouseDown({$Main_Tool_Icon.GetType().GetMethod("ShowContextMenu",[System.Reflection.BindingFlags]::Instance -bor [System.Reflection.BindingFlags]::NonPublic).Invoke($Main_Tool_Icon,$null)})
#endregion

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
            $text = $balloontiptext+"$($td.Hours)h, $($td.Minutes)m"
            
            if ($WarnCount -lt $CriticalThreshold){
                Write-Host "Playing warning (previous warn count: $WarnCount)"
                $Main_Tool_Icon.ShowBalloonTip(7000, $warntext, $text, 'None')
                Play $Warning $WarnVolume
            }
            else{
                Write-Host "Playing critical warning (warn count: $WarnCount)"
                $Main_Tool_Icon.ShowBalloonTip(7000, $crittext, $text, 'None')
                Play $Critical $CritVolume
            }
            
            $global:LastWarn = Get-Date
            $global:WarnCount++
        }
    }
})

Refresh-Config $configfilepath
if ($HideWindow){Hide-Window}
[System.GC]::Collect() # Use a Garbage colector to reduce RAM-usage. See: https://dmitrysotnikov.wordpress.com/2012/02/24/freeing-up-memory-in-powershell-using-garbage-collector/
$myTimer.Start()
$appContext = New-Object System.Windows.Forms.ApplicationContext
[void][System.Windows.Forms.Application]::Run($appContext)

# TODO
# Add option to customize title of the balloonTips 
# Add option to turn off balloontips
# Add option to turn off sound
# Add error-handling for mandatory files missing (warn.mp3, crit.mp3, icon.ico/.exe)
# Add drinking-history-log
# Add general error-handling
# Comment out!
# Add "Install"-parameter to only create config and .cmd-file fast. (And later also ReadMe.txt)
# Maybe create own sounds and Icon, so those can be supplied via GitHub?
