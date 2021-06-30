# Drink Reminder by @Ting3l - 2021
# https://github.com/Ting3l/Powershell-DrinkReminder

Param(
    [Parameter(Mandatory=$false)]
    [switch]$run
)

$Version = "1.8"

#region imports & variables
$BasePath = Split-Path $MyInvocation.MyCommand.Path # Get Basepath
$configfilepath = "$BasePath\config.txt"
$logfilepath = "$BasePath\Logs\"
$drinklogfilepath = "$logfilepath\drinking.log"

Add-Type -AssemblyName presentationCore
[System.Reflection.Assembly]::LoadWithPartialName('System.Windows.Forms') | out-null
[System.Reflection.Assembly]::LoadWithPartialName('presentationframework') | out-null
[System.Reflection.Assembly]::LoadWithPartialName('System.Drawing') | out-null
[System.Reflection.Assembly]::LoadWithPartialName('WindowsFormsIntegration') | out-null
[Reflection.Assembly]::LoadWithPartialName('Microsoft.VisualBasic') | out-null

$mediaPlayer = New-Object system.windows.media.mediaplayer

$windowcode = '[DllImport("user32.dll")] public static extern bool ShowWindowAsync(IntPtr hWnd, int nCmdShow);'
$asyncwindow = Add-Type -MemberDefinition $windowcode -name Win32ShowWindowAsync -namespace Win32Functions -PassThru
$handle = (Get-Process -PID $pid).MainWindowHandle

$WarnFile = "warn.mp3"
$CritFile = "crit.mp3"
$Global:Warning = "$BasePath\$WarnFile" # "Warning"-sound (first one played)
$Global:Critical = "$BasePath\$CritFile" # "Critical"-sound (played after some warnings)

$LastWarn = $Timer = Get-Date
$WarnCount = 0
$disabled = $false
#endregion

