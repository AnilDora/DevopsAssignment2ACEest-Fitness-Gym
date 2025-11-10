# Console-Based Code Quality Report (SonarQube-style)
# Generates comprehensive code quality metrics without SonarQube server

param(
    [switch]$Detailed
)

# Color functions
function Write-Header { param($msg) Write-Host "`n$msg" -ForegroundColor Cyan -BackgroundColor DarkBlue }
function Write-Success { param($msg) Write-Host $msg -ForegroundColor Green }
function Write-Warning { param($msg) Write-Host $msg -ForegroundColor Yellow }
function Write-Error { param($msg) Write-Host $msg -ForegroundColor Red }
function Write-Info { param($msg) Write-Host $msg -ForegroundColor White }
function Write-Metric { param($label, $value, $status)
    $color = switch ($status) {
        "good" { "Green" }
        "warning" { "Yellow" }
        "error" { "Red" }
        default { "White" }
    }
    Write-Host "  $label" -NoNewline
    Write-Host ": $value" -ForegroundColor $color
}

Clear-Host

Write-Header "═══════════════════════════════════════════════════════════════"
Write-Header "          CODE QUALITY ANALYSIS REPORT (Console Mode)          "
Write-Header "          ACEest Fitness & Gym Management System               "
Write-Header "═══════════════════════════════════════════════════════════════"

Write-Info "`nProject: ACEest Fitness"
Write-Info "Date: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')"
Write-Info "Python Version: $(python --version 2>&1)"
Write-Host ""

# Install required tools
Write-Info "Installing analysis tools..."
pip install -q pylint flake8 bandit radon pytest pytest-cov 2>$null
Write-Success "✓ Tools installed"

# Clean old reports
Remove-Item -Path "console-report.txt" -ErrorAction SilentlyContinue

# Create report file
$reportFile = "console-report.txt"
$timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"

# Start analysis
Write-Header "`n[1/6] Running Test Coverage Analysis..."

# Run tests with coverage
pytest test_app.py --cov=. --cov-report=term --cov-report=xml -v --quiet 2>&1 | Out-Null

if (Test-Path "coverage.xml") {
    # Parse coverage XML
    [xml]$coverageXml = Get-Content "coverage.xml"
    $coverage = $coverageXml.coverage
    
    $lineRate = [math]::Round([double]$coverage.'line-rate' * 100, 2)
    $branchRate = [math]::Round([double]$coverage.'branch-rate' * 100, 2)
    $linesValid = $coverage.'lines-valid'
    $linesCovered = $coverage.'lines-covered'
    
    $coverageStatus = if ($lineRate -ge 80) { "good" } elseif ($lineRate -ge 60) { "warning" } else { "error" }
    
    Write-Metric "Overall Coverage" "$lineRate%" $coverageStatus
    Write-Metric "Branch Coverage" "$branchRate%" $coverageStatus
    Write-Metric "Lines Covered" "$linesCovered / $linesValid" $coverageStatus
    
    # File-by-file coverage
    if ($Detailed) {
        Write-Info "`n  File-level Coverage:"
        foreach ($package in $coverage.packages.package) {
            foreach ($class in $package.classes.class) {
                $fileName = $class.filename
                $fileLineRate = [math]::Round([double]$class.'line-rate' * 100, 2)
                $fileStatus = if ($fileLineRate -ge 80) { "good" } elseif ($fileLineRate -ge 60) { "warning" } else { "error" }
                Write-Metric "    $fileName" "$fileLineRate%" $fileStatus
            }
        }
    }
} else {
    Write-Warning "  Coverage data not available"
}

Write-Header "`n[2/6] Running Code Style Analysis (Flake8)..."

$flake8Output = flake8 app.py --statistics --count 2>&1
$flake8Lines = $flake8Output -split "`n"
$flake8Count = 0

foreach ($line in $flake8Lines) {
    if ($line -match "^\d+\s+") {
        $count = [int]($line -split "\s+")[0]
        $flake8Count += $count
        if ($Detailed) {
            Write-Info "  $line"
        }
    }
}

$styleStatus = if ($flake8Count -eq 0) { "good" } elseif ($flake8Count -lt 10) { "warning" } else { "error" }
Write-Metric "Style Issues (PEP8)" $flake8Count $styleStatus

Write-Header "`n[3/6] Running Code Quality Analysis (Pylint)..."

$pylintOutput = pylint app.py --output-format=text --score=yes 2>&1
$pylintScore = 0

