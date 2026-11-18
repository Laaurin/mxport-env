# ==============================================================================
# verify_4actor_chain.ps1
# Redirects to the current 6-Actor Dataspace verification script
# ==============================================================================
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
& (Join-Path $ScriptDir "verify_6actor_chain.ps1")
