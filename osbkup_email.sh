#!/bin/bash

set -u
set -e


# Global script variables here
main_dir='/opt/osbkup'


# Set date/time variables
mail_date=$(date "+%m-%d-%y")


# setup filehandles
mail_body="$main_dir/mail_body"
rsync_log="$main_dir/osbkup.log"


# Set email parameters
mail_to=("elid@outerstuff.com" "ghalevy@gmail.com")
mail_cc='walker@designtechnyc.com,sjaradi@me.com,ameir@outerstuff.com'
#mail_to='ghalevy@gmail.com'
#mail_cc='caghal@gmail.com'
mail_from='osbkup@outerstuff.com'

if fgrep -q 'FAILED!!' "$mail_body"; then

    mail_subject="Daily Backup Report for $mail_date - COMPLETED (with errors)"

else 

    mail_subject="Daily Backup Report for $mail_date - COMPLETED"

fi


# truncate the rsync log to a reasonable size for sending
/opt/local/bin/bzip2 -kqf "$rsync_log"


# print the total runtime to the mail_body
echo -e "\n*** RUNTIME STATS ***\n" >> "$mail_body"
cat "$main_dir/runtime" >> "$mail_body"


# send the mail using mutt
cat "$mail_body" | /opt/local/bin/mutt -s "$mail_subject" -c "$mail_cc" -a "${rsync_log}.bz2" "${mail_to[@]}"
