set -o nounset

f=$1
sf=$2
sed -e 's/__DIR__/'$sf'/' $f >$f.run