#region CustomFunctions
function Refresh-Config ($filepath){
    Write-Host Refreshing configuration:

    if (!(Test-Path $filepath)){
        New-Item $filepath -ItemType File -Value $configdefault -Force | Out-Null
        Write-Host Created config.txt
    }

    $config = Get-Content -Path $filepath | ConvertFrom-Json # Get Config-File
 
    $global:DrinkTimespan = $config.timespan
    $global:RepeatWarning = $config.repeatwarning
    $global:CriticalThreshold = $config.criticalthreshold

    $global:PlaySound = [bool]($config.sound.playsound)
    $global:WarnVolume = (($config.sound.warnvolume) / 100)
    $global:CritVolume = (($config.sound.critvolume) / 100)

    $global:ShowNotification = [bool]$config.notifications.shownotifications
    $global:warntext = $config.notifications.warntext
    $global:crittext = $config.notifications.crittext

    $global:debug = [bool]$config.debug

    if ($global:lang -ne $config.lang){
        $global:lang = $config.lang

        if ($Global:lang -like "de"){
            $conf_lang_de.Checked = $true
            $conf_lang_en.Checked = $false

            $Global:drinktext = "Getrunken!"
            $Global:conftext = "Einstellungen.."
            $Global:conf_timespantext = "Zeitspanne"
            $Global:conf_timespan_popup_title = "Zeitspanne"
            $Global:conf_timespan_popup_message = "Neue Zeitspanne eingeben:"
            $Global:conf_repeattimespantext = "Wiederholungs-Zeitspanne"
            $Global:conf_repeattimespan_popup_title = "Wiederholungs-Zeitspanne"
            $Global:conf_repeattimespan_popup_message = "Neue Zeitspanne für Wiederholungen eingeben:"
            $Global:conf_criticalthresholdtext = "Kritischer Schwellwert"
            $Global:conf_criticalthreshold_popup_title = "Kritischer Schwellwert"
            $Global:conf_criticalthreshold_popup_message = "Neuen Schwellwert eingeben, ab dem Warnungen kritisch werden:"
            $global:conf_soundtext = "Ton"
            $Global:conf_sound_enabledtext = "Ton abspielen"
            $Global:conf_sound_warnvoltext = "Lautstärke (Warnung)"
            $Global:conf_sound_warnvol_popup_message = "Lautstärke für den 'Warnung'-Ton (0-100):"
            $Global:conf_sound_warnvol_popup_title = "Warnung-Lautstärke"
            $Global:conf_sound_critvoltext = "Lautstärke (Kritisch)"
            $Global:conf_sound_warnvol_popup_message = "Lautstärke für den 'Kritisch'-Ton (0-100):"
            $Global:conf_sound_warnvol_popup_title = "Kritisch-Lautstärke"
            $Global:conf_notiftext = "Benachrichtigungen"
            $Global:conf_notif_enabledtext = "Zeige Benachrichtigungen"
            $Global:conf_notif_warntexttext = "Warntext"
            $Global:conf_notif_warntext_popup_message = "Neuen Text eingeben, der bei Warnungs-Benachrichtigungen gezeigt wird:"
            $Global:conf_notif_warntext_popup_title = "Warnungs-Text"
            $Global:conf_notif_crittexttext = "Krittext"
            $Global:conf_notif_crittext_popup_message = "Neuen Text eingeben, der bei Kritisch-Benachrichtigungen gezeigt wird:"
            $Global:conf_notif_crittext_popup_title = "Kritisch-Text"
            $Global:conf_langtext = "Sprache.."
            $global:conf_lang_detext = "Deutsch"
            $Global:conf_lang_entext = "Englisch"
            $Global:autostarttext = "Mit Windows starten"
            $Global:disabletext = "Pausieren"
            $Global:disable_hourtext = "..für eine Stunde"
            $Global:disable_todaytext = "..für heute"
            $Global:helptext = "Hilfe.."
            $Global:abouttext = "Über.."
            $Global:exittext = "Beenden"
            $Global:balloontiptext = "Letztes mal getrunken: "
        }
        else { #default to english
            $conf_lang_en.Checked = $true
            $conf_lang_de.Checked = $false
            
            $Global:drinktext = "Drank!"
            $Global:conftext = "Options.."
            $Global:conf_timespantext = "Timespan.."
            $Global:conf_timespan_popup_title = "Timespan"
            $Global:conf_timespan_popup_message = "Enter new timespan:"
            $Global:conf_repeattimespantext = "Repeat-timespan"
            $Global:conf_repeattimespan_popup_title = "Repeat-timespan"
            $Global:conf_repeattimespan_popup_message = "Enter new timespan for repetition:"
            $Global:conf_criticalthresholdtext = "Critical threshold"
            $Global:conf_criticalthreshold_popup_title = "Critical threshold"
            $Global:conf_criticalthreshold_popup_message = "Enter new threshold after which warnings get critical:"
            $global:conf_soundtext = "Sound"
            $Global:conf_sound_enabledtext = "Play sound"
            $Global:conf_sound_warnvoltext = "Volume (Warning)"
            $Global:conf_sound_warnvol_popup_message = "Volume for warning-sound (0-100):"
            $Global:conf_sound_warnvol_popup_title = "warn volume"
            $Global:conf_sound_critvoltext = "Volume (Critical)"
            $Global:conf_sound_warnvol_popup_message = "Volume for critical-sound (0-100):"
            $Global:conf_sound_warnvol_popup_title = "critical volume"
            $Global:conf_notiftext = "Notifications"
            $Global:conf_notif_enabledtext = "Show notifications"
            $Global:conf_notif_warntexttext = "Warntext"
            $Global:conf_notif_warntext_popup_message = "Enter new text to show in warning-notifications:"
            $Global:conf_notif_warntext_popup_title = "Warning-text"
            $Global:conf_notif_crittexttext = "Crittext"
            $Global:conf_notif_crittext_popup_message = "Enter new text to show in critical-notifications:"
            $Global:conf_notif_crittext_popup_title = "Critical-text"
            $Global:conf_langtext = "Language.."
            $global:conf_lang_detext = "German"
            $Global:conf_lang_entext = "English"
            $Global:autostarttext = "Start with Windows"
            $Global:disabletext = "Disable"
            $Global:disable_hourtext = "..for an hour"
            $Global:disable_todaytext = "..for today"
            $Global:helptext = "Help.."
            $Global:abouttext = "About.."
            $Global:exittext = "Exit"
            $Global:balloontiptext = "Last drink: "
        }

        $Global:drink.Text = $drinktext
        $Global:conf.Text = $conftext
        $Global:conf_sound.Text = $conf_soundtext
        $Global:conf_sound_enabled.Text = $conf_sound_enabledtext
        $Global:conf_notif.text = $conf_notiftext
        $Global:conf_notif_enabled.text = $conf_notif_enabledtext
        $Global:conf_notif_warntext.text = $conf_notif_warntexttext
        $Global:conf_notif_crittext.text = $conf_notif_crittexttext
        $Global:conf_lang.Text = $conf_langtext
        $Global:conf_lang_de.Text = $conf_lang_detext
        $Global:conf_lang_en.Text = $conf_lang_entext
        $Global:autostart.Text = $autostarttext
        $Global:disable.Text = $disabletext
        $Global:disable_hour.Text = $disable_hourtext
        $Global:disable_today.Text = $disable_todaytext
        $Global:help.Text = $helptext
        $Global:about.Text = $abouttext
        $Global:exit.Text = $exittext
    }

    $Global:timestamp.Text = $global:Timer
    $Global:conf_timespan.Text = "$conf_timespantext [$($drinktimespan)m]"
    $Global:conf_repeattimespan.Text = "$conf_repeattimespantext [$($repeatwarning)m]"
    $Global:conf_criticalthreshold.Text = "$conf_criticalthresholdtext [$($global:CriticalThreshold)]"
    $Global:conf_sound_enabled.Checked = $Global:PlaySound
    $Global:conf_sound_warnvol.Text = "$conf_sound_warnvoltext [$($global:warnvolume * 100)]"
    $Global:conf_sound_critvol.Text = "$conf_sound_critvoltext [$($global:critvolume * 100)]"
    $Global:conf_notif_enabled.Checked = $global:ShowNotification

    # Icon for Taskbar
    $iconfile = Get-ChildItem "$BasePath\icon.*"
    if ($iconfile.Count -gt 1){$iconfile = $iconfile[0]}
    if ($iconfile.Name.EndsWith(".ico")){$Icon = "$($iconfile.FullName)"}
    elseif ($iconfile.Name.EndsWith(".exe")){$Icon = [System.Drawing.Icon]::ExtractAssociatedIcon("$($iconfile.FullName)")}
    $Global:Main_Tool_Icon.Icon = $Icon

    $global:HideWindow = $true
    if ($global:debug){$global:HideWindow = $false}
    if ($HideWindow){Hide-Window}
    else{Show-Window}
    
    $global:LastConfigChange = (Get-Item $filepath).LastWriteTime

    Write-Host ""
    Write-host "version           : $($config.version)"
    Write-host "lang              : $($config.lang)"
    Write-host "timespan          : $($config.timespan)"
    Write-host "repeatwarning     : $($config.repeatwarning)"
    Write-host "criticalthreshold : $($config.criticalthreshold)"
    Write-host "sound             : {"
    Write-Host "                      playsound  : $($config.sound.playsound); "
    Write-Host "                      warnvolume : $($config.sound.warnvolume); "
    Write-Host "                      critvolume : $($config.sound.critvolume)"
    Write-Host "                     }"
    Write-host "notifications     : {"
    Write-Host "                      shownotifications : $($config.notifications.shownotifications); "
    Write-Host "                      warntext          : $($config.notifications.warntext); "
    Write-Host "                      crittext          : $($config.notifications.crittext)"
    Write-Host "                     }"
    Write-host "debug             : 1"
    Write-host ""
}
function Set-Config($filepath, $timespan, $repeattimespan, $criticalthreshold, $playsound, $warnvol, $critvol, $shownotif, $warntext, $crittext, $lang){
    $config = Get-Content -Path $filepath | ConvertFrom-Json # Get Config-File

    if ($timespan){$config.timespan = [int]$timespan}
    if ($repeattimespan){$config.repeatwarning = [int]$repeattimespan}
    if ($criticalthreshold){$config.criticalthreshold = [int]$criticalthreshold}
    if ($playsound){$config.sound.playsound = [int]$playsound}
    if ($warnvol){$config.sound.warnvolume = [int]$warnvol}
    if ($critvol){$config.sound.critvolume = [int]$critvol}
    if ($shownotif){$config.notifications.shownotifications = [int]$shownotif}
    if ($warntext){$config.notifications.warntext = $warntext}
    if ($crittext){$config.notifications.crittext = $crittext}
    if ($lang){$config.lang = $lang}

    $config | ConvertTo-Json | Set-Content -Path $filepath
    Write-Host Updated config!
    Refresh-Config $filepath
}
function Play ($Path, $Volume){
    $global:mediaPlayer.open($Path)
    do{Start-Sleep -Milliseconds 10}while(!($mediaPlayer.NaturalDuration.HasTimeSpan))
    $sleeptime = ([int]$global:mediaPlayer.NaturalDuration.TimeSpan.TotalMilliseconds) + 200
    $global:mediaPlayer.Volume = $Volume
    $global:mediaPlayer.Play()
    Start-Sleep -Milliseconds $sleeptime
    $global:mediaPlayer.Close()
}
function Get-TimeDifference($t, [switch]$verbose){
    $ct = Get-Date
    $td = ($ct - $t)
    if ($verbose){Write-Host "$(([String]$ct.TimeOfDay).Split(".")[0]) - $(([String]$t.TimeOfDay).Split(".")[0]) = $td"}
    return $td
}
function Hide-Window(){$null = $asyncwindow::ShowWindowAsync($handle, 0)}
function Show-Window(){$null = $asyncwindow::ShowWindowAsync($handle, 1)}
#endregion

