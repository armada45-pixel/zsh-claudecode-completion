# Top half of demo.gif: flags and their values.
# Record both halves with scripts/record-demo.sh (needs Docker).
Output assets/demo-top.mp4

Set Shell zsh
Set FontSize 16
Set Width 1000
Set Height 290
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
Type@94ms "claude " Sleep 400ms Tab Sleep 3s

Type@60ms "--model " Sleep 400ms Tab Sleep 3s

Backspace@110ms 6 Sleep 200ms
Type@129ms "resume " Sleep 400ms Tab Sleep 3s

Backspace@69ms 7 Sleep 200ms
Type@70ms "agent " Sleep 400ms Tab Sleep 3s
