param(
    [Parameter(Mandatory = $true)]
    [ValidateSet("01", "02", "03")]
    [string]$RunNumber
)

$ErrorActionPreference = "Stop"

# ============================================================
# Formal Checkout-Abuse Experiment
#
# Protocol:
#   10 minutes normal preconditioning (not measured)
#   10 minutes measured normal baseline
#    5 minutes checkout abuse
#   10 minutes measured recovery
#
# Normal checkout traffic runs continuously throughout all
# phases. Five abuse users are added only during the attack.
# ============================================================

function Write-Section {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Title
    )

    Write-Host ""
    Write-Host "============================================================"
    Write-Host $Title
    Write-Host "============================================================"
}

function Get-LocustProcesses {
    Get-CimInstance Win32_Process |
        Where-Object {
            $_.Name -match "^python(?:\.exe)?$" -and
            $_.CommandLine -match "(?i)\blocust\b"
        }
}

function Assert-NoExistingLocust {
    $Processes = @(Get-LocustProcesses)

    if ($Processes.Count -gt 0) {
        $Processes |
            Select-Object ProcessId, Name, CommandLine |
            Format-Table -AutoSize

        throw "Existing Locust process detected. Stop or verify it before starting."
    }
}

function Assert-ApplicationReady {
    $PodJson = kubectl get pods -n application -o json

    if ($LASTEXITCODE -ne 0) {
        throw "Unable to query application pods."
    }

    $Pods = $PodJson | ConvertFrom-Json

    if ($Pods.items.Count -ne 9) {
        throw "Expected 9 application pods, found $($Pods.items.Count)."
    }

    $Unhealthy = @()

    foreach ($Pod in $Pods.items) {
        $Ready = $true

        if (-not $Pod.status.containerStatuses) {
            $Ready = $false
        }
        else {
            foreach ($Container in $Pod.status.containerStatuses) {
                if (-not $Container.ready) {
                    $Ready = $false
                }
            }
        }

        if (
            $Pod.status.phase -ne "Running" -or
            -not $Ready
        ) {
            $Unhealthy += $Pod.metadata.name
        }
    }

    if ($Unhealthy.Count -gt 0) {
        throw "Application pods are not ready: $($Unhealthy -join ', ')"
    }
}

