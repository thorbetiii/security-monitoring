$ErrorActionPreference = "Stop"

# Resolve repository and log directories.
$RepoRoot = Split-Path -Parent $PSScriptRoot
$LogDirectory = Join-Path $RepoRoot ".port-forward-logs"

New-Item -ItemType Directory -Path $LogDirectory -Force | Out-Null

# Only user-facing interfaces need port forwarding.
$PortForwards = @(
    [PSCustomObject]@{
        Name      = "Frontend"
        Namespace = "application"
        Resource  = "svc/frontend"
        Ports     = "8080:80"
        URL       = "http://localhost:8080"
    },
    [PSCustomObject]@{
        Name      = "Grafana"
        Namespace = "monitoring"
        Resource  = "svc/monitoring-grafana"
        Ports     = "3000:80"
        URL       = "http://localhost:3000"
    },
    [PSCustomObject]@{
        Name      = "Prometheus"
        Namespace = "monitoring"
        Resource  = "svc/monitoring-kube-prometheus-prometheus"
        Ports     = "9090:9090"
        URL       = "http://localhost:9090"
    },
    [PSCustomObject]@{
        Name      = "OpenSearch Dashboards"
        Namespace = "monitoring"
        Resource  = "svc/opensearch-dashboards"
        Ports     = "5601:5601"
        URL       = "http://localhost:5601"
    },
    [PSCustomObject]@{
        Name      = "OpenSearch API"
        Namespace = "monitoring"
        Resource  = "svc/opensearch-cluster-single"
        Ports     = "9200:9200"
        URL       = "http://localhost:9200"
    },
    [PSCustomObject]@{
        Name      = "Alertmanager"
        Namespace = "monitoring"
        Resource  = "svc/monitoring-kube-prometheus-alertmanager"
        Ports     = "9093:9093"
        URL       = "http://localhost:9093"
    }
)

$RunningProcesses = @()

function Stop-AllPortForwards {
    Write-Host ""
    Write-Host "Stopping all port-forward processes..." -ForegroundColor Yellow

    foreach ($Entry in $RunningProcesses) {
        $Process = $Entry.Process

        try {
            $Process.Refresh()

            if (-not $Process.HasExited) {
                Stop-Process -Id $Process.Id -Force -ErrorAction SilentlyContinue
                Write-Host "Stopped: $($Entry.Name)"
            }
        }
        catch {
            # Process may already have stopped.
        }
    }

    Write-Host "All port forwards stopped." -ForegroundColor Green
}

try {
    Write-Host "Checking kubectl..." -ForegroundColor Cyan

    if (-not (Get-Command kubectl -ErrorAction SilentlyContinue)) {
        throw "kubectl was not found in PATH."
    }

    kubectl cluster-info *> $null

    if ($LASTEXITCODE -ne 0) {
        throw "The Kubernetes cluster is not reachable."
    }

    Write-Host "Kubernetes cluster is reachable." -ForegroundColor Green
    Write-Host ""
    Write-Host "Checking Kubernetes Services..." -ForegroundColor Cyan

    foreach ($Forward in $PortForwards) {
        kubectl get $Forward.Resource `
            -n $Forward.Namespace `
            --ignore-not-found=true `
            -o name *> $null

        if ($LASTEXITCODE -ne 0) {
            throw "Unable to check $($Forward.Resource) in namespace $($Forward.Namespace)."
        }

        $ResourceResult = kubectl get $Forward.Resource `
            -n $Forward.Namespace `
            --ignore-not-found=true `
            -o name

        if ([string]::IsNullOrWhiteSpace($ResourceResult)) {
            throw "Resource '$($Forward.Resource)' does not exist in namespace '$($Forward.Namespace)'."
        }

        Write-Host "Found: $($Forward.Namespace)/$($Forward.Resource)"
    }

    Write-Host ""
    Write-Host "Starting port forwards..." -ForegroundColor Cyan

    foreach ($Forward in $PortForwards) {
        $SafeName = $Forward.Name `
            -replace " ", "-" `
            -replace "[^A-Za-z0-9\-]", ""

        $StandardOutput = Join-Path $LogDirectory "$SafeName-output.log"
        $StandardError = Join-Path $LogDirectory "$SafeName-error.log"

        # Clear old log contents.
        Set-Content -Path $StandardOutput -Value ""
        Set-Content -Path $StandardError -Value ""

        $Arguments = @(
            "port-forward",
            "-n", $Forward.Namespace,
            $Forward.Resource,
            $Forward.Ports,
            "--address=127.0.0.1"
        )

        $Process = Start-Process `
            -FilePath "kubectl" `
            -ArgumentList $Arguments `
            -PassThru `
            -NoNewWindow `
            -RedirectStandardOutput $StandardOutput `
            -RedirectStandardError $StandardError

        $RunningProcesses += [PSCustomObject]@{
            Name       = $Forward.Name
            URL        = $Forward.URL
            Process    = $Process
            ErrorLog   = $StandardError
            OutputLog  = $StandardOutput
        }

        Write-Host ("Started: {0,-24} PID: {1}" -f $Forward.Name, $Process.Id)
    }

    # Give kubectl time to bind the local ports.
    Start-Sleep -Seconds 4

    Write-Host ""
    Write-Host "Validating port-forward processes..." -ForegroundColor Cyan

    foreach ($Entry in $RunningProcesses) {
        $Entry.Process.Refresh()

        if ($Entry.Process.HasExited) {
            Write-Host ""
            Write-Host "$($Entry.Name) failed to start." -ForegroundColor Red
            Write-Host "Error log: $($Entry.ErrorLog)" -ForegroundColor Yellow

            if (Test-Path $Entry.ErrorLog) {
                Get-Content $Entry.ErrorLog
            }

            throw "A port-forward process failed."
        }
    }

    Write-Host ""
    Write-Host "Security Monitoring system is accessible:" -ForegroundColor Green
    Write-Host ""

    foreach ($Entry in $RunningProcesses) {
        Write-Host ("  {0,-24} {1}" -f $Entry.Name, $Entry.URL)
    }

    Write-Host ""
    Write-Host "Port-forward logs:" -ForegroundColor Cyan
    Write-Host "  $LogDirectory"
    Write-Host ""
    Write-Host "Keep this terminal open." -ForegroundColor Yellow
    Write-Host "Press Ctrl+C to stop every port forward." -ForegroundColor Yellow
    Write-Host ""

    while ($true) {
        Start-Sleep -Seconds 3

        foreach ($Entry in $RunningProcesses) {
            $Entry.Process.Refresh()

            if ($Entry.Process.HasExited) {
                Write-Host ""
                Write-Host "$($Entry.Name) unexpectedly stopped." -ForegroundColor Red
                Write-Host "Inspect: $($Entry.ErrorLog)" -ForegroundColor Yellow
                throw "Port-forward process stopped unexpectedly."
            }
        }
    }
}
catch {
    Write-Host ""
    Write-Host "ERROR: $($_.Exception.Message)" -ForegroundColor Red
}
finally {
    Stop-AllPortForwards
}