#region Templates default files
$configdefault = @"
{
"version":"$Version",
"lang":"en",
"timespan":30,
"repeatwarning":5,
"criticalthreshold":4,
"sound":{
	"playsound":1,
	"warnvolume":100,
	"critvolume":100
},
"notifications":{
	"shownotifications":1,
	"warntext":"Seek fluid intake",
	"crittext":"Seek fluid intake immediately!"
},
"debug":0
}
"@

$cmddefault = '%systemroot%\System32\WindowsPowerShell\v1.0\powershell.exe -executionpolicy bypass -file "DrinkReminder.ps1" -run'

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
if (!(Test-Path "$Global:Warning")){
    $popup = New-Object -ComObject Wscript.Shell
    $popup.Popup("The file 'warn.mp3' is missing in the root directory $BasePath",0,"warn.mp3 missing!",48) | Out-Null
    Exit
}
if (!(Test-Path "$Global:Critical")){
    $popup = New-Object -ComObject Wscript.Shell
    $popup.Popup("The file 'crit.mp3' is missing in the root directory $BasePath",0,"crit.mp3 missing!",48) | Out-Null
    Exit
}
if (!((Test-Path "$BasePath\icon.ico") -or (Test-Path "$BasePath\icon.exe"))){
    $popup = New-Object -ComObject Wscript.Shell
    $popup.Popup("The file 'icon.ico' (alternative 'icon.exe') is missing in the root directory $BasePath",0,"icon missing!",48) | Out-Null
    Exit
}
if (!(Test-Path "$BasePath\DrinkReminder.cmd")){
    New-Item "$BasePath\DrinkReminder.cmd" -ItemType File -Value $cmddefault -Force | Out-Null
    Write-Host Created DrinkReminder.cmd
}
if (!(Test-Path "$BasePath\_ReadMe.txt")){
    New-Item "$BasePath\_ReadMe.txt" -ItemType File -Value $readme -Force | Out-Null
    Write-Host Created _ReadMe.txt
}
if (!(Test-Path "$logfilepath")){
    New-Item "$logfilepath" -ItemType Directory -Force | out-Null
    Write-Host Created Log-directory
}
if (Get-ScheduledTask -TaskPath \ -TaskName "Start Drinkreminder" -ErrorAction SilentlyContinue){
    $autostartenabled = $true
    Write-Host Autostart is: Enabled
}
else{
    $autostartenabled = $false
    Write-Host Autostart is: Disabled
}
#endregion

