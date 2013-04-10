#!/bin/bash
set -u

# set globals
main_dir='/opt/osbkup'

# format for displaying time
gtime_format="Total Runtime: %E \nSwap Count: %W"

# runtime_file
runtime_tmp="$main_dir/runtime"
[[ -f "$runtime_tmp" ]] && >"$runtime_tmp"

# run command
/opt/local/bin/gtime --format="$gtime_format" -o "$runtime_tmp" /opt/osbkup/osbkup.sh && /opt/osbkup/osbkup_email.sh

#comment1
######comment2
