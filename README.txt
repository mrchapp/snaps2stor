# remote server
apt install  awscli jq rsync wget

git clone https://gitlab.com/mrchapp/dir2bundle.git ~/dir2bundle
echo 'http://snapshots.linaro.org/openembedded/lkft/lkft/sumo/juno/lkft/linux-stable-rc-5.6/52/' > urls.txt
./sync.sh

# local desktop
linaro-sso-login
assume-lkft-admin
set | grep ^AWS
