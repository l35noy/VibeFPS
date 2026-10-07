#Requires -Version 5.1
<#
.SYNOPSIS
    Single entry point for every headless check in VibeFPS.

.DESCRIPTION
    Runs each check in tests\ as its own Godot process:

        godot --headless --path . --script res://tests/<name>.gd

    A check is a standalone SceneTree script that ends in quit(0) on success
    and quit(1) on failure. The order of $Tests is meaningful: "smoke" guards
    scene integrity and therefore runs before every other check.

    A name listed in $Tests whose file does not exist yet is reported as
    [SKIP], never as a pass and never as a failure. That is what lets the list
    be declared up front and grown phase by phase.

    Each check runs under a wall-clock timeout ($CheckTimeoutMs, 120 s by
    default). A check that exceeds it is killed and reported as FAIL so that a
    hung check cannot block the run forever.

.PARAMETER Filter
    Optional substring of the test name, matched case-insensitively. Omit it
    (or pass an empty string) to run every listed check.

.EXAMPLE
    .\tools\run_checks.ps1
    Runs every check and prints a RESULT summary line.

.EXAMPLE
    .\tools\run_checks.ps1 smok
    Runs only the checks whose name contains "smok".

.NOTES
    Exit code 0 = every executed check passed. Exit code 1 = at least one check
    failed, timed out, or Godot itself could not be found.
#>

$ErrorActionPreference = 'Stop'

# Godot 4.7.2 stable. This is the single supported engine for the project; do
# not add a second path here, the test contract (exit codes, [FAIL] markers on
# stdout, --headless flag) is tied to this build.
$GodotBin = "E:\Godot\Godot_v4.7.2-stable_win64.exe"

# Ordered list of check names, without the .gd extension.
$Tests = @("smoke", "movement", "input_actions", "input_gate", "weapon_data", "integrity",
           "weapon", "projectile", "enemies", "waves", "save", "progression")

# tests\capture.gd needs a real renderer and tests\diagnose.gd is run by hand,
# so neither belongs here.

$Filter = ''
if ($args.Count -gt 0 -and $null -ne $args[0]) {
    $Filter = [string]$args[0]
}

# Godot's --path . is resolved against the process working directory, and the
# test existence check is resolved against the repo, so pin both to the repo
# root no matter where the script was invoked from.
$RepoRoot = Split-Path -Parent $PSScriptRoot

# Per-check wall-clock budget. The real 31-check smoke test measures ~17s on
# this hardware, so 120s leaves ~7x headroom for heavier checks added in later
# phases (a hang must not be reported as a slow pass). A check that exceeds this
# is killed and reported as FAIL rather than blocking the run forever.
$CheckTimeoutMs = 120000

# Unique per run AND per process. $PID alone would still collide if two runners
# were launched from the same parent process, and a collision would let one run
# read the other's output and report PASS for someone else's check.
$runTag = '{0}-{1}' -f $PID, ([guid]::NewGuid().ToString('N').Substring(0, 8))
$stdoutPath = Join-Path ([System.IO.Path]::GetTempPath()) "vibefps_check_out_$runTag.txt"
$stderrPath = Join-Path ([System.IO.Path]::GetTempPath()) "vibefps_check_err_$runTag.txt"

