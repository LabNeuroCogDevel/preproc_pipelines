 MAXJOBS=1 TESTONLY=1 ./pp cannabis_rest MHRest+dvars5-ref 2>&1|grep cannot|perl -lne 'print $& if /\d{5}_\d{8}/'|sort |uniq

