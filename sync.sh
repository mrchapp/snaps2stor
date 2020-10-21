#!/bin/bash

#set -x
set -e

which wget >/dev/null
which jq >/dev/null
which rsync >/dev/null
which aws
which pigz >/dev/null
which simg2img >/dev/null

ls -l ~/dir2bundle/dir2bundle
ls -l urls.txt

declare -a URLS
readarray -t URLS < urls.txt
DESTINATION="s3://storage.lkft.org/"
SCRATCH=scratch

for url in ${URLS[@]}; do
    SERVER="$(echo "${url}" | cut -d/ -f1-3)"
    path="$(echo "${url}" | cut -d/ -f4-)"
    for file in $(curl -s -L $SERVER/api/ls/$path | jq -r ".files[].url"); do
        if [ -f $SCRATCH/$file ]; then
            continue
        fi
        if echo "$file" | grep -q '/$'; then
            # XXX Directories not supported
            echo "skipping directory $file"
            continue
        fi
        mkdir -p $SCRATCH/$(dirname $file)
        echo "Downloading $SERVER/$file to $SCRATCH/$file"
        wget -qc -P $SCRATCH/$(dirname $file) $SERVER/$file
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

find -name "rpb-console-image-lkft-*" | while read -r file_path; do
    base="$(basename ${file_path})"
    case ${base} in
        *.img.gz)
            echo "IMG: $base"
            pigz -T0 -d "${file_path}"
            simg2img ${file_path%%.gz} new.raw.ext
            mount -o loop new.raw.ext /mnt/ && rm -rf /mnt/opt/kselftests/ /mnt/lib/modules/ && umount /mnt
            img2simg new.raw.ext ${file_path%%.gz}
            pigz -T0 ${file_path%%.gz}
            ;;
        *.tar.xz)
            echo "TAR: $base"
            xz -d -c "${file_path}" | tar -f - --delete ./opt/kselftests ./lib/modules | xz -zc > new.tar.xz
            mv -v new.tar.xz "${file_path}"
            ;;
        *.ext*.gz)
            echo "EXT: $base"
            pigz -T0 -d "${file_path}"
            mount -o loop,rw "${file_path%%.gz}" /mnt && rm -rf /mnt/opt/kselftests/ /mnt/lib/modules/ && umount /mnt
            pigz -T0 "${file_path%%.gz}"
            ;;
        *)
            echo "UNK: $base"
            ;;
    esac;
done

today="$(date +"%Y%m%d")"
mkdir -p rootfs/oe-sumo/${today}

# any url would do
machines_dir="$(echo "${url}" | cut -d/ -f4-7)"

for machine_dir in ${SCRATCH}/${machines_dir}/*; do
    MACHINE=$(basename ${machine_dir})
    rsync -axvP ${machine_dir}/*/*/*/ rootfs/oe-sumo/${today}/${MACHINE}/
    pushd rootfs/oe-sumo/${today}/${MACHINE}
    (ls | ~/dir2bundle/dir2bundle ${MACHINE} > bundle.json) ||:
    popd
done

#echo aws s3 sync --acl public-read $SCRATCH/ $DESTINATION/
echo aws s3 sync --acl public-read rootfs/oe-sumo/${today}/ $DESTINATION/rootfs/oe-sumo/${today}/