Push-Location -LiteralPath $RepoRoot
try {
    # Fail loudly and run nothing if the engine is missing, rather than
    # reporting every check as failed for a reason that has nothing to do with
    # the code under test.
    if (-not (Test-Path -LiteralPath $GodotBin -PathType Leaf)) {
        Write-Output "Godot binary not found: $GodotBin"
        Write-Output "RESULT: 0 passed, 0 failed, 0 skipped"
        exit 1
    }

    # Global class_name declarations (scripts\input_gate.gd declares InputGate)
    # are visible to the parser only through .godot\global_script_class_cache.cfg,
    # and that file is git-ignored. On a clean clone it does not exist, so every
    # script referring to a class_name fails to parse with "Identifier ... not
    # declared in the current scope".
    #
    # The cache also goes stale without disappearing, which is the case that
    # matters most: adding a class_name leaves an existing cache that simply does
    # not list it, and the script referring to it then dies at parse time with
    # "Could not find type ... in the current scope". That reads as that script's
    # own failure and the script cannot say why -- a check that dies before its
    # first assertion cannot report its own failure. So the cache counts as stale
    # when it is missing OR when any source is newer than it.
    #
    # One import pass rebuilds the cache and costs about two seconds, so it runs
    # only when one of those two holds, not on every invocation. Placed after the
    # engine pre-check above so a missing Godot still fails fast with its own
    # message instead of being invoked here.
    $classCache = Join-Path $RepoRoot '.godot\global_script_class_cache.cfg'
    $cacheFile = Get-Item -LiteralPath $classCache -ErrorAction SilentlyContinue

    # The scan is the only cost of this check, so it is one pass, and .godot is
    # pruned rather than descended into and filtered out afterwards: it holds the
    # engine's imported binaries, is most of the tree by file count, and can never
    # contain a class_name. -Include cannot express that -- with -LiteralPath it
    # does not filter at all (it returned every file in the repo, project.godot
    # among them), which would both build FileInfo for the whole tree and treat an
    # edit to any file as a reason to re-import. The extension test is explicit
    # instead.
    $sourceRoots = @(Get-ChildItem -LiteralPath $RepoRoot -ErrorAction SilentlyContinue |
        Where-Object { $_.Name -ne '.godot' } |
        Select-Object -ExpandProperty FullName)
    $newestSource = $null
    # An empty -LiteralPath array is a terminating parameter binding error, and
    # $ErrorActionPreference is Stop: it would abort the whole run with a
    # PowerShell stack trace and no RESULT line. Unreachable while project.godot
    # exists, but this is the single entry point to every check.
    if ($sourceRoots.Count -gt 0) {
        # LastWriteTimeUtc, not LastWriteTime: the cache is written by the engine
        # and both sides of the comparison are compared across a DST boundary,
        # which local wall-clock timestamps do not survive.
        $newestSource = Get-ChildItem -LiteralPath $sourceRoots -Recurse -File -ErrorAction SilentlyContinue |
            Where-Object { $_.Extension -in '.gd', '.tscn', '.tres' } |
            Sort-Object LastWriteTimeUtc -Descending |
            Select-Object -First 1
    }
    $needsImport = $null -eq $cacheFile -or
        ($null -ne $newestSource -and $newestSource.LastWriteTimeUtc -gt $cacheFile.LastWriteTimeUtc)
    if ($needsImport) {
        Write-Output "importing project (class cache missing or stale) ..."
        & $GodotBin --headless --path . --import | Out-Null
    }

    $pass = 0
    $fail = 0
    $skip = 0

    foreach ($name in $Tests) {
        if ($Filter -ne '' -and $name.IndexOf($Filter, [System.StringComparison]::OrdinalIgnoreCase) -lt 0) {
            continue
        }

        $scriptPath = Join-Path $RepoRoot ("tests\{0}.gd" -f $name)
        if (-not (Test-Path -LiteralPath $scriptPath -PathType Leaf)) {
            Write-Output ("{0,-14} [SKIP]  (tests\{1}.gd not present)" -f $name, $name)
            $skip++
            continue
        }

        foreach ($tmp in @($stdoutPath, $stderrPath)) {
            Remove-Item -LiteralPath $tmp -Force -ErrorAction SilentlyContinue
        }

        # --headless reports engine diagnostics on stderr while the check's own
        # print() output, including the [FAIL] lines, goes to stdout. Both
        # streams are captured to files and re-read afterwards: PowerShell 5.1's
        # 2>&1 is not dependable for native processes here, and a test that
        # fails without its [FAIL] lines reaching the console is a runner that
        # cannot be debugged.
        #
        # Started without -Wait and bounded with WaitForExit instead: -Wait
        # blocks forever, and a check that throws before reaching quit() leaves
        # Godot running indefinitely. That would mean no RESULT line, no exit
        # code, and a stuck session for whoever is driving this script.
        $proc = Start-Process -FilePath $GodotBin `
            -ArgumentList '--headless', '--path', '.', '--script', "res://tests/$name.gd" `
            -WorkingDirectory $RepoRoot `
            -NoNewWindow -PassThru `
            -RedirectStandardOutput $stdoutPath `
            -RedirectStandardError $stderrPath

        # Cache the process handle BEFORE the process exits. Start-Process -PassThru
        # without -Wait hands back a Process whose ExitCode reads back as $null once
        # the process is gone, because the handle was never retained; touching .Handle
        # here pins it. Without this, `$code -eq 0` is false for every check and the
        # PASS branch is unreachable -- the runner reports a green check as FAIL.
        # The $null = is required: .Handle returns an IntPtr that would otherwise
        # print into the runner's output.
        $null = $proc.Handle

        $timedOut = -not $proc.WaitForExit($CheckTimeoutMs)
        if ($timedOut) {
            # Kill only this check so the remaining ones still run; a single
            # hung check must not abort the whole suite.
            try {
                $proc.Kill()
                # Let the OS reap it and flush the redirected handles before
                # the files are read below. Bounded on purpose: Kill() returns
                # void under .NET Framework, so a kill that failed to terminate
                # the process would make an unbounded wait hang forever, which is
                # exactly what $CheckTimeoutMs exists to prevent. The result is
                # discarded because the bounded overload returns a bool that
                # would otherwise leak onto the runner's stdout.
                $null = $proc.WaitForExit(5000)
            } catch {
                # Already gone between the timeout and the kill; nothing to do.
            }
        } else {
            # The bounded WaitForExit(ms) above returns as soon as the process is
            # gone and does not wait for the redirected streams to reach EOF, so
            # the files read below would depend on Start-Process having flushed
            # them already. This parameterless overload does wait for EOF, making
            # the captured output deterministic instead of incidentally complete.
            $proc.WaitForExit()
        }

        $output = ''
        if (Test-Path -LiteralPath $stdoutPath) {
            $output += [System.IO.File]::ReadAllText($stdoutPath)
        }
        if (Test-Path -LiteralPath $stderrPath) {
            $output += [System.IO.File]::ReadAllText($stderrPath)
        }

        # The exit code is the primary contract, but a check that reports a
        # failed assertion and then forgets quit(1) must not read as a pass.
        # This can only turn PASS into FAIL, never the reverse. The (?m) flag
        # matters: without it ^ anchors to the start of the whole captured
        # output rather than the start of each line, and the check would
        # silently false-pass whenever the engine banner precedes the failure.
        $reportedFailure = $output -match '(?m)^\s*\[FAIL\]'
        $code = $proc.ExitCode

        # A timed-out check is always a FAIL, whatever its exit code or output
        # happen to say: it never reached a verdict, so there is nothing to pass.
        if ($code -eq 0 -and -not $reportedFailure -and -not $timedOut) {
            Write-Output ("{0,-14} PASS" -f $name)
            $pass++
        } else {
            if ($timedOut) {
                $reason = "timed out after $($CheckTimeoutMs / 1000) s"
            } elseif ($code -ne 0) {
                $reason = "exit code $code"
            } else {
                $reason = '[FAIL] marker in output but exit code 0'
            }
            Write-Output ("{0,-14} FAIL  ({1})" -f $name, $reason)
            foreach ($line in ($output -split "`r?`n")) {
                if ($line -ne '') { Write-Output "    $line" }
            }
            $fail++
        }
    }

    Write-Output ''
    Write-Output ("RESULT: {0} passed, {1} failed, {2} skipped" -f $pass, $fail, $skip)

    if ($fail -gt 0) { exit 1 } else { exit 0 }
}
finally {
    Pop-Location
    foreach ($tmp in @($stdoutPath, $stderrPath)) {
        Remove-Item -LiteralPath $tmp -Force -ErrorAction SilentlyContinue
    }
}
