#!/bin/bash

## ===============================================================================
## This is a backup script for OSNYMAC XServer files.  It should be
## run out of cron daily.  It creates backups directly on osnjnas01.
##
## Features to add:
## 	* Old archives will be truncated and removed after 7 days.
##
## For any maintenance requests, contact Gilad Halevy.ghalevy@gmail.com
##
## Last update: 08/06/2012
## Last modified by: GH
## Update comments: ready for prod
## ===============================================================================

set -u
set -e
#set -o pipefail


# Global script variables here
#rsync_target_base = 'rsync@osnjnas01::NEWSTRUCTURE'
main_dir='/opt/osbkup'
rsync_source_base_osraidset='/Volumes/OSRaidSet/New Structure'
rsync_source_base_9TB_SAN='/Volumes/9TB_SAN/New Structure'
rsync_source_base_18TBSAN='/Volumes/1.8TB SAN/New Structure'
rsync_target_base='admin@osnjnas01:/share/MD0_DATA/share/REMOTENYMACBKUP/New\ Structure'

# setup filehandles
mail_body="$main_dir/mail_body"
rsync_log="$main_dir/osbkup.log"
[[ -f "$mail_body" ]] && >"$mail_body"
[[ -f "$rsync_log" ]] && >"$rsync_log"


# define the directories to backup here
dirs_to_bkup=(
    "$rsync_source_base_9TB_SAN/Reference Numbers"
    "$rsync_source_base_9TB_SAN/Fonts"
    "$rsync_source_base_9TB_SAN/Samples"
    "$rsync_source_base_9TB_SAN/India"
    "$rsync_source_base_9TB_SAN/Labels_Hangtags"
    "$rsync_source_base_9TB_SAN/Logos_Color Stds"
    "$rsync_source_base_9TB_SAN/Submissions"
    "$rsync_source_base_9TB_SAN/Jerseys"
    "$rsync_source_base_9TB_SAN/Design"
#   "$rsync_source_base_9TB_SAN/Design transfer"
    "$rsync_source_base_9TB_SAN/Archives"
    "$rsync_source_base_9TB_SAN/Catalogs"
    "$rsync_source_base_9TB_SAN/Vertis"
    )


mytee () {

    tee -a "$mail_body" "$rsync_log"

}


backup_server () {

    # Begin the backup process for the server

    echo -e "\n### BEGIN BACKUP - $(date) ###" | mytee

    for current_bkup_dir in "${dirs_to_bkup[@]}"; do

        # get the basename
        dir_basename=$(basename "$current_bkup_dir")

        # assign current_bkup_dir to source_path
        source_path="$current_bkup_dir"

        # does the path exist?
        if [[ ! -d "$source_path" ]]; then

            echo -e "Error Backing up '"$dir_basename"'" | mytee
            continue

        else

            # Begin backup of directory
            echo -e "\n======== BEGIN backup of '"$dir_basename"' - $(date) ========" | mytee

            # setup the rsync parameters
            exclusions="--exclude-from=$main_dir/excludes"

            # set the rsync flags below
            rsync_flags=(
                        "--archive"
                        "--verbose"
                        "--numeric-ids"
                        "--compress"
                        "--compress-level=1"
                        "--human-readable"
                        "--partial"
                        "--stats"
                        "--delete"
                        "--delete-excluded"
                        "--itemize-changes"
                        "-E"
                        )
                        # Unused parameters
                        #--dry-run \
                        #--size-only \
                        #--ignore-existing \

            # run the rsync job
            rsync "${rsync_flags[@]}" "$exclusions" "$source_path" "$rsync_target_base" >>"$rsync_log" 2>&1

            rsync_exit_code=${PIPESTATUS[0]}

            if [[ "$rsync_exit_code" -eq 0 ]]; then

                echo "SUCCESS!!" | mytee

            else

                echo "FAILED!! - see attached logfile for details" | mytee
                
            fi
                
            # print ending line for directory
            echo -e "======== END backup of '"$dir_basename"' - $(date) ========\n" | mytee

        fi

    done

    # at this point we are done backing up the current server
    echo -e "### END BACKUP - $(date) ###\n\n" | mytee

}

# Begin backup process
backup_server
