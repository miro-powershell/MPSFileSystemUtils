Import-Module -Name MPSFileSystemUtils

New-Item -Path C:\Watcher -ItemType Directory -Force | Out-Null

$jobs = Start-FileSystemWatcher -Path C:\Watcher -Filter "*.txt"
1..10 | ForEach-Object {New-Item -Path "C:\Watcher\new$_.txt" -ItemType File -ErrorAction SilentlyContinue} | Out-Null
1..10 | ForEach-Object {Add-Content -Path "C:\Watcher\new$_.txt" -Value "Just something" -ErrorAction SilentlyContinue}  | Out-Null
2..5 | ForEach-Object {Remove-Item -Path "C:\Watcher\new$_.txt" -ErrorAction SilentlyContinue} | Out-Null
1..10 | ForEach-Object {Rename-Item -Path "C:\Watcher\new$_.txt" -NewName "C:\Watcher\new$($_ * 10).txt" -ErrorAction SilentlyContinue} | Out-Null
Get-ChildItem C:\Watcher | Remove-Item -Force -ErrorAction SilentlyContinue | Out-Null
$Result = Stop-FileSystemWatcher


$Result | Sort-Object -Property Time

Remove-Item -Path C:\Watcher -Recurse -Force -ErrorAction SilentlyContinue | Out-Null 
