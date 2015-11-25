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

RUBY=`which ruby`

find $1 -name "case_*" | while read line ; do
	if [ -d "$line/case" ] ; then
		echo "Found an existing scenario directory: $line/case"
	else
		echo "Writing to scenario diretory: $line/case"
		(
			IFS=$'\n'

			errOutCount=0
			for line in \
				$($RUBY make_scenario.rb \
					"$line/case.up.deployment" "$line/case" \
					2>&1 >/dev/null)
			do
				echo $line
				errOutCount=$(($errOutCount + 1))
			done
			if [ $errOutCount -gt 0 ] ; then echo ; fi
		)
		mv $line/*.plan "$line/case" >/dev/null 2>&1
	fi
done
echo "Done"
#echo
