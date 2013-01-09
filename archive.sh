#!/bin/bash

# script options
shopt -s extglob
set -e
set -u

## Globals
main_dir='/opt/osbkup'

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

#script_vars=('dirs_file' 'report_mode' 'mtime_days' 'target_base')   
#
#for svar in "${script_vars[@]}"; do "$svar"=''; done

} 

main_menu () {

#    clear

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
            source_base='/Volumes/9TB_SAN/New Structure'
            target_base='/Volumes/Drobo/OSArchive'
            dirs_file="${main_dir}/default_dirs.txt"
            mtime_days=730
            ;;

        2) # Use custom settings
            until [[ -r "$dirs_file" ]]; do read -p "Enter path to file containing directories to archive (newline separated)? " dirs_file; done
            until [[ -d "$target_base" && -w "$target_base" ]]; do
                read -p "Target base directory to archive to (full path, should be writeable): " target_base;
            done
            while [[ "$mtime_days" = *[!0-9]* || "$mtime_days" = "" ]]; do read -p "Archive threshold (in days)? " mtime_days; done
            ;;

        9) # Exit
            exit 0
            ;;

    esac
            
    until [[ "$report_mode" = @(yes|no) ]]; do read -p "Run in Report-only mode (yes/no)? " report_mode; done

}


validate_params () {

    clear

cat <<-EOT

*************************************************************

SETTINGS

Report Mode: $(printf '%s' "$report_mode")
Directories to Archive:
$(cat "$dirs_file")
Target Base: $(printf '%s' "$target_base")
Threshold (in days): $(printf '%s' "$mtime_days")
    

*************************************************************

EOT

    read -n 1 -p "Confirm Settings (y/n)?" confirm_settings
    [[ "$confirm_settings" = "y" ]] || main_menu

}

reset_vars
main_menu
validate_params
exit 0

## END FUNCTIONS


# Validate parameters before continuing


# script options
# set number of days threshold to do archiving for 
mtime="$mtime_days"

# setup base directories
source_base='/Volumes/9TB_SAN/New Structure'
#target_base='/Volumes/Drobo/OSArchive'

# setup filehandles
archive_body="${main_dir}/archive_body"
archive_log="${main_dir}/archive.log"
[[ -f "$archive_body" ]] && >"$archive_body"
[[ -f "$archive_log" ]] && >"$archive_log"

# define the dirs to archive
dirs_to_archive=(
    "${source_base}/Reference Numbers"
    "${source_base}/Fonts"
    "${source_base}/Samples"
    "${source_base}/India"
    "${source_base}/Labels_Hangtags"
#    "${source_base}/Labels_Hangtags2"
    "${source_base}/Logos_Color Stds"
    "${source_base}/Submissions"
    "${source_base}/Jerseys"
    "${source_base}/Design"
    "${source_base}/Design transfer"
    "${source_base}/Archives"
    "${source_base}/Catalogs"
    "${source_base}/Vertis"
    )


# Set grandtotal (sum of space savings from ALL dirs) to 0
grandtotal=0

printf "Files not modified in the past %s days\n\n" "$mtime_days" | tee -a "$archive_body"
printf '%-25s %-6s\n' "DIRECTORY" "SIZE" | tee -a "$archive_body"
printf '%-25s %-6s\n' "---------" "----" | tee -a "$archive_body"

# begin looping over dirs and processing
for top_level_dir in "${dirs_to_archive[@]}"; do

    # set totalsize of dir space saved to 0
    totalsize=0

    # get basename (naked) top level dir
    bn_dir="${top_level_dir##*/}"

    # set log file location for dir
    dir_log="${main_dir}/logs/${bn_dir}.csv"

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

        # do my bidding
        #mkdir -p "$target_dir" \
        #&& mv "$file" "$target_dir" \
        #&& chmod 0444 "$target_file" \
        #&& ln -s "$target_file" "$source_dir"

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

### END ###
