#!/usr/bin/env python3
"""
Console-Based Code Quality Report (SonarQube-style)
Generates comprehensive code quality metrics without SonarQube server
"""

import subprocess
import sys
import os
import json
import xml.etree.ElementTree as ET
from datetime import datetime
import re

# Color codes for console output
class Colors:
    HEADER = '\033[95m'
    OKBLUE = '\033[94m'
    OKCYAN = '\033[96m'
    OKGREEN = '\033[92m'
    WARNING = '\033[93m'
    FAIL = '\033[91m'
    ENDC = '\033[0m'
    BOLD = '\033[1m'
    UNDERLINE = '\033[4m'

def print_header(text):
    print(f"\n{Colors.OKCYAN}{Colors.BOLD}{text}{Colors.ENDC}")

def print_success(text):
    print(f"{Colors.OKGREEN}{text}{Colors.ENDC}")

def print_warning(text):
    print(f"{Colors.WARNING}{text}{Colors.ENDC}")

def print_error(text):
    print(f"{Colors.FAIL}{text}{Colors.ENDC}")

def print_metric(label, value, status="info"):
    color = {
        "good": Colors.OKGREEN,
        "warning": Colors.WARNING,
        "error": Colors.FAIL,
        "info": Colors.ENDC
    }.get(status, Colors.ENDC)
    print(f"  {label}: {color}{value}{Colors.ENDC}")

def run_command(cmd, silent=True):
    """Run command and return output"""
    try:
        result = subprocess.run(
            cmd,
            shell=True,
            capture_output=True,
            text=True,
            timeout=120
        )
        return result.stdout + result.stderr, result.returncode
    except Exception as e:
        return str(e), 1

