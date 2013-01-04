#!/bin/bash

set -u
set -e


# Global script variables here
main_dir='/opt/osbkup'


# Set date/time variables
mail_date=$(date "+%m-%d-%y")


# setup filehandles
archive_body="$main_dir/archive_body"
archive_log="$main_dir/archive.log"


# Set email parameters
#mail_to=("ghalevy@gmail.com")
mail_to=("elid@outerstuff.com" "ghalevy@gmail.com")
mail_cc='ameir@outerstuff.com'
#mail_cc='walker@designtechnyc.com,sjaradi@me.com,ameir@outerstuff.com'
#mail_cc='caghal@gmail.com'
mail_from='osarchive@outerstuff.com'
mail_subject="Archive Report for $mail_date"


# truncate the rsync log to a reasonable size for sending
# /opt/local/bin/bzip2 -kqf "$archive_log"


# print link to download detailed log report CSV files
printf "\n\nFor a detailed CSV breakdown by directory, please visit the OSXServer directory /opt/osbkup/logs\n\n" >> "$archive_body"

# print the total runtime to the archive_body
printf "\n\n*** RUNTIME STATS ***\n\n" >> "$archive_body"
cat "$main_dir/runtime" >> "$archive_body"


# send the mail using mutt (with attachment)
#cat "$archive_body" | /opt/local/bin/mutt -s "$mail_subject" -c "$mail_cc" -a "${archive_log}.bz2" "${mail_to[@]}"

# send the mail using mutt (without attachment)
cat "$archive_body" | /opt/local/bin/mutt -s "$mail_subject" -c "$mail_cc" "${mail_to[@]}"
