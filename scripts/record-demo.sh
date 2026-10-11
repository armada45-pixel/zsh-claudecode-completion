#!/bin/bash
#
# Re-record assets/demo.gif with VHS in Docker: assets/demo-top.tape and
# assets/demo-bottom.tape are recorded one after the other, stacked, and
# given a playhead along the bottom edge. The recordings use the fake data
# from assets/demo-setup.zsh.

set -e
cd "$(dirname "${BASH_SOURCE[0]}")/.."

docker run --rm -i -v "$PWD:/vhs" -e OWNER="$(id -u):$(id -g)" \
    --entrypoint sh ghcr.io/charmbracelet/vhs -s <<'EOF'
set -e
apt-get update -qq && apt-get install -y -qq zsh jq >/dev/null
vhs assets/demo-top.tape
vhs assets/demo-bottom.tape

# Both halves hold their last frame for 3 seconds and the shorter one ends
# the GIF; $d is that length, for the playhead to cross the width in.
d=$(for f in assets/demo-top.mp4 assets/demo-bottom.mp4; do
      ffprobe -v error -show_entries format=duration -of csv=p=0 $f
    done | sort -n | awk 'NR == 1 { print $1 + 3 }')

ffmpeg -v error -y -i assets/demo-top.mp4 -i assets/demo-bottom.mp4 -filter_complex "
  [0]tpad=stop_mode=clone:stop_duration=3[top];
  [1]tpad=stop_mode=clone:stop_duration=3,pad=iw:ih+2:0:2:color=0x585b70[bottom];
  [top][bottom]vstack=shortest=1,pad=iw:ih+14:0:0:color=0x1e1e2e,
    drawbox=x=0:y=ih-8:w=iw:h=2:color=0x45475a:t=fill[panes];
  color=c=0xf9e2af:s=1000x2[played];
  color=c=0xf9e2af:s=4x10[head];
  [panes][played]overlay=x='-w+W*t/$d':y=H-8:shortest=1[bar];
  [bar][head]overlay=x='(W-w)*t/$d':y=H-12:shortest=1,fps=20,split[a][b];
  [a]palettegen=max_colors=64[p];[b][p]paletteuse=dither=none" assets/demo.gif

rm -f assets/demo-top.mp4 assets/demo-bottom.mp4
chown "$OWNER" assets/demo.gif
EOF
