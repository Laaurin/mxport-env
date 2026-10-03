# ==============================================================================
# cluster-down.ps1
# Windows PowerShell Script to delete k3d cluster 'dataspace'
# ==============================================================================
$ClusterName = "dataspace"

Write-Host ">>> Deleting k3d cluster '$ClusterName'..." -ForegroundColor Yellow
$existing = k3d cluster list $ClusterName --no-headers 2>$null
if ($existing) {
    k3d cluster delete $ClusterName
    Write-Host ">>> Cluster '$ClusterName' successfully deleted." -ForegroundColor Green
} else {
    Write-Host ">>> Cluster '$ClusterName' does not exist." -ForegroundColor Gray
}
