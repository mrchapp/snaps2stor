# remote server
apt update
apt install  jq rsync unzip wget
mkdir -p ~/bin
curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
unzip awscliv2.zip
./aws/install --update -i ~/bin/aws-cli -b ~/bin

cd ~
wget https://raw.githubusercontent.com/mrchapp/snaps2stor/master/sync.sh
chmod +x sync.sh
git clone https://gitlab.com/mrchapp/dir2bundle.git ~/dir2bundle
for MACHINE in \
  am57xx-evm \
  beaglebone \
  dragonboard-410c \
  hikey \
  intel-core2-32 \
  intel-corei7-64 \
  juno \
  ls2088ardb
do
  echo "https://snapshots.linaro.org/openembedded/lkft/lkft/sumo/${MACHINE}/lkft/linux-mainline/3049/" >> urls.txt
done
./sync.sh

# local desktop
linaro-sso-login
assume-lkft-admin
set | grep ^AWS

# remote server
set -a
AWS_ACCESS_KEY_ID=key
AWS_SECRET_ACCESS_KEY=key
AWS_SESSION_TOKEN=token
set +a
~/bin/aws s3 sync --acl public-read rootfs/oe-sumo/20201013/ s3://storage.lkft.org/rootfs/oe-sumo/20201013/
