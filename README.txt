apt install  awscli jq rsync wget

echo 'http://snapshots.linaro.org/openembedded/lkft/lkft/sumo/juno/lkft/linux-stable-rc-5.6/52/' > urls.txt
./sync.sh
