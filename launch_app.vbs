' My Elysia AI silent launcher
' Runs start_app.bat with a fully hidden console window (style 0).
' Used by the desktop shortcut; autostart uses its own copy of the same trick.
Set sh = CreateObject("WScript.Shell")
Set fso = CreateObject("Scripting.FileSystemObject")
bat = fso.GetParentFolderName(WScript.ScriptFullName) & "\start_app.bat"
sh.Run """" & bat & """", 0, False