foreach ($line in $pylintOutput -split "`n") {
    if ($line -match "Your code has been rated at ([\d\.]+)/10") {
        $pylintScore = [double]$matches[1]
    }
    if ($Detailed -and $line -match "^\w+:") {
        Write-Info "  $line"
    }
}

$qualityStatus = if ($pylintScore -ge 8.0) { "good" } elseif ($pylintScore -ge 6.0) { "warning" } else { "error" }
Write-Metric "Code Quality Score" "$pylintScore / 10.0" $qualityStatus

# Count issues by severity
$conventions = ($pylintOutput | Select-String -Pattern "convention" -AllMatches).Matches.Count
$warnings = ($pylintOutput | Select-String -Pattern "warning" -AllMatches).Matches.Count
$errors = ($pylintOutput | Select-String -Pattern "error" -AllMatches).Matches.Count

if ($Detailed) {
    Write-Metric "  Conventions" $conventions $(if ($conventions -eq 0) { "good" } else { "warning" })
    Write-Metric "  Warnings" $warnings $(if ($warnings -eq 0) { "good" } elseif ($warnings -lt 5) { "warning" } else { "error" })
    Write-Metric "  Errors" $errors $(if ($errors -eq 0) { "good" } else { "error" })
}

Write-Header "`n[4/6] Running Security Analysis (Bandit)..."

$banditOutput = bandit app.py -f json 2>&1 | ConvertFrom-Json -ErrorAction SilentlyContinue

if ($banditOutput) {
    $highSeverity = ($banditOutput.results | Where-Object { $_.issue_severity -eq "HIGH" }).Count
    $mediumSeverity = ($banditOutput.results | Where-Object { $_.issue_severity -eq "MEDIUM" }).Count
    $lowSeverity = ($banditOutput.results | Where-Object { $_.issue_severity -eq "LOW" }).Count
    
    $securityStatus = if ($highSeverity -eq 0 -and $mediumSeverity -eq 0) { "good" } elseif ($highSeverity -eq 0) { "warning" } else { "error" }
    
    Write-Metric "High Severity Issues" $highSeverity $(if ($highSeverity -eq 0) { "good" } else { "error" })
    Write-Metric "Medium Severity Issues" $mediumSeverity $(if ($mediumSeverity -eq 0) { "good" } else { "warning" })
    Write-Metric "Low Severity Issues" $lowSeverity "good"
    
    if ($Detailed -and $banditOutput.results.Count -gt 0) {
        Write-Info "`n  Security Issues Found:"
        foreach ($issue in $banditOutput.results) {
            Write-Warning "    [$($issue.issue_severity)] Line $($issue.line_number): $($issue.issue_text)"
        }
    }
} else {
    Write-Success "  No security issues detected"
}

Write-Header "`n[5/6] Running Complexity Analysis (Radon)..."

$radonOutput = radon cc app.py -a -s 2>&1
$avgComplexity = 0
$complexFunctions = 0

foreach ($line in $radonOutput -split "`n") {
    if ($line -match "Average complexity: \w+ \(([\d\.]+)\)") {
        $avgComplexity = [double]$matches[1]
    }
    if ($line -match "\((\d+)\)" -and $matches[1] -gt 10) {
        $complexFunctions++
        if ($Detailed) {
            Write-Warning "  $line"
        }
    }
}

$complexityStatus = if ($avgComplexity -lt 5) { "good" } elseif ($avgComplexity -lt 10) { "warning" } else { "error" }
Write-Metric "Average Complexity" "$avgComplexity" $complexityStatus
Write-Metric "Complex Functions (CC > 10)" $complexFunctions $(if ($complexFunctions -eq 0) { "good" } else { "warning" })

Write-Header "`n[6/6] Running Test Suite..."

$testOutput = pytest test_app.py -v --tb=short 2>&1
$testsPassed = ($testOutput | Select-String -Pattern "passed" -AllMatches).Matches.Count
$testsFailed = ($testOutput | Select-String -Pattern "failed" -AllMatches).Matches.Count
$testsTotal = $testsPassed + $testsFailed

$testStatus = if ($testsFailed -eq 0) { "good" } else { "error" }
Write-Metric "Tests Passed" "$testsPassed / $testsTotal" $testStatus
Write-Metric "Tests Failed" $testsFailed $(if ($testsFailed -eq 0) { "good" } else { "error" })

# Summary
Write-Header "`n═══════════════════════════════════════════════════════════════"
Write-Header "                        QUALITY SUMMARY                         "
Write-Header "═══════════════════════════════════════════════════════════════"

