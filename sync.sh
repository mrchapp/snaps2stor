#!/bin/bash

set -x
set -e

which wget >/dev/null
which jq >/dev/null
which aws
ls -l ~/dir2bundle/dir2bundle

SERVER="https://snapshots.linaro.org"
PATHS=(
  openembedded/lkft/lkft/sumo/am57xx-evm/lkft/linux-stable-rc-5.6/25/
  openembedded/lkft/lkft/sumo/dragonboard-410c/lkft/linux-stable-rc-5.6/25/
  openembedded/lkft/lkft/sumo/hikey/lkft/linux-stable-rc-5.6/25/
  openembedded/lkft/lkft/sumo/intel-core2-32/lkft/linux-stable-rc-5.6/25/
  openembedded/lkft/lkft/sumo/intel-corei7-64/lkft/linux-stable-rc-5.6/25/
  openembedded/lkft/lkft/sumo/juno/lkft/linux-stable-rc-5.6/25/
  openembedded/lkft/lkft/sumo/ls2088ardb/lkft/linux-stable-rc-5.6/25/
)
DESTINATION="s3://storage.lkft.org/snapshots"
SCRATCH=scratch

for path in ${PATHS[@]}; do
    for file in $(curl -s -L $SERVER/api/ls/$path | jq -r ".files[].url"); do
        if [ -f $SCRATCH$file ]; then
            continue
        fi
        if echo "$file" | grep -q '/$'; then
            # XXX Directories not supported
            # Add the paths to PATHS above to get them copied.
            echo "skipping directory $file"
            continue
        fi
        mkdir -p $SCRATCH$(dirname $file)
        echo "Downloading $SERVER$file to $SCRATCH$file"
        wget -qc -P $SCRATCH$(dirname $file) $SERVER$file
    done
done

echo
echo

find -name MD5SUMS.txt -o -name SHA256SUMS.txt -print -exec sed -i -e '/MD5SUMS.txt/d' -e '/SHA256SUMS.txt/d' -e '/HEADER.textile/d' {} \;

for md5file in $(find $SCRATCH -name MD5SUMS.txt); do
    dir=$(dirname $md5file)
    file=$(basename $md5file)
    echo "Checking checksums in $dir"
    pushd $dir
    md5sum --ignore-missing --check $file
    popd
done

for shafile in $(find $SCRATCH -name SHA256SUMS.txt); do
    dir=$(dirname $shafile)
    file=$(basename $shafile)
    echo "Checking checksums in $dir"
    pushd $dir
    sha256sum --check $file
    popd
done

mkdir -p rootfs/oe-sumo/20200425
for machine_dir in scratch/openembedded/lkft/lkft/sumo/*; do
    MACHINE=$(basename ${machine_dir})
    mv -v ${machine_dir}/lkft/linux-stable-rc-5.6/25 rootfs/oe-sumo/20200425/${MACHINE}
    pushd rootfs/oe-sumo/20200425/${MACHINE}
    ls | ~/dir2bundle/dir2bundle
    popd
done

#echo aws s3 sync --acl public-read $SCRATCH/ $DESTINATION/
echo aws s3 sync --acl public-read rootfs/oe-sumo/20200425/ $DESTINATION/rootfs/oe-sumo/20200425/