#region GUI
$Main_Tool_Icon = New-Object System.Windows.Forms.NotifyIcon
$Main_Tool_Icon.Text = "Fluid Intake"
$Main_Tool_Icon.Visible = $true
$contextmenu = New-Object System.Windows.Forms.ContextMenu
$Main_Tool_Icon.ContextMenu = $contextmenu
$Main_Tool_Icon.add_MouseDown({$Main_Tool_Icon.GetType().GetMethod("ShowContextMenu",[System.Reflection.BindingFlags]::Instance -bor [System.Reflection.BindingFlags]::NonPublic).Invoke($Main_Tool_Icon,$null)})

$drink = New-Object System.Windows.Forms.MenuItem
$drink.Add_Click({ 
    $global:Timer = $global:LastWarn = Get-Date
    $timestamp.Text = $global:Timer
    $global:WarnCount = 0
    $myTimer.Stop()
    Start-Sleep -Milliseconds 100
    $myTimer.Start()
    Write-Host Timer reset 
})
$contextmenu.MenuItems.Add($drink) | Out-Null

$timestamp = New-Object System.Windows.Forms.MenuItem
$timestamp.Enabled = $false
$contextmenu.MenuItems.Add($timestamp) | Out-Null

$s1 = New-Object System.Windows.Forms.MenuItem
$s1.text = "-"
$contextmenu.MenuItems.Add($s1) | Out-Null

