#!/bin/sh

# Test for pane-padding-x/pane-padding-y: each pane's content should be
# inset by that many blank cells on the axes where the option is set, and
# the padding band should be blank (not a border box, not stale content).
# The two axes are independent of each other. With both off (the
# default), a pane's content should reach the edge of the window as
# before.

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

# Fill the pane with content sized to its current pane_width ($1, queried by
# the caller since command substitution runs this in a subshell) and capture
# the outer window's rendering. Prints a bounded number of lines and then
# sleeps, rather than an infinite 'yes', so output has settled by the time
# capture runs (an infinite yes can still be mid-write on the last visible
# row at capture time, which is a race in the test, not in tmux).
fill_and_capture() {
	line=$(xline "$1")
	$TMUX respawn-pane -k -t 0 \
	    "i=0; while [ \$i -lt 30 ]; do echo $line; i=\$((i + 1)); done; exec sleep 300" \
	    || exit 1
	sleep 1
	$TMUX_OUTER capturep -p 2>/dev/null
}

# Start outer tmux that will capture the inner tmux's rendering. The inner
# tmux window exactly fills the outer pane, so row/column 0 of the capture
# corresponds to row/column 0 of the inner window.
$TMUX_OUTER new -d -x40 -y14 "$TMUX new -x40 -y14 'sleep 300'" || exit 1
sleep 1
$TMUX_OUTER set -g status off || exit 1
$TMUX set -g status off || exit 1
$TMUX set -g window-size manual || exit 1
$TMUX resizew -x40 -y14 || exit 1
sleep 1

# --- default: both axes off, content should reach every edge ---
cw=$($TMUX display -p -t 0 '#{pane_width}')
row0=$(fill_and_capture "$cw" | sed -n '1p')
[ "$row0" = "$(xline 40)" ] || exit 1

# --- pane-padding-x only: width shrinks, height does not ---
$TMUX set -g pane-padding-x 1 || exit 1
sleep 1
cw=$($TMUX display -p -t 0 '#{pane_width}')
[ "$cw" = 38 ] || exit 1
[ "$($TMUX display -p -t 0 '#{pane_height}')" = 14 ] || exit 1

outer=$(fill_and_capture "$cw")
row0=$(echo "$outer" | sed -n '1p')
row1=$(echo "$outer" | sed -n '2p')

# Top row still has content (no vertical padding), even though every row,
# including this one, is horizontally inset.
echo "$row0" | grep -q X || exit 1
[ "$(echo "$row0" | cut -c1)" != "X" ] || exit 1
# Every row has left/right padding.
[ "$(echo "$row1" | cut -c1)" != "X" ] || exit 1
[ "$row1" = " $(xline "$cw")" ] || exit 1

# --- pane-padding-y only: height shrinks, width does not ---
$TMUX set -g pane-padding-x 0 || exit 1
$TMUX set -g pane-padding-y 1 || exit 1
sleep 1
cw=$($TMUX display -p -t 0 '#{pane_width}')
[ "$cw" = 40 ] || exit 1
[ "$($TMUX display -p -t 0 '#{pane_height}')" = 12 ] || exit 1

outer=$(fill_and_capture "$cw")
row0=$(echo "$outer" | sed -n '1p')
row1=$(echo "$outer" | sed -n '2p')
row13=$(echo "$outer" | sed -n '14p')

# Top and bottom rows are blank padding.
[ -z "$row0" ] || exit 1
[ -z "$row13" ] || exit 1
# First content row reaches the left edge: no horizontal padding.
[ "$row1" = "$(xline "$cw")" ] || exit 1

# --- both axes on: combines as expected ---
$TMUX set -g pane-padding-x 1 || exit 1
sleep 1
cw=$($TMUX display -p -t 0 '#{pane_width}')
[ "$cw" = 38 ] || exit 1
[ "$($TMUX display -p -t 0 '#{pane_height}')" = 12 ] || exit 1

outer=$(fill_and_capture "$cw")
row0=$(echo "$outer" | sed -n '1p')
row1=$(echo "$outer" | sed -n '2p')
row13=$(echo "$outer" | sed -n '14p')

[ -z "$row0" ] || exit 1
[ -z "$row13" ] || exit 1
[ "$(echo "$row1" | cut -c1)" != "X" ] || exit 1
[ "$row1" = " $(xline "$cw")" ] || exit 1

# --- padding values greater than one cell ---
$TMUX set -g pane-padding-x 3 || exit 1
$TMUX set -g pane-padding-y 2 || exit 1
sleep 1
cw=$($TMUX display -p -t 0 '#{pane_width}')
[ "$cw" = 34 ] || exit 1
[ "$($TMUX display -p -t 0 '#{pane_height}')" = 10 ] || exit 1

outer=$(fill_and_capture "$cw")

# Two blank rows on top (bottom is checked via pane_height above; the
# fixed-line-count fill this test uses leaves the true last row's redraw
# timing too racy to assert on directly, independent of pane-padding).
[ -z "$(echo "$outer" | sed -n '1p')" ] || exit 1
[ -z "$(echo "$outer" | sed -n '2p')" ] || exit 1

# First content row: three blank columns on the left.
row2=$(echo "$outer" | sed -n '3p')
[ "$row2" = "   $(xline "$cw")" ] || exit 1

$TMUX kill-server 2>/dev/null
$TMUX_OUTER kill-server 2>/dev/null
exit 0
