# Simple DAM Hook Examples

## Hook Directory Structure
```
~/.config/dam/
├── help/
│   └── default              # Help text (replaces built-in help)
├── pre/
│   ├── default              # Global pre-hook (runs before attach/create)
│   ├── myserver             # Default for myserver host
│   └── myserver/
│       └── dev              # Specific to myserver/dev session
├── setup/
│   ├── default              # Global setup-hook (runs only for new sessions)
│   └── myserver/
│       └── dev              # Specific session setup
└── post/
    ├── default              # Global post-hook (runs after detach/exit)
    └── localhost/
        └── work             # Specific to localhost/work session
```

## Example Hooks

### Help Hook (Required for `dam help`)
**`~/.config/dam/help/default`**
```bash
#!/bin/bash
cat << 'EOF'
# DAM - Display Attach Manager
Attach to tmux sessions locally or remotely, with optional hooks for automation.

## BASIC USE
dam`                    # attach to 'mine' session locally
dam work`               # attach to 'work' session locally  
dam host/`              # attach to 'mine' session on 'host'
dam host/deploy`        # attach to 'deploy' session on 'host'

Use `<tab>` completion to see available sessions and hosts.

## HOOKS (optional automation)
Put executable scripts in `~/.config/dam/{help,pre,post}/` to run:

**Hook locations (first found wins):**
- `~/.config/dam/pre/myhost/work` - specific to myhost/work session
- `~/.config/dam/pre/myhost`      - default for myhost  
- `~/.config/dam/pre/default`     - global default

**Hook types:**
- `help/` - runs for `dam -h` or `dam --help` (this text!)
- `pre/` - runs before attach/create (always)
- `setup/` - runs only after creating new sessions (before attach)
- `post/` - runs after detach/exit (always)

**Hook arguments:** `$1=host $2=session` (help gets `$1="dam" $2=""`)

**Example:** Create `~/.config/dam/pre/default` to set terminal title:
```bash
#!/bin/bash
[[ "$1" == "dam" ]] && return  # Skip for help
printf '\033]0;DAM: %s/%s\007' "$1" "$2"
```

That's it. Happy tmuxing!
EOF
```

### Global Pre-Hook (Terminal Title)
**`~/.config/dam/pre/default`**
```bash
#!/bin/bash
printf '\033]0;DAM: %s/%s\007' "$1" "$2"
```

### Session Setup After Creation
**`~/.config/dam/setup/myserver/dev`**
```bash
#!/bin/bash
# Configure new dev sessions - runs after creation, before user attaches
if [[ "$1" == "$HOSTNAME" ]]; then
    tmux rename-window -t "$2:0" 'code'
    tmux new-window -t "$2" -n 'server' -c '~/project'
    tmux new-window -t "$2" -n 'tests' -c '~/project'
    tmux select-window -t "$2:code"
else
    ssh "$1" "
        tmux rename-window -t '$2:0' 'code'
        tmux new-window -t '$2' -n 'server' -c '~/project'
        tmux new-window -t '$2' -n 'tests' -c '~/project'
        tmux select-window -t '$2:code'
    "
fi
```

### Work Session Cleanup
**`~/.config/dam/post/localhost/work`**
```bash
#!/bin/bash
# Clean up work environment
pkill -f "work-specific-daemon" 2>/dev/null || true
printf '\033]0;Terminal\007'  # Reset title
```

### Global Logging
**`~/.config/dam/post/default`**
```bash
#!/bin/bash
echo "$(date '+%Y-%m-%d %H:%M:%S') - Detached from $1/$2" >> ~/.dam.log
```

## Usage

1. **Make hooks executable:**
   ```bash
   chmod +x ~/.config/dam/pre/default
   chmod +x ~/.config/dam/pre/myserver/dev
   # etc.
   ```

2. **Use DAM normally:**
   ```bash
   dam myserver/dev  # Runs pre-hook, attaches/creates, runs post-hook on exit
   ```

3. **Get help:**
   ```bash
   dam help
   ```

The hook system is completely optional - DAM works exactly as before if no hooks exist.
