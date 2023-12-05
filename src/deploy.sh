# Download challenge files
wget --user redacted --password 'redacted' -O /chall.zip https://redacted/chall.zip
echo "Challenge files downloaded"

# Unzip challenge files
apt-get update
apt-get -y install unzip
unzip -P YBfrtdSQzxKGna62y7LUbN /chall.zip -d /

# Change files permissions
chmod 700 -R /chall
rm /chall.zip
echo "Challenge files unzipped with correct permissions"

# install dependencies
apt-get -y install python3-pip python3 can-utils iproute2 nano htop
pip install scapy
echo "Dependencies installed"

# Run challenge as a service
cp /chall/chall.service /etc/systemd/system/
systemctl daemon-reload
systemctl enable chall.service
systemctl start chall.service
echo "Challenge service started"

# Create unprivileged user
useradd -m haxxor
echo "haxxor:ZCqjgYd3B69SD8tRz5GKnX" | chpasswd 
chown -R haxxor:haxxor /home/haxxor
echo "Unprivileged user created"

