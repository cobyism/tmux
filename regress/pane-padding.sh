#!/bin/sh

# Test for pane-padding: with the option set, each pane's content should be
# inset by one blank cell on all sides, and the padding band should be
# blank (not a border box, not stale content). With the option off (the
# default), a pane's content should reach the edge of the window as before.

PATH=/bin:/usr/bin
TERM=screen

[ -z "$TEST_TMUX" ] && TEST_TMUX=$(readlink -f ../tmux)
TMUX="$TEST_TMUX -LtestA$$ -f/dev/null"
$TMUX kill-server 2>/dev/null
TMUX_OUTER="$TEST_TMUX -LtestB$$ -f/dev/null"
$TMUX_OUTER kill-server 2>/dev/null

trap "$TMUX kill-server 2>/dev/null; $TMUX_OUTER kill-server 2>/dev/null" 0 1 15

# A line of exactly $1 'X' characters, so it fills a row of that width
# without wrapping ambiguity.
xline() {
	printf 'X%.0s' $(seq 1 "$1")
}

# Start outer tmux that will capture the inner tmux's rendering. The inner
# tmux window exactly fills the outer pane, so row/column 0 of the capture
# corresponds to row/column 0 of the inner window.
$TMUX_OUTER new -d -x40 -y14 "$TMUX new -x40 -y14 'sleep 300'" || exit 1
sleep 1
$TMUX_OUTER set -g status off || exit 1
$TMUX set -g status off || exit 1
sleep 1

# --- default: pane-padding off, content should reach every edge ---
cw=$($TMUX display -p -t 0 '#{pane_width}')
$TMUX respawn-pane -k -t 0 "yes $(xline "$cw")" || exit 1
sleep 1

row0=$($TMUX_OUTER capturep -p 2>/dev/null | sed -n '1p')
[ "$row0" = "$(xline 40)" ] || exit 1

# --- pane-padding on: content should shrink and the padding band must be
# blank ---
$TMUX set -g pane-padding 1 || exit 1
sleep 1

cw=$($TMUX display -p -t 0 '#{pane_width}')
[ "$cw" = 38 ] || exit 1
$TMUX respawn-pane -k -t 0 "yes $(xline "$cw")" || exit 1
sleep 1

outer=$($TMUX_OUTER capturep -p 2>/dev/null)
row0=$(echo "$outer" | sed -n '1p')
row1=$(echo "$outer" | sed -n '2p')
row13=$(echo "$outer" | sed -n '14p')

# Top and bottom padding rows: no content at all.
[ -z "$row0" ] || exit 1
[ -z "$row13" ] || exit 1

# First content row: one blank cell on the left, then content, and the row
# ends well short of the window width (proving the right edge is blank
# too, since capture-pane trims trailing blanks).
[ "$(echo "$row1" | cut -c1)" != "X" ] || exit 1
[ "$row1" = " $(xline "$cw")" ] || exit 1

$TMUX kill-server 2>/dev/null
$TMUX_OUTER kill-server 2>/dev/null
exit 0
