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
TASKS=4                           #default number of tasks
SKIP_GROUPING=0                   #skip grouping file step, use directly exsisting file
CLEAR_TEMP=1                      #tell if clear temporary files


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

#get number of tasks and test if is number (default is 4)
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

if [[ "$NO_CLEAR" != "0" ]]; then
  #creanup temporary files
  echo -n "Clean temporary files... "
  rm -rf "$2/tmp"
  mkdir "$2/tmp" 2> /dev/null
  echo "Done"
else
  echo "Skipped clean temp step"
fi

if [[ "$SKIP_GROUPING" == "0" ]]; then
  if [[ "$NO_CLEAR" != "0" ]] || ! [[ -f "$2/tmp/$GROUPED_FILE.tmp" ]]; then

    #sort files according to patern
    echo -n "Sorting files... "
    files=($(find "$1" -type d -name .\* -prune -or -type f -name "$PATERN" -print))
    echo "Done"

    #group all content of files in one big
    echo -n "Grouping content... "
    echo > "$2/tmp/$GROUPED_FILE.tmp"
    for f in "${files[@]}"; do
    cat -s "$f" | uniq -u >> "$2/tmp/$GROUPED_FILE.tmp"
    done
    echo "Done"

    #sort the big file and delete duplicate lines
    echo -n "Shorting and removing duplicate lines... "
    sort "$2/tmp/$GROUPED_FILE.tmp" | uniq -u > "$2/$GROUPED_FILE"
    echo "Done"

  else
    echo "Use temp for grouped file"
    cp "$2/tmp/$GROUPED_FILE.tmp" "$2/$GROUPED_FILE"
  fi
else
  echo "Skipped grouping step"
fi

#setup folder, read total lines and devide it for tasks
echo "Started setup for tasks"
rm -rf "$2/$SORTED_FOLDER"
mkdir "$2/$SORTED_FOLDER"

echo "Create background tasks..."

echo "Reading lines and dividing up the tasks... "
total=($(wc -l "$2/$GROUPED_FILE"))
per_task=$(((${total[0]}+$TASKS-1)/$TASKS))
echo "Centralized total lines: ${total[0]}"

for p in $(seq 1 $TASKS); do
  if [[ "$CLEAR_TEMP" != "0" ]] && ! [[ -f "$2/tmp/part$p" ]]; then
    echo "Running task $p..."
    {
      sed -n "$((($p-1)*$per_task+1)),$(($p*$per_task))p" "$2/$GROUPED_FILE" > "$2/tmp/part$p"
      sed -r 's/^ *//; s/ *$//; /^$/d; /^\s*$/d' "$2/tmp/part$p" > "$2/tmp/part$p.tmp"
      rm "$2/tmp/part$p"
      echo "Task$p: Done"
    }&
  fi
done
sleep 2
echo "Waiting tasks finished..."
wait
echo

#Run tasks
echo "OK, now shorting everything..."
for t in $(seq 1 $TASKS); do
  echo "Running task $t..."
  {
    echo "Reading cache file..."
    readarray file < "$2/tmp/part$t.tmp"
    echo "Task$t: Sorting result of ${#file[@]} lines by the length in files..."
    for i in "${file[@]}"; do
      if [[ "${#i}" != "1" ]]; then
        echo -n "$i" >> "$2/$SORTED_FOLDER/length-$((${#i}-1)).txt"
      fi
    done
    echo "Task$t: Done"
  }&
done

#wait tasks finished to continue
sleep 2
echo "Waiting background tasks..."
wait
echo "All background tasks finished"

#and now sort all file and cut duplicated (normally must don't appening)
echo -n "Sorting content of created files... "
for i in $(find "$2/$SORTED_FOLDER" -name "length-*.txt" -type f); do
  sort "$i" | uniq -u > "$i.tmp"
  mv -f "$i.tmp" "$i"
done
echo "Done"

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
echo "All steps finished, enjoy!"

