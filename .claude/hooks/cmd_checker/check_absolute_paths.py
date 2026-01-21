#!/usr/bin/env python3
"""
Check for absolute paths in home directory that should use relative paths.

Blocks commands containing /home/<user>/... paths (except /tmp) and
suggests using relative paths from the project or worktree directory.
"""

import sys
import os
import json
import re
from pathlib import Path

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from common import block_command

# Get user's home directory
HOME_DIR = str(Path.home())

# Pattern to find absolute paths starting with home directory
HOME_PATH_PATTERN = re.compile(
    rf'({re.escape(HOME_DIR)}/[^\s\'";&|><]+)'
)

# Allowed absolute path prefixes (won't be blocked)
ALLOWED_PREFIXES = [
    '/tmp/',
    '/tmp',
]


def get_relative_path(abs_path: str, cwd: str) -> str:
    """Convert absolute path to relative path from cwd."""
    try:
        return os.path.relpath(abs_path, cwd)
    except ValueError:
        return abs_path


def check(command: str, session_cwd: str = None) -> None:
    """
    Check command for absolute home directory paths.

    Args:
        command: The bash command to check
        session_cwd: Current working directory of the session
    """
    command = command.strip()

    # Find all absolute paths in the command
    matches = HOME_PATH_PATTERN.findall(command)

    if not matches:
        return

    # Filter out allowed paths
    problematic_paths = []
    for path in matches:
        is_allowed = any(path.startswith(prefix) for prefix in ALLOWED_PREFIXES)
        if not is_allowed:
            problematic_paths.append(path)

    if not problematic_paths:
        return

    # Build suggested command
    suggested_command = command
    if session_cwd:
        for abs_path in problematic_paths:
            rel_path = get_relative_path(abs_path, session_cwd)
            suggested_command = suggested_command.replace(abs_path, rel_path)

    # Compact output
    output = f"""BLOCKED: Use relative paths instead of absolute paths.

Use: {suggested_command[:150]}

Worktree? cd .worktrees/<name> && <command>"""

    print(output, file=sys.stderr)
    sys.exit(2)


if __name__ == "__main__":
    try:
        data = json.loads(sys.stdin.read())
        command = data.get("tool_input", {}).get("command", "")
        session_cwd = data.get("session_cwd", None)
        if command:
            check(command, session_cwd)
    except SystemExit:
        raise  # Re-raise sys.exit()
    except Exception:
        pass
    sys.exit(0)
