# Powershell-DrinkReminder
Reminds you to drink by playing a sound (custom) and showing a notification after a set time.


Installation:

- Copy all files locally into a directory from where your user-account can run scripts
- Supply the following files: (I can't supply them here due to copyright)
    
    warn.mp3 - The first sound played. A soft warning.
    
    crit.mp3 - After ignoring the reminder a few times it will play the "critical" sound.
    
    icon.ico OR icon.exe - The icon for showing in the taskbar.
- Click on DrinkReminder.cmd to start

OR
- Set up a scheduled task with the follwing parameters:
    
    Trigger: At logon of user
    
    Action: 
    
      Command: C:\Windows\System32\cmd.exe
      
      Arguments: /c start cmd /k "C:\path\to\DrinkReminder.cmd"
      
      WorkingDirectory: C:\path\to\

Configuration:

The configuration is done via config.txt.
The following options are available:

- Timespan - Time to warn after the last drink/startup in minutes. Default: 30
- Repeatwarning - Time until an ignored warning will be repeated in minutes. Default: 10
- Criticalthreshold - How often the normal warning will be played, before the "critial"-sound is played. Default: 2
- WarnVolume - Volume of warning-file (in percent) to compensate for differently balanced soundfiles. Default: 100
- CritVolume - Volume of critical-file (in percent) to compensate for differently balanced soundfiles. Default: 100
- Debug - Turn on/off debug-mode. Debug mode will not hide the Powershell-Window. Default: 0