$qualityGate = "PASSED"
$issues = @()

if ($lineRate -lt 80) {
    $qualityGate = "FAILED"
    $issues += "Coverage below 80%"
}
if ($pylintScore -lt 7.0) {
    $qualityGate = "WARNING"
    $issues += "Code quality score below 7.0"
}
if ($highSeverity -gt 0) {
    $qualityGate = "FAILED"
    $issues += "High severity security issues found"
}
if ($testsFailed -gt 0) {
    $qualityGate = "FAILED"
    $issues += "Test failures detected"
}

Write-Host ""
Write-Host "Quality Gate: " -NoNewline
if ($qualityGate -eq "PASSED") {
    Write-Success $qualityGate
} elseif ($qualityGate -eq "WARNING") {
    Write-Warning $qualityGate
} else {
    Write-Error $qualityGate
}

if ($issues.Count -gt 0) {
    Write-Host "`nIssues to Address:" -ForegroundColor Yellow
    foreach ($issue in $issues) {
        Write-Warning "  • $issue"
    }
}

# Generate summary table
Write-Host "`n┌─────────────────────────────────┬──────────────┬────────────┐"
Write-Host "│ Metric                          │ Value        │ Status     │"
Write-Host "├─────────────────────────────────┼──────────────┼────────────┤"

function Write-TableRow {
    param($metric, $value, $status)
    $statusSymbol = switch ($status) {
        "good" { "✓" }
        "warning" { "⚠" }
        "error" { "✗" }
        default { "?" }
    }
    $statusColor = switch ($status) {
        "good" { "Green" }
        "warning" { "Yellow" }
        "error" { "Red" }
        default { "White" }
    }
    Write-Host "│ " -NoNewline
    Write-Host $metric.PadRight(31) -NoNewline
    Write-Host " │ " -NoNewline
    Write-Host $value.PadRight(12) -NoNewline
    Write-Host " │ " -NoNewline
    Write-Host $statusSymbol.PadLeft(5) -NoNewline -ForegroundColor $statusColor
    Write-Host "      │"
}

Write-TableRow "Code Coverage" "$lineRate%" $coverageStatus
Write-TableRow "Code Quality (Pylint)" "$pylintScore/10" $qualityStatus
Write-TableRow "Style Issues (Flake8)" "$flake8Count" $styleStatus
Write-TableRow "Security Issues (High)" "$highSeverity" $(if ($highSeverity -eq 0) { "good" } else { "error" })
Write-TableRow "Complexity (Average)" "$avgComplexity" $complexityStatus
Write-TableRow "Test Pass Rate" "$testsPassed/$testsTotal" $testStatus

Write-Host "└─────────────────────────────────┴──────────────┴────────────┘"

# Save to file
$reportContent = @"
CODE QUALITY ANALYSIS REPORT
Generated: $timestamp
Project: ACEest Fitness & Gym Management System

METRICS SUMMARY
===============
Code Coverage: $lineRate%
Code Quality Score: $pylintScore / 10.0
Style Issues: $flake8Count
Security Issues (High): $highSeverity
Security Issues (Medium): $mediumSeverity
Average Complexity: $avgComplexity
Tests Passed: $testsPassed / $testsTotal

QUALITY GATE: $qualityGate

RECOMMENDATIONS
===============
"@

if ($lineRate -lt 80) {
    $reportContent += "`n- Increase test coverage to at least 80%"
}
if ($pylintScore -lt 8.0) {
    $reportContent += "`n- Improve code quality by addressing pylint warnings"
}
if ($flake8Count -gt 0) {
    $reportContent += "`n- Fix PEP8 style violations"
}
if ($highSeverity -gt 0 -or $mediumSeverity -gt 0) {
    $reportContent += "`n- Address security vulnerabilities"
}
if ($avgComplexity -gt 5) {
    $reportContent += "`n- Refactor complex functions to reduce cyclomatic complexity"
}

$reportContent | Out-File -FilePath $reportFile -Encoding UTF8

Write-Host "`nReport saved to: $reportFile" -ForegroundColor Cyan
Write-Host ""

# Offer to open detailed reports
$openReports = Read-Host "Open detailed HTML reports? (Y/N)"
if ($openReports -eq 'Y' -or $openReports -eq 'y') {
    if (Test-Path "htmlcov\index.html") {
        Start-Process "htmlcov\index.html"
    }
    if (Test-Path "test-report.html") {
        Start-Process "test-report.html"
    }
}

Write-Success "`n✓ Analysis Complete!"
