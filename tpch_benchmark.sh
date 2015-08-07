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
echo "Code generation disabled? $DISABLE_CODEGEN"

trial=0
while [ $trial -lt $NUM_OF_TRIALS ]; do
	trial=`expr $trial + 1`
	echo "Executing Trial #$trial of $NUM_OF_TRIALS trial(s)..."

	for query in ${TPCH_QUERIES_ALL[@]}; do
		echo "Running query: $query" | tee -a $LOG_FILE

		echo "Running Hive prepare query: $query" >> $LOG_FILE
		#$TIME_CMD $HIVE_CMD -f $BASE_DIR/tpch_prepare/${query}.hive 2>&1 | tee -a $LOG_FILE | grep '^Time:'
        # use impala instead of hive for DDL because its way faster
        # also use .impala which are the modified queries
		$TIME_CMD $IMPALA_CMD --query_file=$BASE_DIR/tpch_prepare/${query}.impala 2>&1 | tee -a $LOG_FILE | grep '^Time:'
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
            querytmpdir=$BASE_DIR/tpch_impala/tmp
            cat $BASE_DIR/disable_codegen_snippet.impala $BASE_DIR/tpch_impala/${query}.impala >$querytmpdir/${query}.impala
        else
            cp $BASE_DIR/tpch_impala/${query}.impala $querytmpdir/
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
