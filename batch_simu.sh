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
PARS=("- OPPORTUNITY" \
	"alg4.plan STRICT_PLAN" \
	"ga.plan STRICT_PLAN" \
	"alg4.plan ADAPTIVE_GP alg4.specs" \
	"ga.plan ADAPTIVE_GP ga.specs")
DNMS=("opportunity" "alg4_static" "ga_static" "alg4_agp" "ga_agp")
find $1 -name "case_*" | while read line ; do
	if [ -d "$line/case" ] ; then
		cd "$line/case"
		echo -e "\033[1;37mRunning in scenario directory: $line/case\033[0m"
		typeset -i i ind jnd
		for ((ind=0; ind<5; ++ind)); do
			par=${PARS[$ind]}
			dnm=${DNMS[$ind]}
			for ((jnd=11; jnd<=15; ++jnd)); do
				jnm="dynamic_$jnd.bandwidth"
				echo -e "\033[1;37mRunning case: $jnm $par\033[0m"
				echo
				./dynamic_simu.sh $jnm $par
				echo
				killall -q qualnet
				mkdir -p $dnm/rand_$jnd
				mv *.out $dnm/rand_$jnd
				mv *.log $dnm/rand_$jnd
			done
		done
	else
		echo "Cannot find scenario directory: $line/case" >&2
	fi
	cd $PWD_INIT
done
echo "Done"
