# Windows installer: add this clone's bin\ to the user PATH so showgit, new-claude
# and resume-claude work in PowerShell, cmd and Git Bash. Re-running is harmless.
# Needs Git for Windows; the scripts run under its bash.exe.
$bin  = Join-Path $PSScriptRoot 'bin'
$user = [Environment]::GetEnvironmentVariable('Path', 'User')
$parts = @($user -split ';' | Where-Object { $_ })

if ($parts -contains $bin) {
  Write-Host "already on user PATH: $bin"
} else {
  [Environment]::SetEnvironmentVariable('Path', (($parts + $bin) -join ';'), 'User')
  Write-Host "added to user PATH: $bin"
  Write-Host "open a new terminal to pick it up"
}

$bash = & (Join-Path $bin '_gitbash.ps1')
if ($bash) { Write-Host "using Git Bash: $bash" }

if ((Get-ExecutionPolicy -Scope CurrentUser) -eq 'Restricted') {
  Write-Warning "PowerShell execution policy is Restricted; the .ps1 shims will not run. Fix with:`n  Set-ExecutionPolicy -Scope CurrentUser RemoteSigned"
}
