# make 2 changes to the original preparation files
# 1. drop if exists instead of unconditionally
# 2. change the location of tables from /tpch/lineitem to /tpch/user/<...>/tpch/sf<...>/lineitem


pushd tpch_prepare

for f in q*.hive; do
    sed $f -e 's/DROP TABLE/DROP TABLE IF EXISTS/g' -e 's/[/]tpch/\/user\/bdmyers\/tpch\/sf10/g' >`basename $f .hive`.impala
done

popd
