#!/bin/bash

# script options
shopt -s extglob
set -e
set -u

## Globals
main_dir='/opt/osbkup'
log_dir="${main_dir}/logs"
archive_body="${main_dir}/archive_body"
archive_log="${main_dir}/archive.log"
[[ -f "$archive_body" ]] && >"$archive_body"
[[ -f "$archive_log" ]] && >"$archive_log"
[[ -d "$log_dir" ]] || mkdir -p "$log_dir"


## BEGIN FUNCTIONS 
mytee () { 

    tee -a "$archive_body" "$archive_log" 

}

reset_vars () {

    source_base=
    target_base=
    dirs_file=
    mtime_days=
    report_mode=

} 

main_menu () {

reset_vars || exit 1

clear

cat <<-EOT

*************************************************************

    Main Menu:

    1. Use default settings
    2. Use custom settings

    9. Exit

*************************************************************

EOT

echo
read -n 1 -p "Please select a choice from above: " main_menu_choice
echo

eval_main_menu_choice

}


eval_main_menu_choice () {

    case "$main_menu_choice" in

        1) # use default settings
            target_base='/Volumes/Drobo/OSArchive'
            dirs_file="${main_dir}/default_dirs.txt"
            mtime_days=730
            ;;

        2) # collect and use custom settings

            until [[ -r "$dirs_file" ]]; do read -rp "Enter full path to a file containing directories to archive (newline separated)? " dirs_file; done

            until [[ -d "$target_base" && -w "$target_base" ]]; do
                read -p "Target base directory to archive to (full path, should be writeable): " target_base;
            done

            while [[ "$mtime_days" = *[!0-9]* || "$mtime_days" = "" ]]; do read -p "Archive threshold (in days)? " mtime_days; done
            ;;

        9) # Exit
            exit 0
            ;;

        *) # all else
           main_menu 

    esac
            
    until [[ "$report_mode" = @(yes|no) ]]; do read -p "Run in Report-only mode (yes/no)? " report_mode; done

    validate_params

}


validate_params () {

clear

cat <<-EOT

*************************************************************

--- SETTINGS ---

Report Mode: ${report_mode}

Directories to Archive:
$(cat "$dirs_file")

Target Base: ${target_base}

Threshold (in days): ${mtime_days}

*************************************************************

EOT

read -n 1 -p "Confirm Settings (y/n)?" confirm_settings
[[ "$confirm_settings" = "y" ]] || main_menu

run_script

}


do_my_bidding () {

        mkdir -p "$target_dir" \
        && mv "$file" "$target_dir" \
        && chmod 0444 "$target_file" \
        && ln -s "$target_file" "$source_dir"

}

## END FUNCTIONS


## RUN SCRIPT ##
main_menu