$conf = New-Object System.Windows.Forms.MenuItem
$contextmenu.MenuItems.Add($conf) | Out-Null

$conf_timespan = New-Object System.Windows.Forms.MenuItem
$conf_timespan.Add_Click({
    do{$new = [Microsoft.VisualBasic.Interaction]::InputBox($conf_timespan_popup_message, $conf_timespan_popup_title, [string]$global:DrinkTimespan)}while(!(($new -match "^\d+$") -or $new -like ""))
    if ($new -match "^\d+$"){Set-Config -filepath $configfilepath -timespan $new}
})
$conf.MenuItems.Add($conf_timespan) | Out-Null

$conf_repeattimespan = New-Object System.Windows.Forms.MenuItem
$conf_repeattimespan.Add_Click({
    do{$new = [Microsoft.VisualBasic.Interaction]::InputBox($conf_repeattimespan_popup_message, $conf_repeattimespan_popup_title, [string]$global:Repeatwarning)}while(!(($new -match "^\d+$") -or $new -like ""))
    if ($new -match "^\d+$"){Set-Config -filepath $configfilepath -repeattimespan $new}
})
$conf.MenuItems.Add($conf_repeattimespan) | Out-Null

$conf_criticalthreshold = New-Object System.Windows.Forms.MenuItem
$conf_criticalthreshold.Add_Click({
    do{$new = [Microsoft.VisualBasic.Interaction]::InputBox($conf_criticalthreshold_popup_message, $conf_criticalthreshold_popup_title, [string]$global:CriticalThreshold)}while(!(($new -match "^\d+$") -or $new -like ""))
    if ($new -match "^\d+$"){Set-Config -filepath $configfilepath -criticalthreshold $new}
})
$conf.MenuItems.Add($conf_criticalthreshold) | Out-Null

$conf_sound = New-Object System.Windows.Forms.MenuItem
$conf.MenuItems.Add($conf_sound) | Out-Null

$conf_sound_enabled = New-Object System.Windows.Forms.MenuItem
$conf_sound_enabled.Add_Click({
    if($Global:playsound){Set-Config -filepath $configfilepath -playsound "0"}
    else{Set-Config -filepath $configfilepath -playsound "1"}
})
$conf_sound.MenuItems.Add($conf_sound_enabled) | Out-Null

$conf_sound_warnvol = New-Object System.Windows.Forms.MenuItem
$conf_sound_warnvol.Add_Click({
    do{$new = [Microsoft.VisualBasic.Interaction]::InputBox($conf_sound_warnvol_popup_message, $conf_sound_warnvol_popup_title, [string]($global:WarnVolume * 100))}while(!(($new -match "^\d+$" -and [int]$new -ge 0 -and [int]$new -le 100) -or $new -like ""))
    if ($new -match "^\d+$" -and [int]$new -ge 0 -and [int]$new -le 100){Set-Config -filepath $configfilepath -warnvol $new}
})
$conf_sound.MenuItems.Add($conf_sound_warnvol) | Out-Null

