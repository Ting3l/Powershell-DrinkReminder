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

The configuration can be done manually via config.txt.
I recommend using the context menu to configure options.
Only debug mode (=don't hide PS-window) must be turned on manually.
