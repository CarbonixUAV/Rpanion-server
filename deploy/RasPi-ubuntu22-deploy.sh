#!/bin/bash

set -e
set -x

git submodule update --init --recursive

## Change hostname
sudo hostnamectl set-hostname rpanion --static

## Enable serial port
sudo perl -pe 's/console=serial0,115200//' -i /boot/firmware/cmdline.txt 

echo "export PATH=$PATH:$HOME/.local/bin" >> ~/.bashrc

## Power switch config for Pi-Connect
echo "" | sudo tee -a /boot/firmware/config.txt >/dev/null
echo "# Power switch" | sudo tee -a /boot/firmware/config.txt >/dev/null
echo "dtoverlay=gpio-shutdown" | sudo tee -a /boot/firmware/config.txt >/dev/null
echo "dtoverlay=gpio-poweroff" | sudo tee -a /boot/firmware/config.txt >/dev/null
sudo perl -pe 's/dtparam=i2c_arm=on/dtparam=i2c_arm=off/' -i /boot/firmware/config.txt 

## CSI Camera - not working for now (Ubuntu issue ... not fixable at my end)
#echo "" | sudo tee -a /boot/firmware/config.txt >/dev/null
#echo "# Enable Camera" | sudo tee -a /boot/firmware/config.txt >/dev/null
#echo "start_x=1" | sudo tee -a /boot/firmware/config.txt >/dev/null
#echo "gpu_mem=128" | sudo tee -a /boot/firmware/config.txt >/dev/null

## Need to temp disable this
sudo systemctl stop unattended-upgrades.service

## Remove this to disable the "Pending Kernel Upgrade" message
sudo apt -y remove needrestart

## Packages
./install_common_libraries.sh
sudo apt install -y wireless-tools

sudo systemctl disable dnsmasq

curl -sL https://deb.nodesource.com/setup_18.x | sudo -E bash -
sudo apt install -y nodejs

## Configure nmcli to not need sudo
sudo sed -i.bak -e '/^\[main\]/aauth-polkit=false' /etc/NetworkManager/NetworkManager.conf

## Ensure nmcli can manage all network devices
sudo touch /etc/NetworkManager/conf.d/10-globally-managed-devices.conf
echo "[keyfile]" | sudo tee -a /etc/NetworkManager/conf.d/10-globally-managed-devices.conf >/dev/null
echo "unmanaged-devices=*,except:type:wifi,except:type:gsm,except:type:cdma,except:type:wwan,except:type:ethernet,type:vlan" | sudo tee -a /etc/NetworkManager/conf.d/10-globally-managed-devices.conf >/dev/null

## Need this to get eth0 working too
## From https://askubuntu.com/questions/1290471/ubuntu-ethernet-became-unmanaged-after-update
sudo touch /etc/netplan/networkmanager.yaml
echo "network:" | sudo tee -a /etc/netplan/networkmanager.yaml >/dev/null
echo "  version: 2" | sudo tee -a /etc/netplan/networkmanager.yaml >/dev/null
echo "  renderer: NetworkManager" | sudo tee -a /etc/netplan/networkmanager.yaml >/dev/null
sudo netplan generate
sudo netplan apply

## mavlink-router
./build_mavlinkrouter.sh

## and build & run Rpanion
./build_rpanion.sh

## For wireguard. Must be installed last as it messes the DNS resolutions
sudo apt install -y resolvconf

## And re-enable
sudo systemctl start unattended-upgrades.service

sudo reboot
