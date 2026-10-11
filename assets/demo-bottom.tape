# Bottom half of demo.gif: subcommands and their arguments.
# Record both halves with scripts/record-demo.sh (needs Docker).
Output assets/demo-bottom.mp4

Set Shell zsh
Set FontSize 16
Set Width 1000
Set Height 340
Set Padding 16
Set Theme "Catppuccin Mocha"
Set TypingSpeed 60ms
Env LC_ALL "C.UTF-8"

Hide
Type "source assets/demo-setup.zsh" Enter
Sleep 2s
Show

# Each step deletes only what differs from the previous command. The
# per-key speeds are set so that deleting, typing and Tab start and end at
# the same moment as in the other half, which also keeps the two cursors
# blinking together.
Type@60ms "claude mcp " Sleep 400ms Tab Sleep 3s

Type@69ms "remove " Sleep 400ms Tab Sleep 3s

Backspace@60ms 11 Sleep 200ms
Type@60ms "plugin install " Sleep 400ms Tab Sleep 3s

Backspace@60ms 8 Sleep 200ms
Type@60ms "enable " Sleep 400ms Tab Sleep 3s
