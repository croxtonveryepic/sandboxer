"""Switch between Claude Code accounts by swapping credential files."""

import argparse
import json
import os
import platform
import subprocess
import sys
import tempfile
from datetime import datetime, timezone
from pathlib import Path

CLAUDE_DIR = Path.home() / ".claude"
CREDENTIALS_FILE = CLAUDE_DIR / ".credentials.json"
ACCOUNT_FILE = CLAUDE_DIR / ".account.json"
PROFILES_DIR = CLAUDE_DIR / "profiles"


def read_json(path):
    try:
        return json.loads(path.read_text("utf-8"))
    except FileNotFoundError:
        print(f"Error: {path} not found. Are you logged into Claude Code?")
        sys.exit(1)
    except json.JSONDecodeError:
        print(f"Error: {path} contains invalid JSON.")
        sys.exit(1)


def write_json_atomic(path, data):
    """Write JSON atomically via temp file + os.replace."""
    path.parent.mkdir(parents=True, exist_ok=True)
    fd, tmp = tempfile.mkstemp(dir=path.parent, suffix=".tmp")
    try:
        with os.fdopen(fd, "w", encoding="utf-8") as f:
            json.dump(data, f, indent=2)
        os.replace(tmp, path)
    except Exception:
        os.unlink(tmp)
        raise


def load_profile(name):
    path = PROFILES_DIR / f"{name}.json"
    if not path.exists():
        print(f"Error: Profile '{name}' not found.")
        print(f"Available profiles: {', '.join(list_profile_names()) or '(none)'}")
        sys.exit(1)
    return json.loads(path.read_text("utf-8"))


def list_profile_names():
    if not PROFILES_DIR.exists():
        return []
    return sorted(p.stem for p in PROFILES_DIR.glob("*.json"))


def get_active_refresh_token():
    if not CREDENTIALS_FILE.exists():
        return None
    creds = json.loads(CREDENTIALS_FILE.read_text("utf-8"))
    return creds.get("claudeAiOauth", {}).get("refreshToken")


def check_running_claude() -> bool:
    """Return True if claude processes are running (besides this script).

    Skipped entirely inside Sandboxer containers (BOXER_CONTAINER=true).
    Uses platform-appropriate detection: tasklist on Windows, pgrep on Linux/macOS.
    """
    if os.environ.get("BOXER_CONTAINER") == "true":
        return False

    try:
        if platform.system() == "Windows":
            result = subprocess.run(
                ["tasklist", "/FI", "IMAGENAME eq claude.exe", "/FO", "CSV", "/NH"],
                capture_output=True, text=True, timeout=5,
            )
            for line in result.stdout.strip().splitlines():
                if "claude.exe" in line.lower():
                    return True
        else:
            result = subprocess.run(
                ["pgrep", "-x", "claude"],
                capture_output=True, text=True, timeout=5,
            )
            if result.returncode == 0 and result.stdout.strip():
                return True
    except (subprocess.TimeoutExpired, FileNotFoundError):
        pass
    return False


def cmd_save(args):
    name = args.name
    profile_path = PROFILES_DIR / f"{name}.json"

    if profile_path.exists() and not args.overwrite:
        existing = json.loads(profile_path.read_text("utf-8"))
        print(f"Profile '{name}' already exists ({existing.get('email', '?')}).")
        print("Use --overwrite to replace it.")
        sys.exit(1)

    creds = read_json(CREDENTIALS_FILE)
    account = read_json(ACCOUNT_FILE)

    oauth = creds.get("claudeAiOauth")
    if not oauth:
        print("Error: No claudeAiOauth found in credentials. Are you logged in?")
        sys.exit(1)

    acct_info = account.get("account", {})
    org_info = account.get("organization", {})

    profile = {
        "name": name,
        "email": acct_info.get("email", "unknown"),
        "org": org_info.get("name", "unknown"),
        "subscription_type": oauth.get("subscriptionType", "unknown"),
        "saved_at": datetime.now(timezone.utc).isoformat(),
        "claude_ai_oauth": oauth,
        "account": account,
    }

    write_json_atomic(profile_path, profile)
    print(f"Saved profile '{name}':")
    print(f"  Email: {profile['email']}")
    print(f"  Org:   {profile['org']}")
    print(f"  Type:  {profile['subscription_type']}")


def cmd_use(args):
    name = args.name
    profile = load_profile(name)

    # Check if already on this profile
    active_token = get_active_refresh_token()
    profile_token = profile["claude_ai_oauth"].get("refreshToken")
    if active_token and active_token == profile_token:
        print(f"Already on profile '{name}' ({profile['email']}).")
        return

    # Warn about running sessions
    if check_running_claude() and not args.force:
        print("Warning: Claude Code appears to be running.")
        print("Exit all Claude Code sessions first, or use --force to switch anyway.")
        sys.exit(1)

    # Read current credentials to preserve mcpOAuth
    current_creds = {}
    if CREDENTIALS_FILE.exists():
        try:
            current_creds = json.loads(CREDENTIALS_FILE.read_text("utf-8"))
        except json.JSONDecodeError:
            pass

    # Swap only claudeAiOauth, keep everything else
    current_creds["claudeAiOauth"] = profile["claude_ai_oauth"]
    write_json_atomic(CREDENTIALS_FILE, current_creds)
    write_json_atomic(ACCOUNT_FILE, profile["account"])

    print(f"Switched to '{name}':")
    print(f"  Email: {profile['email']}")
    print(f"  Org:   {profile['org']}")
    print(f"  Type:  {profile['subscription_type']}")


def cmd_status(args):
    active_token = get_active_refresh_token()
    profiles = list_profile_names()

    if not profiles:
        print("No profiles saved. Use 'save <name>' to capture the current account.")
        return

    # Determine active profile by matching refresh token
    active_name = None
    for name in profiles:
        p = json.loads((PROFILES_DIR / f"{name}.json").read_text("utf-8"))
        if p["claude_ai_oauth"].get("refreshToken") == active_token:
            active_name = name
            break

    print("Profiles:")
    for name in profiles:
        p = json.loads((PROFILES_DIR / f"{name}.json").read_text("utf-8"))
        marker = " *" if name == active_name else "  "
        print(f"{marker} {name:12s}  {p['email']:40s}  {p['subscription_type']}")

    if active_name:
        print(f"\nActive: {active_name}")
    else:
        print("\nActive: (no matching profile)")


def main():
    parser = argparse.ArgumentParser(
        prog="claude-switch",
        description="Switch between Claude Code accounts.",
    )
    sub = parser.add_subparsers(dest="command")

    p_save = sub.add_parser("save", help="Capture current account as a named profile")
    p_save.add_argument("name", help="Profile name (e.g. 'work', 'personal')")
    p_save.add_argument("--overwrite", action="store_true", help="Overwrite existing profile")

    p_use = sub.add_parser("use", help="Switch to a named profile")
    p_use.add_argument("name", help="Profile name to switch to")
    p_use.add_argument("--force", action="store_true", help="Switch even if Claude is running")

    sub.add_parser("status", help="Show active account and all profiles")

    args = parser.parse_args()

    if args.command == "save":
        cmd_save(args)
    elif args.command == "use":
        cmd_use(args)
    elif args.command == "status":
        cmd_status(args)
    else:
        parser.print_help()


if __name__ == "__main__":
    main()
