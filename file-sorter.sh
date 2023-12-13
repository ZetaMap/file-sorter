#!/bin/bash

# File Sorter is a small script to group, sort and split by line size a large number of files.
# It takes a source directory, where the whole tree will be grouped, and a destination directory, to store cache, results and sorted files.
# Most uses of this method is to sort lot of usernames or passwords lists, but it work with other usages =).
# Alse you can add an optional argument to tell the number of tasks on which the process will be divided.
# WARNING: this script is not very optimized, but good enough to run a lot of tasks in the background to process them faster.

###internal settings
PATERN="[!.]*.txt"                #patern to find files, note: this ignores directories starting with a dot
GROUPED_FILE="all-in-one.txt"     #name of centralized file
SORTED_FOLDER="sorted"            #name of sorted files folder
TASKS=16                          #default number of tasks
SKIP_GROUPING=1                   #skip grouping file step, use directly exsisting file
CLEAR_TEMP=1                      #tell if clear temporary files
PREFIX_FILE="length-"


#test if source and destination is specified
if [[ "$1" == "" ]] || [[ "$2" == "" ]]; then
  echo "Script must have source and destination directory"
  exit 1
else
  if ! [[ -d "$1" ]] || ! [[ -d "$2" ]]; then
    echo "Source or destination not exists or incorrect"
    exit 1
  fi
fi

#get number of tasks and test if is number (default is 16)
if [[ "$3" != "" ]]; then
  if [ -z "${3##[0-9]*}" ] && [[ "$3" -gt "0" ]]; then
    TASKS=$3
  else
    echo "tasks argument must be number and greater than 1"
    exit 1
  fi
fi


###program
#header
echo "Started script with settings:"
echo "  - file find patern: $PATERN"
echo "  - source folder: $1"
echo "  - destination folder: $2"
echo "  - centralized file: $GROUPED_FILE"
echo "  - background tasks: $TASKS"
echo "  - sorted files folder: $SORTED_FOLDER"
echo "  - skipping grouping: $SKIP_GROUPING"
echo "Note: more settings at top of script"
echo
echo

if [[ "$CLEAR_TEMP" != "0" ]]; then
  #creanup temporary files
  echo -n "Clean temporary files... "
  rm -rf "$2/tmp"
  mkdir "$2/tmp" 2> /dev/null
  echo "Done"
else
  echo "Skipped clean temp step"
fi
mkdir "$2/tmp" 2> /dev/null

if [[ "$SKIP_GROUPING" == "0" ]]; then
  if [[ "$CLEAR_TEMP" != "0" ]] || ! [[ -f "$2/tmp/$GROUPED_FILE.tmp" ]]; then

    #sort files according to patern
    echo -n "Sorting files... "
    files=($(find "$1" -type d -name .\* -prune -or -type f -name "$PATERN" -print))
    echo "Done"

    #group all content of files in one big
    echo -n "Grouping content... "
    echo > "$2/tmp/$GROUPED_FILE.tmp"
    for f in "${files[@]}"; do
      cat -s "$f" >> "$2/tmp/$GROUPED_FILE.tmp"
    done
    echo "Done"

    #sort the big file and delete duplicate lines
    echo -n "Shorting and removing duplicate lines... "
    sort "$2/tmp/$GROUPED_FILE.tmp" | uniq -u > "$2/$GROUPED_FILE"
    echo "Done"

  else
    echo "Use temp for grouped file"
    sort "$2/tmp/$GROUPED_FILE.tmp" | uniq -u > "$2/$GROUPED_FILE"
  fi
else
  echo "Skipped grouping step"
fi

#setup folders and split the grouped file for tasks
rm -rf "$2/$SORTED_FOLDER"
mkdir "$2/$SORTED_FOLDER"

echo "Spliting grouped file... "
total=($(wc -l "$2/$GROUPED_FILE"))
per_task=$(((${total[0]}+$TASKS-1)/$TASKS))
echo "Total lines: ${total[0]}"
cd tmp
split -d -l $per_task "../$2/$GROUPED_FILE" part
cd ..

#Run tasks
echo "Sorting everything..."
i=0
for f in $(find "$2/tmp" -name "part*" -type f); do
  echo "Running task $i..."
  {
    echo "Task$i: Sorting file '$f' by lines length ..."
    awk '{print >> "'$2'/'$SORTED_FOLDER'/'$PREFIX_FILE'" length($0) ".txt"}' "$f"
    echo "Task$i: Done"
  } &
  ((i+=1))
done

#wait tasks finished to continue
sleep 2
echo "Waiting for background tasks..."
wait
echo "All background tasks finished"

if [[ "$CLEAR_TEMP" != "0" ]]; then
  #creanup temporary files
  echo -n "Clean temporary files... "
  rm -rf "$2/tmp"
  echo "Done"
else
 echo "Skipped clear temp step"
fi

#cool message for the end
echo
echo "All steps finished."