def main():
    os.system('cls' if os.name == 'nt' else 'clear')
    
    print_header("═" * 70)
    print_header("          CODE QUALITY ANALYSIS REPORT (Console Mode)          ")
    print_header("          ACEest Fitness & Gym Management System               ")
    print_header("═" * 70)
    
    print(f"\nProject: ACEest Fitness")
    print(f"Date: {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}")
    
    # Get Python version
    py_version, _ = run_command("python --version")
    print(f"Python Version: {py_version.strip()}")
    print()
    
    # Install required tools
    print("Installing analysis tools...")
    run_command("pip install -q pylint flake8 bandit radon pytest pytest-cov")
    print_success("✓ Tools installed\n")
    
    metrics = {}
    
    # ===== 1. TEST COVERAGE =====
    print_header("[1/6] Running Test Coverage Analysis...")
    
    run_command("pytest test_app.py --cov=. --cov-report=term --cov-report=xml -q")
    
    if os.path.exists("coverage.xml"):
        try:
            tree = ET.parse("coverage.xml")
            root = tree.getroot()
            
            line_rate = float(root.get('line-rate', 0)) * 100
            branch_rate = float(root.get('branch-rate', 0)) * 100
            lines_valid = int(root.get('lines-valid', 0))
            lines_covered = int(root.get('lines-covered', 0))
            
            metrics['coverage'] = line_rate
            metrics['branch_coverage'] = branch_rate
            
            status = "good" if line_rate >= 80 else "warning" if line_rate >= 60 else "error"
            print_metric("Overall Coverage", f"{line_rate:.2f}%", status)
            print_metric("Branch Coverage", f"{branch_rate:.2f}%", status)
            print_metric("Lines Covered", f"{lines_covered} / {lines_valid}", status)
            
            # File-level coverage
            print("\n  File-level Coverage:")
            for package in root.findall('.//package'):
                for cls in package.findall('.//class'):
                    filename = cls.get('filename', '').replace('\\', '/')
                    if filename:
                        file_rate = float(cls.get('line-rate', 0)) * 100
                        file_status = "good" if file_rate >= 80 else "warning" if file_rate >= 60 else "error"
                        print_metric(f"    {os.path.basename(filename)}", f"{file_rate:.2f}%", file_status)
        except Exception as e:
            print_warning(f"  Could not parse coverage: {e}")
    else:
        print_warning("  Coverage data not available")
    
    # ===== 2. CODE STYLE (FLAKE8) =====
    print_header("\n[2/6] Running Code Style Analysis (Flake8)...")
    
    flake8_out, _ = run_command("flake8 app.py --statistics --count")
    flake8_count = 0
    
    for line in flake8_out.split('\n'):
        if re.match(r'^\d+\s+', line):
            count = int(line.split()[0])
            flake8_count += count
            print(f"  {line}")
    
    metrics['style_issues'] = flake8_count
    status = "good" if flake8_count == 0 else "warning" if flake8_count < 10 else "error"
    print_metric("Total Style Issues (PEP8)", flake8_count, status)
    
    # ===== 3. CODE QUALITY (PYLINT) =====
    print_header("\n[3/6] Running Code Quality Analysis (Pylint)...")
    
    pylint_out, _ = run_command("pylint app.py --output-format=text --score=yes")
    pylint_score = 0.0
    
    for line in pylint_out.split('\n'):
        match = re.search(r'Your code has been rated at ([\d.]+)/10', line)
        if match:
            pylint_score = float(match.group(1))
            break
    
    metrics['quality_score'] = pylint_score
    status = "good" if pylint_score >= 8.0 else "warning" if pylint_score >= 6.0 else "error"
    print_metric("Code Quality Score", f"{pylint_score:.2f} / 10.0", status)
    
    # Count issue types
    conventions = len(re.findall(r'convention', pylint_out, re.IGNORECASE))
    warnings = len(re.findall(r'warning', pylint_out, re.IGNORECASE))
    errors = len(re.findall(r'error', pylint_out, re.IGNORECASE))
    
    print_metric("  Conventions", conventions, "good" if conventions == 0 else "warning")
    print_metric("  Warnings", warnings, "good" if warnings == 0 else "warning")
    print_metric("  Errors", errors, "good" if errors == 0 else "error")
    
    # ===== 4. SECURITY (BANDIT) =====
    print_header("\n[4/6] Running Security Analysis (Bandit)...")
    
    bandit_out, _ = run_command("bandit app.py -f json")
    
    high_severity = 0
    medium_severity = 0
    low_severity = 0
    
    try:
        bandit_data = json.loads(bandit_out)
        for result in bandit_data.get('results', []):
            severity = result.get('issue_severity', '').upper()
            if severity == 'HIGH':
                high_severity += 1
                print_error(f"  [HIGH] Line {result.get('line_number')}: {result.get('issue_text')}")
            elif severity == 'MEDIUM':
                medium_severity += 1
                print_warning(f"  [MEDIUM] Line {result.get('line_number')}: {result.get('issue_text')}")
            elif severity == 'LOW':
                low_severity += 1
    except:
        pass
    
    metrics['security_high'] = high_severity
    metrics['security_medium'] = medium_severity
    
    print_metric("High Severity Issues", high_severity, "good" if high_severity == 0 else "error")
    print_metric("Medium Severity Issues", medium_severity, "good" if medium_severity == 0 else "warning")
    print_metric("Low Severity Issues", low_severity, "good")
    
    # ===== 5. COMPLEXITY (RADON) =====
    print_header("\n[5/6] Running Complexity Analysis (Radon)...")
    
    radon_out, _ = run_command("radon cc app.py -a -s")
    avg_complexity = 0.0
    complex_functions = 0
    
    for line in radon_out.split('\n'):
        match = re.search(r'Average complexity: [A-Z]+ \(([\d.]+)\)', line)
        if match:
            avg_complexity = float(match.group(1))
        
        match = re.search(r'\((\d+)\)', line)
        if match and int(match.group(1)) > 10:
            complex_functions += 1
            print_warning(f"  {line.strip()}")
    
    metrics['avg_complexity'] = avg_complexity
    metrics['complex_functions'] = complex_functions
    
    status = "good" if avg_complexity < 5 else "warning" if avg_complexity < 10 else "error"
    print_metric("Average Complexity", f"{avg_complexity:.2f}", status)
    print_metric("Complex Functions (CC > 10)", complex_functions, "good" if complex_functions == 0 else "warning")
    
    # ===== 6. TESTS =====
    print_header("\n[6/6] Running Test Suite...")
    
    test_out, _ = run_command("pytest test_app.py -v --tb=short")
    
    tests_passed = test_out.count(" PASSED")
    tests_failed = test_out.count(" FAILED")
    tests_total = tests_passed + tests_failed
    
    metrics['tests_passed'] = tests_passed
    metrics['tests_failed'] = tests_failed
    
    status = "good" if tests_failed == 0 else "error"
    print_metric("Tests Passed", f"{tests_passed} / {tests_total}", status)
    print_metric("Tests Failed", tests_failed, "good" if tests_failed == 0 else "error")
    
    # ===== SUMMARY =====
    print_header("\n" + "═" * 70)
    print_header("                        QUALITY SUMMARY                         ")
    print_header("═" * 70)
    
    quality_gate = "PASSED"
    issues = []
    
    if metrics.get('coverage', 0) < 80:
        quality_gate = "FAILED"
        issues.append("Coverage below 80%")
    
    if metrics.get('quality_score', 0) < 7.0:
        quality_gate = "WARNING"
        issues.append("Code quality score below 7.0")
    
    if metrics.get('security_high', 0) > 0:
        quality_gate = "FAILED"
        issues.append("High severity security issues found")
    
    if metrics.get('tests_failed', 0) > 0:
        quality_gate = "FAILED"
        issues.append("Test failures detected")
    
    print("\nQuality Gate: ", end="")
    if quality_gate == "PASSED":
        print_success(quality_gate)
    elif quality_gate == "WARNING":
        print_warning(quality_gate)
    else:
        print_error(quality_gate)
    
    if issues:
        print("\n" + Colors.WARNING + "Issues to Address:" + Colors.ENDC)
        for issue in issues:
            print_warning(f"  • {issue}")
    
    # Summary Table
    print("\n┌─────────────────────────────────┬──────────────┬────────────┐")
    print("│ Metric                          │ Value        │ Status     │")
    print("├─────────────────────────────────┼──────────────┼────────────┤")
    
    def table_row(metric, value, status):
        symbol = {"good": "✓", "warning": "⚠", "error": "✗", "info": "?"}.get(status, "?")
        color = {"good": Colors.OKGREEN, "warning": Colors.WARNING, "error": Colors.FAIL}.get(status, Colors.ENDC)
        print(f"│ {metric:<31} │ {value:<12} │ {color}{symbol:>5}{Colors.ENDC}      │")
    
    cov = metrics.get('coverage', 0)
    cov_status = "good" if cov >= 80 else "warning" if cov >= 60 else "error"
    table_row("Code Coverage", f"{cov:.2f}%", cov_status)
    
    quality = metrics.get('quality_score', 0)
    quality_status = "good" if quality >= 8 else "warning" if quality >= 6 else "error"
    table_row("Code Quality (Pylint)", f"{quality:.2f}/10", quality_status)
    
    style = metrics.get('style_issues', 0)
    style_status = "good" if style == 0 else "warning" if style < 10 else "error"
    table_row("Style Issues (Flake8)", str(style), style_status)
    
    sec = metrics.get('security_high', 0)
    sec_status = "good" if sec == 0 else "error"
    table_row("Security Issues (High)", str(sec), sec_status)
    
    comp = metrics.get('avg_complexity', 0)
    comp_status = "good" if comp < 5 else "warning" if comp < 10 else "error"
    table_row("Complexity (Average)", f"{comp:.2f}", comp_status)
    
    test_pass = metrics.get('tests_passed', 0)
    test_total = test_pass + metrics.get('tests_failed', 0)
    test_status = "good" if metrics.get('tests_failed', 0) == 0 else "error"
    table_row("Test Pass Rate", f"{test_pass}/{test_total}", test_status)
    
    print("└─────────────────────────────────┴──────────────┴────────────┘")
    
    # Save report
    report_file = "console-report.txt"
    with open(report_file, 'w') as f:
        f.write(f"CODE QUALITY ANALYSIS REPORT\n")
        f.write(f"Generated: {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}\n")
        f.write(f"Project: ACEest Fitness & Gym Management System\n\n")
        f.write(f"METRICS SUMMARY\n")
        f.write(f"===============\n")
        f.write(f"Code Coverage: {cov:.2f}%\n")
        f.write(f"Code Quality Score: {quality:.2f} / 10.0\n")
        f.write(f"Style Issues: {style}\n")
        f.write(f"Security Issues (High): {metrics.get('security_high', 0)}\n")
        f.write(f"Security Issues (Medium): {metrics.get('security_medium', 0)}\n")
        f.write(f"Average Complexity: {comp:.2f}\n")
        f.write(f"Tests Passed: {test_pass} / {test_total}\n")
        f.write(f"\nQUALITY GATE: {quality_gate}\n")
    
    print(f"\nReport saved to: {report_file}")
    print_success("\n✓ Analysis Complete!\n")

if __name__ == "__main__":
    main()
