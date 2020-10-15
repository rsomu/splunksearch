# Splunk Search test framework
 Script to run concurrent searches across tiers on Splunk Enterprise.
 The script allows concurrent searches with cache percentage which determines the number of users searching cached data while the remaining users search remote tiered data.
 
This search test framework enables concurrent searches on the synthetic apache log data generated by [apclog](https://github.com/rsomu/apclog) data generation toolkit.
 
## Usage
```
  runsearch.sh <#Users> <Cache pct> <search type> <output file> <test-name>
    Search type: [dense | sparse] 
    Cache pct [0 to 100]: This determines the number of users searching cached data
    output file: Output will be in CSV format
    test-name: Meaningful label for the test which will be included in the output file
```

The script uses a configuration file named search.conf

```
latest_time="Oct 07 23:59:59 PDT 2020"   # Latest date/time of events that are in Hot/Warm or Cache tier
earliest_time="Oct 01 00:00:00 PDT 2020" # Earliest date/time of events that are in Cold or remote tier
search_range=1                           # In days. Tiered searches will use this range with latest/earliest time
search_head=splunk-sh01                  # Search Head IP/FQDN to issue the searches
username=admin                           # Username under which the searches will be issued
password=splunk123                       # Password of the user
index_name=apache-pure1                  # The custom index where the synthetic apache log data is ingested
```

For example, to run 40 concurrent searches with 75% of the searches to go after the Cached data do the following.

```
  runsearch.sh 40 75 sparse 40users_75pct_sparse Sparse_test
```

The above command will issue 30 searches against the cached data and 10 searches against the remote-tiered data.

The search time range (starttime, endtime) per user is calculated by search_range/user_count in seconds.

For the cached data, the search time for every search is between latest_time and latest_time + per_user_search_range.

For the non-cached data, the search time for every search is between earliest_time and earliest_time + per_user_search_range.

The searches are in the following format

 `search index=apache-pure1 every10m starttime="10/01/2020:00:00:00" endtime="10/01/2020:04:00:00"`
