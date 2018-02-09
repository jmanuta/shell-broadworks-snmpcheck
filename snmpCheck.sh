#!/usr/bin/env bash
# jmanuta@bluip.com | 2018.02.08



bwLogPath="/bw/broadworks/logs/"
snmpLog=$(find ${bwLogPath} -name 'snmptraps.log' 2>&1 | grep -v '^find')
newestRecord=$(date +%Y/%m/%d' '%H:%M:%S' GMT')
oldestRecord=$(
	date -d @$(
		head -2 ${snmpLog} |\
			tail -1 |\
			cut -d',' -f2 |\
			cut -c1-10
    ) +%Y/%m/%d' '%H:%M:%S' GMT'
)


usage() {
	if [ -z "${1}" ]; then
		(
        msg+="Description:\tSNMP parse tool\n"
        msg+="Usage:\t\t$(basename ${0}) <command> [string]\n"
        msg+="Commands:\tlist \t- List count of entries\n"
        msg+="\t\tdetail \t- Expand the specified alarm\n"
        msg+="\t\tsearch \t- Search for a string or \"all\""
		echo -e "\n${msg}\n"
		) 1>&2
		exit
	fi
}


action() {
	if [ "${1}" = "list" ]; then

		:<<-Comment
		$results is a string which lists each alarm type, along with
		the number of occurrences.  Example --
		
        (872)   bwSystemHealthReport
        (32)    bwConfigurationChanged
        (26)    bwCPUIdleTimeLimitReached
        (24)    bwApplicationStateTransition
        (3)     bwPMhttpdLaunched
        (3)     bwPMhttpdShutDown
        (3)     bwPMtomcatLaunched
		Comment

		results=$(awk '
			BEGIN {
				RS=">\n<"
				FS="\n"
			} {
				print $3
			}' ${snmpLog} |\
    			sed -e 's/"//g' \
        		-e 's/,//g' |\
    			sort |\
    			uniq -c |\
    			sort -k1,1nr |\
    			awk '{printf "\t\t%-s%-s%-s\t%-40s\n", "(", $1, ")", $2}'
		)


		echo -e "\n Server:\t${HOSTNAME}"
		echo -e "  Range:\t${oldestRecord}"
		echo -e "\t\t${newestRecord}"

		:<<-Comment
		To output the Records, I wanted to list the first record on the same line
		as the "Records" header.  A combination of head, sed and tail were used
		to output the data like this:

        Records:    (872)    bwSystemHealthReport
                    (32)     bwConfigurationChanged
                    (26)     bwCPUIdleTimeLimitReached
                    (24)     bwApplicationStateTransition
                    (3)      bwPMhttpdLaunched
                    (3)      bwPMhttpdShutDown
                    (3)      bwPMtomcatLaunched
                    (3)      bwPMtomcatShutDown
                    (1)      bwPMconfigdLaunched
                    (1)      bwPMlmdLaunched
		Comment

		echo -e "\nRecords:\t$(echo "${results}" | head -1 | sed s'/^[[:space:]]*//')"
		echo -e "${results[*]}\n" | tail -n +2


	elif [ "${1}" = "detail" ]; then
		shift
		results=$(
			awk '
				BEGIN {
					RS=">\n<"
					FS="\n"
					ORS="\n----------------------------------------\n"
				} $0 ~ /'"${1}"'/ {
					print $0
				}' $snmpLog
		)
		severity=$(echo "$results" | grep -v "^$\|^<$" | head -1 | cut -d, -f3 | sed 's/\"//g')
		timestamps=$(
			counter=1
			echo "${results}" |\
				grep ${severity} |\
				cut -d, -f2 |\
				cut -c1-10 |\
				while read i; do
					stamp=$(date -d @${i})
					printf "%6s %s" "[${counter}]" "${stamp}\n"
					let counter+=1
			done
		)

		echo -e "\n${timestamps}\n"


	elif [ "${1}" = "search" ]; then
		shift
		pattern=${1}

		if [ -z "${pattern}" ]; then
			echo -e "\\n% Specify search string %"
			usage
		elif [ ${pattern} == "all" ]; then
			pattern=""
		fi

		results=$(
			awk '
				BEGIN {
					RS=">\n<"
					FS="\n"
					ORS="\n----------------------------------------\n"
				} $0 ~ /'"${pattern}"'/ {
					print $0
				}' ${snmpLog}
		)

        echo -e "\nServer:\t\t${HOSTNAME}"
        echo -e " Range:\t\t${oldestRecord}"
        echo -e "\t\t${newestRecord}"
        echo -e "\n${results}\n"


	else
		echo -e "\n% Invalid option %"
		usage

	fi
}

usage ${1}
action ${1} ${2}
