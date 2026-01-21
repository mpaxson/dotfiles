#!/usr/bin/env python3
"""Test script for cmd_checker modules."""

import subprocess
import json
import sys
import os

CMD_CHECKER_DIR = os.path.dirname(os.path.abspath(__file__))
HOOKS_DIR = os.path.dirname(CMD_CHECKER_DIR)


def test_module(module, command, should_block, description, session_cwd=None):
    """Test a single check module."""
    module_path = os.path.join(CMD_CHECKER_DIR, module)
    input_data = {"tool_name": "Bash", "tool_input": {"command": command}}
    if session_cwd:
        input_data["session_cwd"] = session_cwd
    r = subprocess.run(
        ["python3", module_path],
        input=json.dumps(input_data),
        capture_output=True, text=True
    )
    blocked = r.returncode == 2
    status = "PASS" if blocked == should_block else "FAIL"
    return status, description, blocked


def test_full_checker(command, should_block, description):
    """Test the full cmd_checker module."""
    r = subprocess.run(
        ["python3", "-m", "cmd_checker"],
        input=json.dumps({"tool_name": "Bash", "tool_input": {"command": command}}),
        capture_output=True, text=True,
        cwd=HOOKS_DIR
    )
    blocked = r.returncode == 2
    status = "PASS" if blocked == should_block else "FAIL"
    return status, description, blocked


def main():
    print("Testing cmd_checker modules...\n")

    # Get home dir for tests
    import pathlib
    home = str(pathlib.Path.home())

    # Individual module tests
    module_tests = [
        ("check_search.py", "grep pattern file.txt", False, "single grep (allowed)"),
        ("check_search.py", "rg pattern src/", False, "single rg (allowed)"),
        ("check_write.py", "echo hello > file.txt", True, "echo redirect (blocked)"),
        ("check_write.py", "echo hello", False, "echo no redirect (allowed)"),
        ("check_read.py", "cat README.md", True, "cat file (blocked)"),
        ("check_read.py", "git status", False, "non-read (allowed)"),
        ("check_read.py", 'tail -50 /tmp/log.txt 2>/dev/null || echo "No log"', False, "|| echo fallback (allowed)"),
        ("check_read.py", "cat file.txt | grep pattern", False, "pipe to cmd (allowed)"),
        ("check_read.py", "tail -f /var/log/syslog", False, "tail -f follow (allowed)"),
        ("check_read.py", "head -20 file.txt | wc -l", False, "head with pipe (allowed)"),
        ("check_edit.py", "sed -i 's/a/b/' file", True, "sed -i (blocked)"),
        ("check_multi_command.py", "cmd1 && cmd2", True, "&& chain (blocked)"),
        ("check_multi_command.py", "cd /tmp && ls", False, "cd && cmd (allowed)"),
        ("check_multi_command.py", "git status", False, "single cmd (allowed)"),
        ("check_multi_command.py", 'cmd || echo "fallback"', False, "|| echo (allowed)"),
        # Python/venv tests
        ("check_python.py", "../.venv/bin/python test.py", True, "../.venv path (blocked)"),
        ("check_python.py", ".venv/bin/python test.py", False, "relative .venv (allowed)"),
        ("check_python.py", f"source {home}/project/.venv/bin/activate", True, "absolute venv source (blocked)"),
        ("check_python.py", "source .venv/bin/activate", False, "relative venv source (allowed)"),
        # Absolute path tests
        ("check_absolute_paths.py", f"python {home}/project/script.py", True, "absolute home path (blocked)"),
        ("check_absolute_paths.py", "python script.py", False, "relative path (allowed)"),
        ("check_absolute_paths.py", "cat /tmp/log.txt", False, "/tmp path (allowed)"),
        ("check_absolute_paths.py", f"{home}/.venv/bin/python manage.py", True, "absolute venv python (blocked)"),
        ("check_absolute_paths.py", ".venv/bin/python manage.py", False, "relative venv python (allowed)"),
    ]

    passed = failed = 0
    print("Individual module tests:")
    for module, cmd, should_block, desc in module_tests:
        status, description, blocked = test_module(module, cmd, should_block, desc)
        result = "blocked" if blocked else "allowed"
        print(f"  [{status}] {module}: {desc} -> {result}")
        if status == "PASS":
            passed += 1
        else:
            failed += 1

    # Full cmd_checker tests
    full_tests = [
        ("git status", False, "git status (allowed)"),
        ("ls -la", False, "ls (allowed)"),
        ("echo hello > file.txt", True, "write pattern (blocked)"),
        ("grep pattern file", False, "single grep (allowed)"),
        ("cmd1 && cmd2", True, "multi-cmd (blocked)"),
        ('tail -50 /tmp/debug.log 2>/dev/null || echo "No log found"', False, "|| echo fallback (allowed)"),
        ("cat file.txt | head -10", False, "pipe chain (allowed)"),
        ("tail -f /var/log/app.log", False, "tail -f follow (allowed)"),
    ]

    print("\nFull cmd_checker tests:")
    for cmd, should_block, desc in full_tests:
        status, description, blocked = test_full_checker(cmd, should_block, desc)
        result = "blocked" if blocked else "allowed"
        print(f"  [{status}] {desc} -> {result}")
        if status == "PASS":
            passed += 1
        else:
            failed += 1

    print(f"\nResults: {passed} passed, {failed} failed")
    return 0 if failed == 0 else 1


if __name__ == "__main__":
    sys.exit(main())
