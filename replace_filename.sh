set -o nounset

sf=$1
sed -e 's/__DIR__/sf'$sf'/'  
