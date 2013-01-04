#!/bin/bash

set -e
set -u

# functions
mytee () { 

    tee -a "$archive_body" "$archive_log" 

}

# script options
mtime=730

# setup base dirs
main_dir='/opt/osbkup'
source_base='/Volumes/9TB_SAN/New Structure'
target_base='/Volumes/Drobo/OSArchive'

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
#    "${source_base}/Logos_Color Stds"
#    "${source_base}/Submissions"
#    "${source_base}/Jerseys"
#    "${source_base}/Design"
#    "${source_base}/Design transfer"
#    "${source_base}/Archives"
#    "${source_base}/Catalogs"
#    "${source_base}/Vertis"
    )


# begin looping
grandtotal=0

printf "Files not modified in the past %s days\n\n" "$mtime" | tee -a "$archive_body"
printf '%-25s %-6s\n' "DIRECTORY" "SIZE" | tee -a "$archive_body"
printf '%-25s %-6s\n' "---------" "----" | tee -a "$archive_body"

for top_level_dir in "${dirs_to_archive[@]}"; do

    totalsize=0

    # get naked top level dir
    bn_dir="${top_level_dir##*/}"

    # set log file location for dir
    dir_log="${main_dir}/logs/{$bndir}.log"

    # initialize log file for top level dir and print header
    [[ -f "$dir_log" ]] && >"$dir_log"
    printf 'filename, owner, group, size, atime, mtime, ctime\n' | tee -a "$dir_log"

    # top banner for stdout on console
    printf "### BEGIN PROCESSING '%s' ###\n" "$top_level_dir"

    # read in the results of find, tally size, create target dir, mv file, make read only, create symlink
    while IFS= read -rd '' file; do

        # setup parameters for use inside loop, self explanatory.  Filepath_relative strips out leading /Volumes/9TB_SAN/New Structure...
        source_dir="${file%/*}"
        target_file="${target_base}/${file#"$source_base"}"
        target_dir="${target_file%/*}"
        filepath_relative="${file#"$source_base"}"


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
        printf "'%s', %s, %s, %s, %s, %s, %s\n" \
        "$filepath_relative" "$f_owner" "$f_group" "$f_filesize" "$f_atime" "$f_mtime" "$f_ctime" | tee -a "$dir_log"

        # do my bidding
        #mkdir -p "$target_dir" \
        #&& mv "$file" "$target_dir" \
        #&& chmod 0444 "$target_file" \
        #&& ln -s "$target_file" "$source_dir"

    done < <(find "$top_level_dir" -type f -mtime +"$mtime" -print0)

    # check if over 1GB, otherwise output size in MB format
    if (( totalsize > 1073741824 )); then
        
        size="$(printf '%s\n' "scale=2; $totalsize/1073741824" | bc)"'GB'

    else

        size="$(printf '%s\n' "scale=0; $totalsize/1048576" | bc)"'MB'

    fi

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
