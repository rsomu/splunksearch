#!/usr/bin/bash

# [search input file format]
# username:password search-server-name search-command
#
if [ "$#" -ne 5 ]; then
   echo "Usage: $0 <#Users> <Cache pct> <search type> <output file> <test-name>"
   echo "       Search type: [dense | sparse] "
   echo "       Cache pct [0 to 100]: This determines the number of users searching cached data"
   exit 1
fi

source ./search.conf

UNPD=${username}:${password}
SRVR=${search_head}

USERS=$1
CACHEPCT=$2
STYPE=$3
OUTFILE=$4
TESTNAME=$5
RUSERS=$(( USERS * CACHEPCT / 100 ))
LUSERS=$(( USERS - RUSERS ))

# 1/4 day - 6 hours
SRANGE=$(( search_range * 6 * 3600 )) 

LTIME_START=$(date --date="$latest_time" +%s)
LTIME_END=$(date --date="$latest_time -$SRANGE second" +%s )
ETIME_START=$(date --date="$earliest_time" +%s)
ETIME_END=$(date --date="$earliest_time +$SRANGE second" +%s )

INTERVAL=$(( SRANGE / USERS ))

i=0
j=0
declare -A SIDS
for ((i=1; i<=$USERS; i++));
do
  RPTD[$i]=0
  status[$i]=STARTED
  if [ $i -le $LUSERS ]; then
      # Search against Cached Data
      SIDX=$(( LTIME_START - ((i - 1) * INTERVAL )))
      EIDX=$(( LTIME_START - (i * INTERVAL - 1 )))
      SDT=$(date -d @$EIDX +"%m/%d/%Y:%H:%M:%S")
      EDT=$(date -d @$SIDX +"%m/%d/%Y:%H:%M:%S")
      DTIR[$i]="Local"
  else
      # Search against Non-Cached Data
      j = $(( i - LUSERS ))
      SIDX=$(( ETIME_START + ((j - 1) * INTERVAL )))
      EIDX=$(( ETIME_START + (j * INTERVAL - 1 )))
      SDT=$(date -d @$SIDX +"%m/%d/%Y:%H:%M:%S")
      EDT=$(date -d @$EIDX +"%m/%d/%Y:%H:%M:%S")
      DTIR[$i]="Remote"      
  fi
  if [ "$STYPE" == "dense" ]; then
     keyword=west100k
  else
     keyword=west100m
  fi
  SRCH[$i]="'search index=${index_name} ${keyword} start_time=\"${SDT}\" end_time=\"${EDT}\"'"

  cmd="curl -s -u ${UNPD} -k https://${SRVR}:8089/services/search/jobs -d search=${SRCH[$i]} | grep -oPm1 '(?<=<sid>)[^<]+' "
  SIDS[$i]=$( eval $cmd )
  echo ${SIDS[$i]} " " ${SRCH[$i]}
done

echo "TestName, DataTier, SearchEndTime, eventCount, resultCount, runDuration, scanCount, searchTotalBucketsCount, searchTotalEliminatedBucketsCount, search, index-bucket-hits, index-bucket-miss" > $OUTFILE
echo "TestName, DataTier, SearchEndTime, eventCount, resultCount, runDuration, scanCount, searchTotalBucketsCount, searchTotalEliminatedBucketsCount, search, index-bucket-hits, index-bucket-miss"
ct=0
echo "Total sids "${#SIDS[@]}

sleep 10
while [ $ct -lt ${#SIDS[@]} ]; do
  for ((i=1; i <= ${#SIDS[@]}; i++)); do
    echo "RPTD is " ${RPTD[$i]} " and status is " ${status[$i]}
    if [[ "${status[$i]}" =~ "DONE" ]] && [ ${RPTD[$i]} -eq 0 ]; then
      (( ct++ ))
      RPTD[$i]=1
      cmd="curl -s -u ${UNPD} -k https://${SRVR}:8089/services/search/jobs/${SIDS[$i]} | egrep -i 'updated|resultCount|scanCount|eventCount|searchTotalBucketsCount|runduration|searchTotalEliminatedBucketsCount'| sed 's/s:key//g' |sed -r 's/< name=\"[a-zA-Z]*\">//g'|sed 's/updated//g' |sed 's/<\/>/,/g' |sed 's/<>//g' "
      results[$i]=$( eval $cmd )
      cmd="curl -s -u ${UNPD} -k https://${SRVR}:8089/services/search/jobs/${SIDS[$i]} |egrep -A3 'command.search.index.bucketcache.hit|command.search.index.bucketcache.miss'  |grep invocations |sed 's/s:key//g' |sed -r 's/< name=\"[a-zA-Z]*\">//g'|sed 's/<\/>/,/g' |sed 's/<>//g' "
      bkts[$i]=$( eval $cmd )
      echo $TESTNAME", "${DTIR[$i]}", "${results[$i]}" "${SRCH[$i]} ", " ${bkts[$i]} >> $OUTFILE
      echo $TESTNAME", "${DTIR[$i]}", "${results[$i]}" "${SRCH[$i]} ", " ${bkts[$i]}
    elif [ ${RPTD[$i]} -eq 0 ]; then
      cmd="curl -s -u ${UNPD} -k https://${SRVR}:8089/services/search/jobs/${SIDS[$i]} | grep 'dispatchState'  |sed 's/s:key//g' |sed 's/[\<|\>|\/]//g' |sed 's/\"/ /g'|sed 's/name= //'| sed 's/dispatchState //' "
      status[$i]=$( eval $cmd )
    fi
  done
done
