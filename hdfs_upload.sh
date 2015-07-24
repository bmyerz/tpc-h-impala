tablesdir=$HOME/escience/tpch_2_17_0/dbgen/sf10

# turn the .tbl files into directories of 1 file (expected format for external tables)
mkdir -p $tablesdir/hive

pushd $tablesdir
for i in *.tbl; do
    dir=hive/`basename $i .tbl`
    mkdir -p $dir
    cp $i $dir/part-00000
popd

hadoop fs -mkdir -p /user/bdmyers/tpch
hadoop fs -copyFromLocal $tablesdir/hive /user/bdmyers/tpch/


