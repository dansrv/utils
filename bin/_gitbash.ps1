# Prints the path to Git for Windows bash.exe, or writes an error and prints nothing.
# Order: per-user Git install, machine-wide Git install, then any bash.exe on PATH
# except the WSL launcher in System32 (that one runs Linux, not Git Bash).
$candidates = @(
  (Join-Path $env:LOCALAPPDATA 'Programs\Git\bin\bash.exe'),
  (Join-Path $env:ProgramFiles 'Git\bin\bash.exe')
)
$bash = $candidates | Where-Object { Test-Path $_ } | Select-Object -First 1
if (-not $bash) {
  $bash = Get-Command bash.exe -All -ErrorAction SilentlyContinue |
    ForEach-Object Source |
    Where-Object { $_ -notlike "$env:SystemRoot\System32\*" } |
    Select-Object -First 1
}
if (-not $bash) { Write-Error 'Git for Windows bash.exe not found. Install Git from https://git-scm.com'; return }
$bash
