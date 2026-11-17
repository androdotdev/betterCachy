import shutil
import subprocess


def have(*names: str) -> bool:
    return any(shutil.which(n) for n in names)


def run(cmd, timeout: float = 20, cwd=None, env=None):
    """Run a command, never raise. Returns (returncode, stdout, stderr)."""
    try:
        proc = subprocess.run(
            cmd, capture_output=True, text=True, timeout=timeout, cwd=cwd, env=env
        )
        return proc.returncode, proc.stdout, proc.stderr
    except FileNotFoundError:
        return 127, "", f"command not found: {cmd[0]}"
    except subprocess.TimeoutExpired:
        return 124, "", f"timed out after {timeout:.0f}s: {' '.join(map(str, cmd))}"
    except Exception as error:  # noqa: BLE001
        return 1, "", repr(error)
