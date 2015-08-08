sf=100
tablesdir=$HOME/escience/tpch_2_17_0/dbgen/sf$sf

# turn the .tbl files into directories of 1 file (expected format for external tables)
mkdir -p $tablesdir/hive/$sf

pushd $tablesdir
for i in *.tbl; do
    dir=hive/$sf/`basename $i .tbl`
    mkdir -p $dir
    cp $i $dir/part-00000
done
popd

hadoop fs -mkdir -p /user/bdmyers/tpch/hive
hadoop fs -copyFromLocal $tablesdir/hive/$sf /user/bdmyers/tpch/


