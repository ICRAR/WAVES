#!/bin/bash
FILE_LIST=`cat filelist`
echo ${FILE_LIST[@]} | xargs --verbose -n 1 --max-procs=20 ./dowaves.sh