function Save-PodEvidence {
    param(
        [Parameter(Mandatory = $true)]
        [string]$RunDirectory,

        [Parameter(Mandatory = $true)]
        [ValidateSet("before", "after")]
        [string]$Stage
    )

    kubectl get pods -n application -o wide |
        Set-Content (
            Join-Path $RunDirectory "application-pods-$Stage.txt"
        )

    kubectl get pods -n application `
        -o custom-columns="POD:.metadata.name,READY:.status.containerStatuses[*].ready,RESTARTS:.status.containerStatuses[*].restartCount" |
        Set-Content (
            Join-Path $RunDirectory "application-restarts-$Stage.txt"
        )
}

function Resolve-ProcessExitCode {
    param(
        [Parameter(Mandatory = $true)]
        [System.Diagnostics.Process]$Process,

        [Parameter(Mandatory = $true)]
        [string]$StdErrFile
    )

    # Windows PowerShell 5.1 can occasionally expose a blank ExitCode
    # immediately after a timed WaitForExit() call when output is redirected.
    # Wait once more, refresh the object, and then read the property.
    try {
        $Process.WaitForExit()
        $Process.Refresh()

        if ($Process.HasExited) {
            $ExitCode = $Process.ExitCode

            if ($null -ne $ExitCode) {
                return [int]$ExitCode
            }
        }
    }
    catch {
        # Fall through to the Locust stderr fallback below.
    }

    # Locust writes its final process exit code to stderr. Use that line as
    # a reliable fallback if Windows PowerShell did not populate ExitCode.
    if (Test-Path $StdErrFile) {
        $ExitLine = Get-Content $StdErrFile -Tail 100 |
            Select-String -Pattern 'Shutting down \(exit code\s+(-?\d+)\)' |
            Select-Object -Last 1

        if ($ExitLine) {
            return [int]$ExitLine.Matches[0].Groups[1].Value
        }
    }

    return $null
}

function Assert-ProcessRunning {
    param(
        [Parameter(Mandatory = $true)]
        [System.Diagnostics.Process]$Process,

        [Parameter(Mandatory = $true)]
        [string]$Stage,

        [Parameter(Mandatory = $true)]
        [string]$StdOutFile,

        [Parameter(Mandatory = $true)]
        [string]$StdErrFile
    )

    $Process.Refresh()

    if ($Process.HasExited) {
        $ExitCode = Resolve-ProcessExitCode `
            -Process $Process `
            -StdErrFile $StdErrFile

        $StdOutTail = if (Test-Path $StdOutFile) {
            Get-Content $StdOutFile -Tail 40
        }
        else {
            @("No stdout file was created.")
        }

        $StdErrTail = if (Test-Path $StdErrFile) {
            Get-Content $StdErrFile -Tail 40
        }
        else {
            @("No stderr file was created.")
        }

        $ExitCodeText = if ($null -eq $ExitCode) {
            "unknown"
        }
        else {
            [string]$ExitCode
        }

        throw @"
Process stopped unexpectedly during: $Stage
Exit code: $ExitCodeText

Last stdout lines:
$($StdOutTail -join [Environment]::NewLine)

Last stderr lines:
$($StdErrTail -join [Environment]::NewLine)
"@
    }
}

function Wait-ProcessOrThrow {
    param(
        [Parameter(Mandatory = $true)]
        [System.Diagnostics.Process]$Process,

        [Parameter(Mandatory = $true)]
        [int]$TimeoutMilliseconds,

        [Parameter(Mandatory = $true)]
        [string]$ProcessName,

        [Parameter(Mandatory = $true)]
        [string]$StdErrFile
    )

    $Exited = $Process.WaitForExit($TimeoutMilliseconds)

    if (-not $Exited) {
        throw "$ProcessName did not finish within the expected timeout."
    }

    # Complete redirected-stream processing and refresh the process object
    # before reading ExitCode.
    $Process.WaitForExit()
    $Process.Refresh()

    $ExitCode = Resolve-ProcessExitCode `
        -Process $Process `
        -StdErrFile $StdErrFile

    if ($null -eq $ExitCode) {
        $StdErrTail = if (Test-Path $StdErrFile) {
            Get-Content $StdErrFile -Tail 40
        }
        else {
            @("No stderr file was created.")
        }

        throw @"
$ProcessName finished, but its exit code could not be determined.

Last stderr lines:
$($StdErrTail -join [Environment]::NewLine)
"@
    }

    if ($ExitCode -ne 0) {
        $StdErrTail = if (Test-Path $StdErrFile) {
            Get-Content $StdErrFile -Tail 40
        }
        else {
            @("No stderr file was created.")
        }

        throw @"
$ProcessName exited with code $ExitCode.

Last stderr lines:
$($StdErrTail -join [Environment]::NewLine)
"@
    }

    Write-Host "$ProcessName completed successfully with exit code 0."
}

# ------------------------------------------------------------
# Resolve repository paths
# ------------------------------------------------------------

$RepoRoot = (
    Resolve-Path (
        Join-Path $PSScriptRoot ".."
    )
).Path

$Python = (
    Get-Command python -ErrorAction Stop
).Source

$BaselineFile = (
    Resolve-Path (
        Join-Path `
            $RepoRoot `
            "experiments\baseline\checkout-normal-locustfile.py"
    )
).Path

$AttackFile = (
    Resolve-Path (
        Join-Path `
            $RepoRoot `
            "experiments\attacks\checkout-abuse-locustfile.py"
    )
).Path

$RunDir = Join-Path `
    $RepoRoot `
    "evidence\05-checkout-abuse\run-$RunNumber"

if (Test-Path $RunDir) {
    throw "Evidence directory already exists: $RunDir. Archive it before rerunning."
}

New-Item `
    -ItemType Directory `
    -Force `
    -Path $RunDir |
    Out-Null

$BaselineProcess = $null
$AttackProcess = $null
$RunCompleted = $false

$BaselineStdOut = Join-Path $RunDir "baseline-console-output.txt"
$BaselineStdErr = Join-Path $RunDir "baseline-console-error.txt"
$AttackStdOut = Join-Path $RunDir "attack-console-output.txt"
$AttackStdErr = Join-Path $RunDir "attack-console-error.txt"

try {
    Write-Section "Formal Checkout-Abuse Run $RunNumber"

    Write-Host "Repository root: $RepoRoot"
    Write-Host "Python:          $Python"
    Write-Host "Baseline file:   $BaselineFile"
    Write-Host "Attack file:     $AttackFile"
    Write-Host "Evidence path:   $RunDir"

    # --------------------------------------------------------
    # Preflight validation
    # --------------------------------------------------------

    Write-Section "Preflight checks"

    Assert-NoExistingLocust
    Assert-ApplicationReady

    $Frontend = Invoke-WebRequest `
        -Uri "http://localhost:8080/" `
        -Method Get `
        -TimeoutSec 15 `
        -UseBasicParsing

    if ($Frontend.StatusCode -ne 200) {
        throw "Frontend returned HTTP $($Frontend.StatusCode)."
    }

    Write-Host "Application pods: 9/9 ready"
    Write-Host "Frontend: HTTP 200"
    Write-Host "Existing Locust processes: none"

    Save-PodEvidence `
        -RunDirectory $RunDir `
        -Stage "before"

    @"
Scenario: Checkout Workflow Abuse
Formal run: $RunNumber

Protocol:
- 10 minutes normal preconditioning
- 10 minutes measured normal baseline
- 5 minutes checkout abuse
- 10 minutes measured normal recovery

Normal workload:
- 2 persistent users
- Runs continuously across all phases

Attack workload:
- 5 persistent users
- Spawn rate: 1 user/second
- Wait time: 3-5 seconds
"@ | Set-Content "$RunDir\run-metadata.txt"

    # --------------------------------------------------------
    # Start continuous normal checkout traffic.
    # --------------------------------------------------------

    Write-Section "Starting continuous normal checkout traffic"

    $BaselineArguments = @(
        "-m", "locust",
        "-f", "`"$BaselineFile`"",
        "--headless",
        "--host", "http://localhost:8080",
        "--users", "2",
        "--spawn-rate", "1",
        "--run-time", "36m",
        "--stop-timeout", "5s",
        "--csv", "`"$RunDir\baseline`"",
        "--csv-full-history",
        "--html", "`"$RunDir\baseline-report.html`""
    )

    $BaselineProcess = Start-Process `
        -FilePath $Python `
        -ArgumentList $BaselineArguments `
        -WorkingDirectory $RepoRoot `
        -RedirectStandardOutput $BaselineStdOut `
        -RedirectStandardError $BaselineStdErr `
        -PassThru `
        -WindowStyle Hidden

    Start-Sleep -Seconds 8

    Assert-ProcessRunning `
        -Process $BaselineProcess `
        -Stage "baseline startup" `
        -StdOutFile $BaselineStdOut `
        -StdErrFile $BaselineStdErr

    Write-Host "Continuous baseline process confirmed running."
    Write-Host "Baseline process ID: $($BaselineProcess.Id)"

    $PreconditioningStart = [DateTimeOffset]::Now

    $PreconditioningStart.ToString("o") |
        Set-Content "$RunDir\preconditioning-start.txt"

    Write-Host "Preconditioning started: $($PreconditioningStart.ToString('o'))"
    Write-Host "Waiting 10 minutes..."

    Start-Sleep -Seconds 600

    Assert-ProcessRunning `
        -Process $BaselineProcess `
        -Stage "end of preconditioning" `
        -StdOutFile $BaselineStdOut `
        -StdErrFile $BaselineStdErr

    Assert-ApplicationReady

    # --------------------------------------------------------
    # Formal measured normal baseline.
    # --------------------------------------------------------

    Write-Section "Measured normal baseline"

    $ExperimentStart = [DateTimeOffset]::Now

    $ExperimentStart.ToString("o") |
        Set-Content "$RunDir\experiment-start.txt"

    Write-Host "Formal experiment started: $($ExperimentStart.ToString('o'))"
    Write-Host "Waiting 10 minutes of measured normal traffic..."

    Start-Sleep -Seconds 600

    Assert-ProcessRunning `
        -Process $BaselineProcess `
        -Stage "end of formal baseline" `
        -StdOutFile $BaselineStdOut `
        -StdErrFile $BaselineStdErr

    Assert-ApplicationReady

    # --------------------------------------------------------
    # Checkout-abuse phase.
    #
    # Start-Process is used here because Locust writes normal
    # INFO messages to stderr. In Windows PowerShell, piping
    # native stderr through 2>&1 with ErrorActionPreference=Stop
    # can incorrectly raise NativeCommandError.
    # --------------------------------------------------------

    Write-Section "Checkout abuse phase"

    $AttackStart = [DateTimeOffset]::Now

    $AttackStart.ToString("o") |
        Set-Content "$RunDir\attack-start.txt"

    Write-Host "Checkout abuse started: $($AttackStart.ToString('o'))"

    $AttackArguments = @(
        "-m", "locust",
        "-f", "`"$AttackFile`"",
        "--headless",
        "--host", "http://localhost:8080",
        "--users", "5",
        "--spawn-rate", "1",
        "--run-time", "5m",
        "--stop-timeout", "5s",
        "--csv", "`"$RunDir\attack`"",
        "--csv-full-history",
        "--html", "`"$RunDir\attack-report.html`""
    )

    $AttackProcess = Start-Process `
        -FilePath $Python `
        -ArgumentList $AttackArguments `
        -WorkingDirectory $RepoRoot `
        -RedirectStandardOutput $AttackStdOut `
        -RedirectStandardError $AttackStdErr `
        -PassThru `
        -WindowStyle Hidden

    Start-Sleep -Seconds 5

    Assert-ProcessRunning `
        -Process $AttackProcess `
        -Stage "attack startup" `
        -StdOutFile $AttackStdOut `
        -StdErrFile $AttackStdErr

    Write-Host "Checkout-abuse process confirmed running."
    Write-Host "Attack process ID: $($AttackProcess.Id)"

    Wait-ProcessOrThrow `
        -Process $AttackProcess `
        -TimeoutMilliseconds 360000 `
        -ProcessName "Checkout-abuse Locust" `
        -StdErrFile $AttackStdErr

    $AttackEnd = [DateTimeOffset]::Now

    $AttackEnd.ToString("o") |
        Set-Content "$RunDir\attack-end.txt"

    Assert-ProcessRunning `
        -Process $BaselineProcess `
        -Stage "end of attack" `
        -StdOutFile $BaselineStdOut `
        -StdErrFile $BaselineStdErr

    Write-Host "Checkout abuse ended: $($AttackEnd.ToString('o'))"

    # --------------------------------------------------------
    # Formal recovery.
    # --------------------------------------------------------

    Write-Section "Normal recovery"

    Write-Host "Continuous normal traffic remains active."
    Write-Host "Waiting 10 minutes of recovery..."

    Start-Sleep -Seconds 600

    $RecoveryEnd = [DateTimeOffset]::Now

    $RecoveryEnd.ToString("o") |
        Set-Content "$RunDir\recovery-end.txt"

    Write-Host "Formal recovery ended: $($RecoveryEnd.ToString('o'))"

    Assert-ApplicationReady

    # --------------------------------------------------------
    # Complete continuous baseline process.
    # --------------------------------------------------------

    Write-Section "Finalizing Locust evidence"

    Wait-ProcessOrThrow `
        -Process $BaselineProcess `
        -TimeoutMilliseconds 180000 `
        -ProcessName "Baseline Locust" `
        -StdErrFile $BaselineStdErr

    Save-PodEvidence `
        -RunDirectory $RunDir `
        -Stage "after"

    Assert-ApplicationReady

    @"
Preconditioning start ISO: $($PreconditioningStart.ToString("o"))
Experiment start ISO:      $($ExperimentStart.ToString("o"))
Attack start ISO:          $($AttackStart.ToString("o"))
Attack end ISO:            $($AttackEnd.ToString("o"))
Recovery end ISO:          $($RecoveryEnd.ToString("o"))

Preconditioning start ms:  $($PreconditioningStart.ToUnixTimeMilliseconds())
Experiment start ms:       $($ExperimentStart.ToUnixTimeMilliseconds())
Attack start ms:           $($AttackStart.ToUnixTimeMilliseconds())
Attack end ms:             $($AttackEnd.ToUnixTimeMilliseconds())
Recovery end ms:           $($RecoveryEnd.ToUnixTimeMilliseconds())
"@ | Set-Content "$RunDir\formal-timestamps.txt"

    @"
Formal checkout-abuse Run $RunNumber completed successfully.

OpenSearch and Grafana results must still be collected before
classifying the run as detected or not detected.
"@ | Set-Content "$RunDir\run-status.txt"

    $RunCompleted = $true

    Write-Section "Formal Run $RunNumber completed"

    Write-Host "Evidence directory: $RunDir"
    Write-Host "Next: collect OpenSearch and Grafana evidence."

    kubectl get pods -n application
}
catch {
    $FailureTime = [DateTimeOffset]::Now

    @"
Formal checkout-abuse Run $RunNumber failed.

Failure time:
$($FailureTime.ToString("o"))

Error:
$($_.Exception.Message)

This attempt is not a valid formal run until reviewed.
"@ | Set-Content "$RunDir\run-failure.txt"

    foreach ($Process in @($AttackProcess, $BaselineProcess)) {
        if (
            $Process -and
            -not $Process.HasExited
        ) {
            Stop-Process `
                -Id $Process.Id `
                -Force `
                -ErrorAction SilentlyContinue
        }
    }

    Write-Host ""
    Write-Host "FORMAL RUN FAILED" -ForegroundColor Red
    Write-Host $_.Exception.Message -ForegroundColor Red
    Write-Host "Evidence preserved at: $RunDir"

    throw
}
finally {
    if (
        -not $RunCompleted -and
        (Test-Path $RunDir)
    ) {
        Get-LocustProcesses |
            Select-Object ProcessId, Name, CommandLine |
            Set-Content "$RunDir\locust-processes-after-failure.txt"
    }
}
