#!/bin/bash
#
#	dowaves <fname>		# no extension
#

# root contains the code and processing files
root=#<the root>
# origfiles is the location of the orginal .fit files
origfiles=#<the source directory>
# tmp is the working directory to process each decompresses fits file
tmp=/tmp/$1
# name of the fits file during processing
fits=$tmp/$1.fits
# where to write the results of processing
output=$root/results/$1/
#
# Create the required directories
mkdir $tmp
mkdir $output

# Close STDOUT and STDERR
exec 1<&-
exec 2<&-
# Open STDOUT as $LOG_FILE file for read and write.
exec 1<>$output/$1.log
# Redirect STDERR to STDOUT
exec 2<>$output/$1.out
#exec 2>&1

#
$root/imcopy $origfiles/$1.fit $fits
#
# Copy required files to processing directory
cp default.nnw config.final.sex param.final.sex $tmp/
#
# Go to the working direcotry
cd $tmp
#
$root/preprocesswaves.r $1 $output
cd $root
#
/bin/rm -rf $tmp
#
echo DONE

