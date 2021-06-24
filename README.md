# Powershell-DrinkReminder
Reminds you to drink by playing a sound (custom) and showing a notification after a set time.


Installation:

- Copy DrinkReminder.ps1 locally into a directory from where your user-account can run scripts
- Supply the following files: (I can't supply them here due to copyright)
    
    warn.mp3 - The first sound played. A soft warning.
    
    crit.mp3 - After ignoring the reminder a few times it will play the "critical" sound.
    
    icon.ico OR icon.exe - The icon for showing in the taskbar.
- Right-click DrinkReminder.ps1 and run it with powershell. This will create the config file and a batch-file to start the program easily.


- Click on DrinkReminder.cmd to start

- Richt-click the taskbar-icon and select "Start with Windows" to create a scheduled task to start DrinkReminder at logon of your user.



Configuration:

The configuration is done via config.txt.
The following options are available:

- Version - Not an option, only a reference to the scipt-version which created the file. Unused.
- Lang - Defines which language is to be used. Possible values: en, de - Unknown values default to en. Default: en
- Timespan - Time to warn after the last drink/startup in minutes. Default: 30
- Repeatwarning - Time until an ignored warning will be repeated in minutes. Default: 10
- Criticalthreshold - How often the normal warning will be played, before the "critial"-sound is played. Default: 2
- PlaySound - If sound is played or not. Possible: 0,1 Default: 1
- WarnFile - Filename of the mp3 played with a warning. Default: warn.mp3
- WarnVolume - Volume of warning-file (in percent) to compensate for differently balanced soundfiles. Default: 100
- CritFile - Filename of the mp3 played with a critial warning. Default: warn.mp3
- CritVolume - Volume of critical-file (in percent) to compensate for differently balanced soundfiles. Default: 100
- ShowNotifications - If notifications are shown or not. Possible: 0,1 Default: 1
- WarnText - Title of the notification shown with a warning. Default: "Seek fluid intake"
- CritText - Title of the notification shown with a critial warning. Default: "Seek fluid intake immediately!"
- Debug - Turn on/off debug-mode. Debug mode will not hide the Powershell-Window. Default: 0
