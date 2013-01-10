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
    email_report=

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
            dirs_file="${main_dir}/my_dirs.txt"
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
            
    until [[ "$report_mode" = @(yes|no) ]]; do read -p "Run in Report-only mode - No changes to the system will be made (yes/no)? " report_mode; done
    until [[ "$email_report" = @(yes|no) ]]; do read -p "Send email report (yes/no)? " email_report; done

    validate_params

}


validate_params () {

clear

cat <<-EOT

*************************************************************

Please confirm the following settings:

Directories to Archive:
$(cat "$dirs_file")

Target Base: ${target_base}

Threshold (in days): ${mtime_days}

Report Mode: ${report_mode}

Send Email Report: ${email_report}

*************************************************************

EOT

read -p "Confirm Settings (y/n)?" confirm_settings
[[ "$confirm_settings" = "y" ]] || main_menu

run_script

}


do_my_bidding () {

        mkdir -p "$target_dir" \
        && mv "$file" "$target_dir" \
        && chmod 0444 "$target_file" \
        && ln -s "$target_file" "$source_dir"

}

run_script () {

    begin_time=$(date "+%s")
# read in the text file containing the directories to archive, store in the array dirs_to_archive
    declare -a dirs_to_archive

    while IFS= read -r a_dir; do

        dirs_to_archive+=("$a_dir")

    done < "$dirs_file"


    # Set grandtotal (sum of space savings from ALL dirs) to 0
    grandtotal=0

    printf "Files not modified in the past %s days\n\n" "$mtime_days" | tee -a "$archive_body"
    printf '%-25s %-6s\n' "DIRECTORY" "SIZE" | tee -a "$archive_body"
    printf '%-25s %-6s\n' "---------" "----" | tee -a "$archive_body"

    # begin looping over dirs and processing
    for top_level_dir in "${dirs_to_archive[@]}"; do

        # set totalsize of dir space saved to 0
        totalsize=0

        # get dirname (source base)
        source_base="${top_level_dir%/*}"

        # get basename (naked) top level dir
        bn_dir="${top_level_dir##*/}"

        # set log file location for dir
        dir_log="${log_dir}/${bn_dir}.csv"

        # initialize log file for top level dir and print header
        [[ -f "$dir_log" ]] && >"$dir_log"
        printf 'filepath, file, extension,  owner, group, size, atime, mtime, ctime\n' | tee -a "$dir_log"

        # top banner for stdout on console
        printf "### BEGIN PROCESSING '%s' ###\n" "$top_level_dir"

        # read in the results of find, tally size, create target dir, mv file, make read only, create symlink
        while IFS= read -rd '' file; do

            # setup parameters for use inside loop, self explanatory.  Filepath_relative strips out leading /Volumes/9TB_SAN/New Structure...
            source_dir="${file%/*}"
            target_file="${target_base}/${file#"$source_base"}"
            target_dir="${target_file%/*}"
            filepath_relative="${file#"$source_base"}"
            filename_extension="${file##*.}"
            filename_bn="${file##*/}"


            # generate a parseable stat output for variable initialization
            stat_out="$(stat -t "%Y-%m-%d_%H:%M" "$file")"

            # read the output of stat_out into an array we can use to parse attributes
            read -r -a filemeta <<< "$stat_out"
            f_owner="${filemeta[4]}"
            f_group="${filemeta[5]}"
            f_filesize="${filemeta[7]}"

            # removing the double-quotes on the dates
            f_atime="${filemeta[8]//\"/}"
            f_mtime="${filemeta[9]//\"/}"
            f_ctime="${filemeta[10]//\"/}"

            # update totalsize calculation as we process
            (( totalsize += f_filesize ))

            # print out the files and attributes in a parseable format to each directory's dedicated dir_log file
            printf "'%s', %s, %s, %s, %s, %s, %s, %s, %s\n" \
            "$filepath_relative" "$filename_bn" "$filename_extension" "$f_owner" "$f_group" "$f_filesize" "$f_atime" "$f_mtime" "$f_ctime" | tee -a "$dir_log"

            # Are we running in report_only mode
            if [[ $report_mode = "yes" ]]; then
                continue
            elif [[ $report_mode = "no" ]]; then
                do_my_bidding
            fi 

        done < <(find "$top_level_dir" -type f -mtime +"$mtime_days" -print0)

        # check if totalsize (measured in kilobytes) is over 1GB.  If so, initialize size in GB, otherwise use MB format
        # NOTE conversion numbers are GB = KB / 1073741824, MB = KB / 1048576
        if (( totalsize > 1073741824 )); then
            
            size="$(printf '%s\n' "scale=2; $totalsize/1073741824" | bc)"'GB'

        else

            size="$(printf '%s\n' "scale=0; $totalsize/1048576" | bc)"'MB'

        fi

        # output each directory's name and size into the archive body for email
        printf '%-25s %-6s\n' "$bn_dir" "$size" | tee -a "$archive_body"
        
        (( grandtotal += totalsize ))

        # bottom banner for stdout on console
        printf "### END PROCESSING '%s' ###\n" "$top_level_dir"

    done

    # calculate and output grand total numbers
    grandtotal_gb="$(printf '%s\n' "scale=2; $grandtotal/1073741824" | bc)"'GB'

    # print grandtotal to mail body
    printf '\n%-25s %-6s\n' "TOTAL SAVINGS" "$grandtotal_gb" | tee -a "$archive_body"

    # mail the report?
    [[ $email_report = "yes" ]] && mail_the_report

    exit 0
}

mail_the_report () {

    # Set date/time variables
    mail_date=$(date "+%m-%d-%y")

    # Set email parameters
    mail_to=("ghalevy@gmail.com")
    #mail_to=("elid@outerstuff.com" "ghalevy@gmail.com")
    #mail_cc='ameir@outerstuff.com'
    #mail_cc='walker@designtechnyc.com,sjaradi@me.com,ameir@outerstuff.com'
    mail_cc='caghal@gmail.com'
    mail_from='osarchive@outerstuff.com'
    mail_subject="Archive Report for $mail_date"

    # print link to download detailed log report CSV files
    printf "\n\nFor a detailed CSV breakdown by directory, please visit the OSXServer directory http://osxserve/logs/ or http://192.168.168.13/logs/\n\n" >> "$archive_body"

    # send the mail using mutt (without attachment)
    cat "$archive_body" | /opt/local/bin/mutt -s "$mail_subject" -c "$mail_cc" "${mail_to[@]}"

}

#runtime () {
#
#    runtime_sec=$(( $(date +%s) - start_time ))
#    runtime_min=$(( runtime_sec / 60 ))
#    printf 'Runtime: %s\n' "$runtime_min" | tee -a "$archive_body"
#    printf 'Runtime: %s minutes\n' "$runtime_min" | tee -a "$archive_body"
#    
#}

## END FUNCTIONS


## RUN SCRIPT ##
main_menu
