#!/usr/bin/env bash

# set up configurations
source benchmark.conf;

mkdir -p $LOG_DIR
if [ -e "$LOG_FILE" ]; then
	timestamp=`date "+%F-%R" --reference=$LOG_FILE`
	backupFile="$LOG_FILE.$timestamp"
	mv $LOG_FILE $LOG_DIR/$backupFile
fi

echo ""
echo "***********************************************"
echo "*          TPC-H benchmark on Impala          *"
echo "***********************************************"
echo "                                               " 
echo "See $LOG_FILE for more details of query errors."
echo ""

if [[ -z $DISABLE_CODEGEN ]]; then
    DISABLE_CODEGEN=0
fi

# when you are using big data and don't want to re-ingest every time
# set KEEP_TABLES=1
preparemod=''
if [[ $KEEP_TABLES -eq 1 ]]; then
    echo "Preparing all" | tee -a $LOG_FILE
    preptmpdir=$BASE_DIR/tpch_prepare/tmp
    mkdir -p $preptmpdir
    $BASE_DIR/replace_filename.sh $SF <$BASE_DIR/tpch_prepare/bigdata/prepare-all.impala >$preptmpdir/prepare-all.impala
    $TIME_CMD $IMPALA_CMD --query_file=$preptmpdir/prepare-all.impala 2>&1 | tee -a $LOG_FILE | grep '^Time:'
        returncode=${PIPESTATS[0]}
    if [ $returncode -ne 0 ]; then
        echo "FAILED INGEST"
        exit 1
    fi
    preparemod=bigdata
fi

trial=0
while [ $trial -lt $NUM_OF_TRIALS ]; do
	trial=`expr $trial + 1`
	echo "Executing Trial #$trial of $NUM_OF_TRIALS trial(s)..."

	for query in ${TPCH_QUERIES_ALL[@]}; do
		echo "Running query: $query, no_codegen: $DISABLE_CODEGEN, scale: $SF" | tee -a $LOG_FILE

		echo "Running Hive prepare query: $query" >> $LOG_FILE
		#$TIME_CMD $HIVE_CMD -f $BASE_DIR/tpch_prepare/${query}.hive 2>&1 | tee -a $LOG_FILE | grep '^Time:'
        # use impala instead of hive for DDL because its way faster
        # also use .impala which are the modified queries
        preptmpdir=$BASE_DIR/tpch_prepare/tmp
        mkdir -p $preptmpdir
        $BASE_DIR/replace_filename.sh $SF <$BASE_DIR/tpch_prepare/$preparemod/${query}.impala >$preptmpdir/${query}.impala
		$TIME_CMD $IMPALA_CMD --query_file=$preptmpdir/${query}.impala 2>&1 | tee -a $LOG_FILE | grep '^Time:'
                returncode=${PIPESTATUS[0]}
		if [ $returncode -ne 0 ]; then
			echo "ABOVE QUERY FAILED:$returncode"
		fi

		# If you want to use old beta, enable below.
		#$TIME_CMD $IMPALA_CMD -q 'refresh' 2>&1 | tee -a $LOG_FILE | grep '^Time:'
                #returncode=${PIPESTATUS[0]}
		#if [ $returncode -ne 0 ]; then
		#	echo "ABOVE QUERY FAILED:$returncode"
		#fi

        # add set codegen on/off to query code
        querytmpdir=$BASE_DIR/tpch_impala/tmp
        mkdir -p $querytmpdir
        if [[ $DISABLE_CODEGEN -eq 1 ]]; then
            cat $BASE_DIR/disable_codegen_snippet.impala $BASE_DIR/tpch_impala/${query}.impala  >$querytmpdir/${query}.impala
        else
            cp $BASE_DIR/tpch_impala/${query}.impala $querytmpdir/${query}.impala
        fi
            
        echo "Running Impala query: $query" >> $LOG_FILE
        $TIME_CMD $IMPALA_CMD --query_file=$querytmpdir/${query}.impala 2>&1 | tee -a $LOG_FILE | grep '^Time:'
        echo "  -- and a second time: $query" >> $LOG_FILE
        $TIME_CMD $IMPALA_CMD --query_file=$querytmpdir/${query}.impala 2>&1 | tee -a $LOG_FILE | grep '^Time:'
        #$TIME_CMD $IMPALA_CMD --query_file=$BASE_DIR/tpch_impala/${query}-2.impala 2>&1 | tee -a $LOG_FILE | grep '^Time:'
            
                returncode=${PIPESTATUS[0]}
		if [ $returncode -ne 0 ]; then
			echo "ABOVE QUERY FAILED:$returncode"
		fi

		#echo "Running Hive query: $query" >> $LOG_FILE
		#$TIME_CMD $HIVE_CMD -f $BASE_DIR/tpch_hive/${query}.hive 2>&1 | tee -a $LOG_FILE | grep '^Time:'
                #returncode=${PIPESTATUS[0]}
		#if [ $returncode -ne 0 ]; then
		#	echo "ABOVE QUERY FAILED:$returncode"
		#fi
	done

done # TRIAL
echo "***********************************************"
echo ""