$conf_sound_critvol = New-Object System.Windows.Forms.MenuItem
$conf_sound_critvol.Add_Click({
    do{$new = [Microsoft.VisualBasic.Interaction]::InputBox($conf_sound_critvol_popup_message, $conf_sound_critvol_popup_title, [string]($global:CritVolume * 100))}while(!(($new -match "^\d+$" -and [int]$new -ge 0 -and [int]$new -le 100) -or $new -like ""))
    if ($new -match "^\d+$" -and [int]$new -ge 0 -and [int]$new -le 100){Set-Config -filepath $configfilepath -critvol $new}
})
$conf_sound.MenuItems.Add($conf_sound_critvol) | Out-Null

$conf_notif = New-Object System.Windows.Forms.MenuItem
$conf.MenuItems.Add($conf_notif) | Out-Null

$conf_notif_enabled = New-Object System.Windows.Forms.MenuItem
$conf_notif_enabled.Add_Click({
    if($Global:ShowNotification){Set-Config -filepath $configfilepath -shownotif "0"}
    else{Set-Config -filepath $configfilepath -shownotif "1"}
})
$conf_notif.MenuItems.Add($conf_notif_enabled) | Out-Null

$conf_notif_warntext = New-Object System.Windows.Forms.MenuItem
$conf_notif_warntext.Add_Click({
    $new = [Microsoft.VisualBasic.Interaction]::InputBox($conf_notif_warntext_popup_message, $conf_notif_warntext_popup_title, $global:WarnText)
    if (!($new.trim() -like "" -or $new.Trim() -eq $global:warnText)){Set-Config -filepath $configfilepath -warntext $new.Trim()}
})
$conf_notif.MenuItems.Add($conf_notif_warntext) | Out-Null

$conf_notif_crittext = New-Object System.Windows.Forms.MenuItem
$conf_notif_crittext.Add_Click({
    $new = [Microsoft.VisualBasic.Interaction]::InputBox($conf_notif_crittext_popup_message, $conf_notif_crittext_popup_title, $global:critText)
    if (!($new.trim() -like "" -or $new.Trim() -eq $global:critText)){Set-Config -filepath $configfilepath -crittext $new.Trim()}
})
$conf_notif.MenuItems.Add($conf_notif_crittext) | Out-Null

$conf_lang = New-Object System.Windows.Forms.MenuItem
$conf.MenuItems.Add($conf_lang) | Out-Null

$conf_lang_de = New-Object System.Windows.Forms.MenuItem
$conf_lang_de.Add_Click({if ($Global:lang -notlike "de"){Set-Config -filepath $configfilepath -lang "de"}})
$conf_lang.MenuItems.Add($conf_lang_de) | Out-Null

$conf_lang_en = New-Object System.Windows.Forms.MenuItem
$conf_lang_en.Add_Click({if ($Global:lang -notlike "en"){Set-Config -filepath $configfilepath -lang "en"}})
$conf_lang.MenuItems.Add($conf_lang_en) | Out-Null

$autostart = New-Object System.Windows.Forms.MenuItem
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
$contextmenu.MenuItems.Add($autostart) | Out-Null

$disable = New-Object System.Windows.Forms.MenuItem
$contextmenu.MenuItems.Add($disable) | Out-Null

$disable_hour = New-Object System.Windows.Forms.MenuItem
$disable_hour.add_Click({
    if ($global:disabled -and $global:disable_hour.Checked){
        Write-Host Timer resumed
        $global:disabled = $false
        $global:Timer = $global:LastWarn = Get-Date
        $global:WarnCount = 0
        $myTimer.Start()
    }
    else{
        Write-Host Timer paused, will resume in one hour
        if ($global:disabled){
            $global:disable_today.Checked = $false
        }
        else{
            $myTimer.Stop()
            $global:disabled = $true
        }
        $global:Timer = Get-Date
        $global:pauseTimer = new-object System.Windows.Forms.Timer
        $pauseTimer.Interval = 300000
        $pauseTimer.add_tick({
            Write-Host "Pause time: " -NoNewline
            $td = Get-TimeDifference -t $Timer -verbose
    
            if ($td.TotalMinutes -ge 60){
                Write-Host Resuming timer after 60m
                $global:WarnCount = 0
                $global:disabled = $global:disable_hour.Checked = $false
                $pauseTimer.Stop()
                $global:myTimer.Start()
            }
        })
        $pauseTimer.Start()
    }
    $disable_hour.Checked = $global:disabled
})
$disable.MenuItems.Add($disable_hour) | Out-Null

