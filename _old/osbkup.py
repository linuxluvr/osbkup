#!/usr/bin/env python2

#===============================================================================
# # This is a backup script for OSNYMAC XServer files.  It should be
# run out of cron daily.  It creates backups directly on osnjnas01.
# 
# Features to add:
# 	* Old archives will be truncated and removed after 7 days.
# 	* Mail report, need a valid SMTP server
#
# For any maintenance requests, contact Gilad Halevy.ghalevy@gmail.com
#
# Last update: 08/02/2012
# Last modified by: GH
# Update comments:
#===============================================================================


import os
import sys
import time
import subprocess
#import smtplib
import string
#import itertools


# Global script variables here
# uncomment below to use rsyncd
#rsync_target_base = 'rsync@osnjnas01::NEWSTRUCTURE'
# local source base
rsync_source_base = '/Volumes/OSRaidSet/New Structure/'
# remote target base
rsync_target_base = 'admin@osnjnas01:/share/MD0_DATA/share/REMOTENYMACBKUP/New\ Structure'

# Set date/time variables
mail_date = time.strftime("%m-%d-%Y")
filename_date = time.strftime("%Y-%m-%d_%H:%M:%S")
log_date = time.strftime("%m-%d-%y %H:%M")

# setup filehandles 
mail_body_w = open("/opt/admscripts/python/mail_body", "w+b")
rsync_log_w = open("/opt/admscripts/python/osbkup.log", "w+b")


# set directories to backup
def set_bkup_dirs():

    global dirs_to_bkup

    # define the backup directories here
    dirs_to_bkup = (
        'Reference Numbers',
        'Fonts',
        'Samples',
        'India',
        'Labels_Hangtags',
        'Logos_Color Stds',
        'Samples',
        'Submissions',
        'Jerseys',
        'Design',
        'Archives',
        )
        #'Submissions',
        #'Jerseys',
        #'Design',
        #'Archives',


def backup_server():

    # Begin the backup process for the server

    mail_body_w.write("\n+++++ " + time.asctime() + " +++++\n")
    mail_body_w.write("\n### BEGIN BACKUP OF MAC XSERVE ###")

    for current_bkup_dir in dirs_to_bkup:

        # does the path exist?
        source_path = rsync_source_base + current_bkup_dir
        if not os.path.exists(source_path):

            print "\nError Backing up '" + current_bkup_dir + "'\n"
            mail_body_w.write("\nError Backing up '" + current_bkup_dir + "'\n")
            rsync_log_w.write("\nError Backing up '" + current_bkup_dir + "'\n")
            continue

        else:


            # Begin backup of directory
            print "======== BEGIN backup of '" + current_bkup_dir + "' ~ " + time.asctime() + "  ========"
            rsync_log_w.write("\n======== BEGIN backup of '" + current_bkup_dir + "' ~ " + time.asctime() + " ========\n")
            mail_body_w.write("\n...Backing up '" + current_bkup_dir + "' to OSNJNAS01...")

            # setup the rsync parameters
            #exclusions = ['--exclude %s' % x.strip() for x in exclude_params_str.split(',')]
            exclusions = '--exclude-from=/opt/admscripts/python/excludes'

            # set the rsync flags below
            rsync_flags = '\
                            --recursive \
                            --perms \
                            --links \
                            --owner \
                            --times \
                            --verbose \
                            --group \
                            --devices \
                            --specials \
                            --numeric-ids \
                            --compress \
                            --compress-level=1 \
                            --human-readable \
                            --partial \
                            --stats \
                            --E \
                            '
                            # Unused parameters
                            #--progress \
                            #--dry-run \
                            #--size-only \
                            #--ignore-existing \
                            #--itemize-changes \
                            #--password-file=/etc/rsyncd.passwd \
                            #--delete \
                            #--delete-after \
                            #--delete-excluded \

            rsync_cmd =  ['rsync'] + [ exclusions ] + rsync_flags.split() + [ source_path ] + [ rsync_target_base ]

            # Debugging parameters
            #print rsync_cmd
            #continue

            # run the rsync command
            rsync_exec = subprocess.Popen(
                                        rsync_cmd,
                                        stdout=subprocess.PIPE,
                                        stderr=subprocess.PIPE,
                                        shell=False,
                                        )

            # wait for rsync job to finish
            #rsync_exec.wait()
            
            # capture output of rsync cmd
            stdout,stderr = rsync_exec.communicate()

            # write output to our log file
            rsync_log_w.write(stdout)
            rsync_log_w.write(stderr)
            print stdout
            print stderr
            
            # grab the exit code
            rsync_retval = rsync_exec.returncode
            
            #if rsync_retval == 0:
            if rsync_retval == 0:

                print "======== END backup of '" + current_bkup_dir + "' ~ " + time.asctime() + "  ========"
                rsync_log_w.write("======== END backup of '" + current_bkup_dir + "' ~ " + time.asctime() + " ========\n\n")
                mail_body_w.write("SUCCESS!")

    # at this point we are done backing up the current server
    mail_body_w.write("\n### COMPLETED BACKUP OF MAC XSERVE ###\n")
    mail_body_w.write("\n+++++ " + time.asctime() + " +++++\n\n")
    #rsync_log_w.write("\n### COMPLETED BACKUP OF XSERVE ###\n\n")


def send_mailreport():

    #Be responsible and close the filehandles
    mail_body_w.close()
    rsync_log_w.close()

    # gzip the existing local backup log
    #subprocess.call(
    #               ['tar', 'czf', '/opt/admscripts/python/rsync_log.log.gz', '/opt/admscripts/python/rsync_log.log'],
    #               stdout=open(os.devnull, 'w'),
    #               stderr=open(os.devnull, 'w'),
    #               shell=False,
    #               )


    # open the mail_body_w file for reading
    #mail_body_r = open ('/opt/admscripts/python/mail_body').read()

    # Set email parameters
    #mail_server = smtplib.SMTP('localhost')
    #mail_to = 'elid@outerstuff.com'
    mail_to = 'caghal@gmail.com'
    mail_cc = 'ghalevy@gmail.com'
    mail_from = 'osbkup@outerstuff.com'
    mail_subject = 'Daily Backup Report for ' + mail_date

    ### build the mail body
    ##mail_body = string.join((
    ##    "From: %s" % mail_from,
    ##    "To: %s" % mail_to,
    ##    "Subject: %s" % mail_subject,
    ##    "",
    ##    mail_body_r
    ##    ), "\r\n")

    ## send the mail
    ##mail_server.sendmail(mail_from, [mail_to], mail_body)
    ##mail_server.quit()
    
    # send the mail using mutt (python smtplib + email too complicated for this simple task
    subprocess.call(
                    ["cat /opt/admscripts/python/mail_body | mutt -s '" + mail_subject + 
                    "' -c " + mail_cc + 
                    " -a /opt/admscripts/python/osbkup.log " + mail_to],
                    shell=True,
                    )


# Begin backup process
set_bkup_dirs()
#set_rsync_exclusions()
backup_server()
send_mailreport()
