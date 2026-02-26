# Quick Start for Working with Claude

## Setup (One Time)

```bash
# 1. Source aliases in your shell profile
echo 'source ~/Documents/code/ayllu-app/.aliases' >> ~/.zshrc
source ~/.zshrc

# 2. Test the setup
make help
```

## Daily Workflow

### When Claude creates new files:

```bash
make regenerate   # or: xcode-regen
```

### When builds fail with package errors:

```bash
make reset        # or: ayllu-reset
```

### Before committing:

SwiftLint runs automatically! But you can check manually:

```bash
make lint         # or: ayllu-lint
make format       # Auto-fix issues
```

## Enable GUI Automation (Optional)

For Claude to automate Xcode tasks:

**System Settings → Privacy & Security → Accessibility → Add Terminal**

## That's It!

See [DEVELOPER_SETUP.md](./DEVELOPER_SETUP.md) for full details.
