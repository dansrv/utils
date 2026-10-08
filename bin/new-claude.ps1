# PowerShell shim: runs new-claude.sh under Git for Windows bash.
$bash = & (Join-Path $PSScriptRoot '_gitbash.ps1')
if (-not $bash) { exit 1 }
& $bash (Join-Path $PSScriptRoot '..\new-claude.sh') @args
exit $LASTEXITCODE