$disable_today = New-Object System.Windows.Forms.MenuItem
$disable_today.add_Click({
    if ($global:disabled -and $disable_today.Checked){
        Write-Host Timer resumed
        $global:disabled = $false
        $global:Timer = $global:LastWarn = Get-Date
        $global:WarnCount = 0
        $global:myTimer.Start()
    }
    else{
        Write-host Timer paused
        if ($global:disabled){
            $global:disable_hour.Checked = $false
            $pauseTimer.Stop()
        }
        else{
            $global:disabled = $true
            $global:myTimer.Stop()
        }
    }
    $disable_today.Checked = $disabled
})
$disable.MenuItems.Add($disable_today) | Out-Null

$help = New-Object System.Windows.Forms.MenuItem
$help.Add_Click({ 
    notepad.exe $BasePath\_ReadMe.txt
})
$contextmenu.MenuItems.Add($help) | Out-Null

$about = New-Object System.Windows.Forms.MenuItem
$about.Add_Click({ 
    $popup = New-Object -ComObject Wscript.Shell
    $popup.Popup("PowerShell Drink Reminder by @Ting3l - 2021`nhttps://github.com/Ting3l/Powershell-DrinkReminder",0,"Über..",64) | Out-Null
})
$contextmenu.MenuItems.Add($about) | Out-Null

$s2 = New-Object System.Windows.Forms.MenuItem
$s2.text = "-"
$contextmenu.MenuItems.Add($s2) | Out-Null

$exit = New-Object System.Windows.Forms.MenuItem
$exit.add_Click({
    $myTimer.Enabled = $false
    $Main_Tool_Icon.Visible = $false
    Stop-Process $pid
})
$contextmenu.MenuItems.Add($exit) | Out-Null
#endregion

$myTimer = new-object System.Windows.Forms.Timer
$myTimer.Interval = 60000
$myTimer.add_tick({
    if ($global:LastConfigChange -ne (Get-Item -Path $configfilepath).LastWriteTime){Refresh-Config $configfilepath}
    
    Write-Host "Last drink: " -NoNewline
    $td = Get-TimeDifference -t $Timer -verbose
    
    if ($td.TotalMinutes -ge $DrinkTimespan){
        Write-host " Last warn: " -NoNewline
        $lw = Get-TimeDifference -t $LastWarn -verbose

        if ($lw.TotalMinutes -ge $RepeatWarning){            
            $text = $balloontiptext+"$($td.Hours)h, $($td.Minutes)m"
            
            if ($WarnCount -le $CriticalThreshold){
                Write-Host "Playing warning (warn count: $WarnCount)"
                if ($ShowNotification){$Main_Tool_Icon.ShowBalloonTip(7000, $warntext, $text, 'None')}
                if ($PlaySound){Play $Warning $WarnVolume}
            }
            else{
                Write-Host "Playing critical warning (warn count: $WarnCount)"
                if ($ShowNotification){$Main_Tool_Icon.ShowBalloonTip(7000, $crittext, $text, 'None')}
                if ($PlaySound){Play $Critical $CritVolume}
            }
            
            $global:LastWarn = Get-Date
            $global:WarnCount++
        }
    }
})

Refresh-Config $configfilepath
if ($run){
    [System.GC]::Collect() # Use a Garbage colector to reduce RAM-usage. See: https://dmitrysotnikov.wordpress.com/2012/02/24/freeing-up-memory-in-powershell-using-garbage-collector/
    $myTimer.Start()
    $appContext = New-Object System.Windows.Forms.ApplicationContext
    [void][System.Windows.Forms.Application]::Run($appContext)
}

# TODO
# Add drinking-history-log?
# Add programm log
# Add general error-handling
# Comment out!
# Maybe create own sounds and Icon, so those can be supplied via GitHub?
