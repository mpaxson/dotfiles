#!/usr/bin/env python3
"""
Check for Python/venv command patterns that may not work correctly in worktrees.

Validates that:
1. Relative .venv paths are used (portable across main repo and worktrees)
2. Absolute venv paths match the current working directory context
3. source .venv/bin/activate uses relative path format
"""

import sys
import os
import json
import re

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from common import block_command

# Patterns to detect problematic venv usage

# Absolute path to main repo venv when we might be in a worktree
# e.g., /home/kettle/git_repos/website/.venv/bin/python when in .worktrees/feature/
MAIN_REPO_VENV_PATTERN = re.compile(
    r'(/home/[^/]+/git_repos/[^/]+)/\.venv/bin/(python|activate|pip|invoke|inv)'
)

# Using ../venv paths (usually wrong)
PARENT_VENV_PATTERN = re.compile(
    r'\.\./.venv/bin/(python|activate|pip|invoke|inv)'
)

# source with absolute path to venv
SOURCE_ABSOLUTE_VENV = re.compile(
    r'source\s+(/[^\s]+)/\.venv/bin/activate'
)


def check(command: str, cwd: str = None) -> None:
    """
    Check command for problematic Python/venv patterns.

    Args:
        command: The bash command to check
        cwd: Current working directory (optional, for context)
    """
    command = command.strip()

    # Check for parent directory venv access (../. venv)
    if PARENT_VENV_PATTERN.search(command):
        block_command(
            title="Parent directory venv access detected",
            pattern_name="../.venv/bin/*",
            command=command,
            problem="Using '../.venv' is fragile and depends on current directory",
            solution="Use '.venv/bin/...' (from project root) or full absolute path",
            tool_name="Bash",
            extra_lines=[
                "",
                "Suggestions:",
                "  - cd to project root first, then use .venv/bin/python",
                "  - Use full path: /path/to/project/.venv/bin/python",
                "",
                "For worktrees, ensure you're using the worktree's own .venv:",
                "  cd /path/to/.worktrees/feature && .venv/bin/python ...",
            ]
        )

    # Check for source with absolute path (suggest relative)
    match = SOURCE_ABSOLUTE_VENV.search(command)
    if match:
        abs_path = match.group(1)
        # Only warn if it looks like a main repo path that might not match worktree
        if '.worktrees' not in abs_path:
            # This is pointing to main repo - might be wrong if in worktree
            lines = [
                "",
                "Suggestion: Use relative path for portability",
                "  source .venv/bin/activate",
                "",
                "Or if you need absolute path in a worktree:",
                f"  source {abs_path}/.worktrees/<name>/.venv/bin/activate",
                "",
                "Relative paths work from any project root (main or worktree).",
            ]
            block_command(
                title="Absolute venv activation path detected",
                pattern_name="source /abs/path/.venv/bin/activate",
                command=command,
                problem="Absolute paths to main repo venv won't work in worktrees",
                solution="Use relative path: source .venv/bin/activate",
                tool_name="Bash",
                extra_lines=lines
            )


if __name__ == "__main__":
    try:
        data = json.loads(sys.stdin.read())
        command = data.get("tool_input", {}).get("command", "")
        # Get cwd if available from session context
        cwd = data.get("cwd", None)
        if command:
            check(command, cwd)
    except SystemExit:
        raise  # Re-raise sys.exit()
    except Exception:
        pass
    sys.exit(0)
