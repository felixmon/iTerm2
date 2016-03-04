#!/bin/bash

# Save the tty's state.
saved_stty=$(stty -g)

# Trap ^C to fix the tty.
trap ctrl_c INT

function ctrl_c() {
  stty "$saved_stty"
  exit 1
}

# Read some bytes from stdin. Pass the number as the first argument.
function read_bytes()
{
  numbytes=$1
  dd bs=1 count=$numbytes 2>/dev/null
}

function read_dsr() {
  # Reading response to DSR, presuming ESC [ has already been read.
  dsr=""
  byte=$(read_bytes 1)
  while [ "${byte}" != "n" ]; do
    dsr=${dsr}${byte}
    byte=$(read_bytes 1)
  done
  echo ${dsr}
}

# Extract the terminal name from DSR 1337
function terminal {
  echo -n "$1" | sed -e 's/ .*//'
}

# Extract the version number from DSR 1337
function version {
  echo -n "$1" | sed -e 's/.* //'
}

# Enter raw mode and turn off echo so the terminal and I can chat quietly.
stty -echo -icanon raw

# Support for the extension first appears in this version of iTerm2:
MIN_VERSION=2.9.20160304
if [ $# -eq 1 ]; then
  MIN_VERSION=$1
fi

# Send iTerm2-proprietary code. Other terminals ought to ignore it (but are
# free to use it respectfully).  The response won't start with a 0 so we can
# distinguish it from the response to DSR 5. It should contain the terminal's
# name followed by a space followed by its version number and be terminated
# with an n.
echo -n '[1337n'

# Report device status. Responds with esc [ 0 n. All terminals support this. We
# do this because if the terminal will not respond to iTerm2's custom escape
# sequence, we can still read from stdin without blocking indefinitely.
echo -n '[5n'

# Read esc [, which either iTerm2 or any VT100-compatible terminal will send.
byte=$(read_bytes 2)

version_string=$(read_dsr)
if [ "${version_string}" != "0" ]; then
  # Already read DSR 1337. Read DSR 5 and throw it away..
  dsr=$(read_dsr)
else
  # Terminal didn't respond to the DSR 1337. The response we read from from DSR 5.
  version_string=""
fi

# Restore the terminal to cooked mode.
stty "$saved_stty"

version=$(version "${version_string}")
term=$(terminal "${version_string}")
test "$term" = ITERM2 -a \( "$version" \> "$MIN_VERSION" -o "$version" = "$MIN_VERSION" \)
