#!/bin/bash
if [ "$#" -ne 1 ] || ! [ -d "$1" ] ; then
	echo "Usage: $0 DIRECTORY" >&2
	echo
	exit 1
fi

command -v ruby >/dev/null 2>&1 || {
	echo "Error: Ruby is required to run this script" >&2
	echo
	exit 1
}

PWD_INIT=`pwd`
find $1 -name "case_*" | while read line ; do
	if [ -d "$line/case" ] ; then
		cd "$line/case"
		echo -e "\033[1;37mRunning in scenario directory: $line/case\033[0m"
		find . -name "*.plan" \
			! -name "immediate.plan" \
			! -name "terminate.plan" \
			| while read line; do
			# echo $line
			target=`echo $line | sed -rn "s/^(.*)\/(.+)\.plan$/\2/p"`
			# echo $target
			echo -e "\033[1;37mRunning plan: $target"
			echo
			./simu.sh $target.plan
			echo
			killall -q qualnet
			mkdir -p $target
			mv *.out $target
			mv *.log $target
		done
	else
		echo "Cannot find scenario directory: $line/case" >&2
	fi
	cd $PWD_INIT
done
echo "Done"
