# Developer Setup Guide

This guide helps you set up the Ayllu development environment for maximum efficiency.

## Quick Start

1. **Install dependencies** (if not already installed):
   ```bash
   brew install xcodegen swiftlint
   ```

2. **Source the aliases** (add to your `~/.zshrc` or `~/.bashrc`):
   ```bash
   source ~/Documents/code/ayllu-app/.aliases
   ```

3. **Regenerate the Xcode project**:
   ```bash
   make regenerate
   # or
   xcode-regen
   ```

4. **Open the project**:
   ```bash
   open Ayllu/Ayllu.xcodeproj
   ```

## Available Commands

### Using Make

```bash
make help           # Show all available commands
make clean          # Clean all build artifacts and caches
make regenerate     # Regenerate Xcode project from project.yml
make build          # Build the project
make test           # Run all tests
make lint           # Run SwiftLint
make format         # Auto-fix SwiftLint violations
make reset          # Clean everything and regenerate project
```

### Using Aliases

After sourcing `.aliases`:

```bash
xcode-clean         # Clean all Xcode and package caches
xcode-regen         # Regenerate project from project.yml
ayllu-lint          # Run SwiftLint in strict mode
ayllu-fix           # Auto-fix SwiftLint violations
ayllu-reset         # Clean and regenerate everything
```

## Development Workflow

### Adding New Files

When Claude (or you) creates new Swift files:

1. **Files are automatically included** - XcodeGen scans the `Ayllu/` directory
2. **Regenerate the project**:
   ```bash
   make regenerate
   ```
3. **No manual Xcode project file editing needed!**

### Before Committing

The pre-commit hook automatically runs SwiftLint on every commit. If you need to bypass it:

```bash
git commit --no-verify -m "Your message"
```

### When Build Fails with Package Errors

```bash
make clean          # Clean everything
make regenerate     # Regenerate project
```

Or use the shortcut:
```bash
make reset
```

## GUI Automation (Optional)

To enable Claude to automate Xcode tasks:

1. Open **System Settings** → **Privacy & Security** → **Accessibility**
2. Click the **+** button
3. Add your **Terminal** app (Terminal.app, iTerm, etc.)
4. Restart your terminal

This allows AppleScript automation of Xcode operations.

## Project Structure

```
ayllu-app/
├── Ayllu/
│   ├── project.yml          # XcodeGen project definition
│   ├── Ayllu.xcodeproj/     # Generated (do not edit manually)
│   ├── Ayllu/               # Source code (auto-scanned by XcodeGen)
│   └── .swiftlint.yml       # SwiftLint configuration
├── .git/hooks/
│   └── pre-commit           # Auto-runs SwiftLint
├── Makefile                 # Development commands
├── .aliases                 # Shell aliases
└── DEVELOPER_SETUP.md       # This file
```

## Troubleshooting

### "Cannot find XcodeGen"
```bash
brew install xcodegen
```

### "Pre-commit hook not running"
```bash
chmod +x .git/hooks/pre-commit
```

### "Build fails with MapLibre errors"
```bash
make clean
make regenerate
```

### "Project file has merge conflicts"
Never manually edit `project.pbxproj`. Instead:
1. Discard changes to `project.pbxproj`
2. Run `make regenerate`
3. Commit the regenerated file

## Benefits

✅ **No more manual project file editing**
✅ **No more pbxproj merge conflicts**
✅ **Automatic SwiftLint enforcement**
✅ **One-command cleanup for package issues**
✅ **Claude can work 10x faster**
