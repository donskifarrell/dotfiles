# Asus ROG Rapture GT-AX6000

Fancy router to do some fancy things. This is a running document of bits + pieces needed to setup the router if it ever needs reset.

## Basic Setup

### 1. Update Firmware

Flash the stock Asus firmware with latest from https://www.asuswrt-merlin.net/

Installation page at: https://github.com/RMerl/asuswrt-merlin.ng/wiki/Installation but it's fairly easy stuff.

### 2. Restore config

Note: Might not be necessary

Navigate to Administation -> Restore/Save/Upload Setting (https://192.168.50.1:8443/Advanced_SettingBackup_Content.asp)

Two files:

- Settings_GT-AX6000.CFG
- backup_jffs.tar (need a ext4 USB inserted)

### 3. SSH Setup

Navigate to Administation -> System (https://192.168.50.1:8443/Advanced_System_Content.asp) and enable SSH for LAN only, port 22

Add authorised key:

`ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIIBTZdJljYv/dYfn3VJk3hSwyYTU4LQowFTYXrgWChPJ gt-ax6000`

### 4. Format USB

If not done already, we need a USB drive formatted to ext4 filesystem.
SSH into router, then run `amtm` and select `fd` to format the USB drive.

After formatting and rebooting, create a swap file. Run `amtm` then `sw` and run through options, selecting 5GB option.

### 5. Entware

If you didn't restore the backup we need a new install of Entware.
Plug in the USB device, then SSH into router. Run `amtm` command, install Entware

### 6. Wireguard

Using Entware, install Wireguard Session Manager

> Note: During the install, you can add server peer configs for external devices. This is to allow them to connect _to_ the router

From local .ssh folder, copy over the apple-tv wireguard config:

`scp gig-vps-asus-apple-tv.conf asus:/opt/etc/wireguard.d/`

Now you need to import the config:

`import ?` to see a list of configs

`import gig-vps-asus-apple-tv.conf name=wg11`

- be sure to test! (`start wg11` then `stop wg11`)

You can see details of the client with `peer wg11`

> Note: upon restarting the router, the server interface (wg21) is started automatically. Unsure about the client interface (wg11)

### 7. x3mRouting

Using Entware, install x3mRouting (https://github.com/Xentrk/x3mRouting)

In the x3mRouting menu, install both:

- OpenVPN Event & x3mRouting.sh Script
- Install x3mRouting Utility Scripts

## Selective Routing Setup

Follow for setting up certain IP addresses to run through the Wireguard client VPN

1. Add the `dnsmasq.conf.add` file - see file for steps

`scp dnsmasq.conf.add asus:/jffs/configs/`

`service restart_dnsmasq`

2. Add the `nat-start` script - see file for steps

`scp nat-start asus:/jffs/scripts/`

`chmod +x /jffs/scripts/nat-start`

### Create IPSet

Next, we need to setup the IPSet list for each filter we want. Taken mostly from https://github.com/ZebMcKayhan/WireguardManager#create-and-setup-ipsets

#### Quick IPSet Creation

x3mRouting gives us a nice quick way to create IPSets. It's built to create OpenVPN rules too, but we can skip that part.

> List of commands to run taken from https://www.snbforums.com/threads/x3mrouting-liststats-ipset-becoming-0-after-reboot.77933/post-757102

`sh /jffs/scripts/x3mRouting/x3mRouting.sh ipset_name=BBC-ASN asnum=AS2818,AS31459,AS2906 #AS2906 also Netflix`

#### For Manual Creation

1. Create IPSet list

`ipset create IPLAYER hash:net family inet # ipv4 addresses`

> Note the name (e.g IPLAYER) needs to match the name in `nat-script`

2. Add at least one entry

`ipset add IPLAYER 52.84.248.103`

3. Save initial list

`ipset save IPLAYER > /opt/tmp/IPLAYER`

4. Restart dnsmasq

`service restart_dnsmasq`

You can view all IPSets with

`ipset list` or specific lists with `ipset list IPLAYER`

If you need to restore an IPSet file, use `ipset restore -! < /opt/tmp/IPLAYER`

### Scan for domains/IPs

We need to figure out what domains are used by the service we want to filter. Unfortunately this a test-retry-test loop until we can it working. Use `restart wg11`

See `getdomainnames.sh` at https://github.com/Xentrk/x3mRouting#4-x3mrouting-utility-scripts-1

1. Navigate to the scripts folder

`cd /jffs/scripts/x3mRouting`

2. Run getdomains script

`sh getdomainnames.sh` - put in filename and Apple-TV IP address

3. Start using the desired app on the Apple TV

4. Stop the script. The list of domains recorded will be output.

5. Add the relevant domains to the `dnsmasq.conf.add` IPSet list

6. Run the Wireguard interface a few time to build up a list in `ipset list` then save the file e.g `ipset save IPLAYER > /opt/tmp/IPLAYER`

> Note: Make sure we have the Wireguard interface turned off, otherwise we don't see traffic - from my testing at least it doesn't work

### Add IPSet to Wireguard interface

Now add the IPSets to the Wireguard client interface to route those specific IPs through the VPN. Taken mostly from https://github.com/ZebMcKayhan/WireguardManager#create-rules-in-wgm

1. Add the IPSets to the interface peer

`peer wg11 add ipset IPLAYER`
`peer wg11 add ipset BBC-ANS`

2. Verify it's been added correctly. You should see it in the selective routing section

`peer wg11`

3. Start the VPN

`start wg11`

4. Test!

> Keep an eye on the IPSet entries and also perform domain name scans to get a more complete list.

### Removing IPSet lists

To remove an IPSet, make sure we remove it from the Wireguard interface, e.g

`peer wg12 del ipset IPLAYER`

Then, we can flush entries and attempt to destroy it:

`ipset flush IPLAYER`

`ipset destroy IPLAYER`

Note: for IPSets, once set, cannot be removed using `ipset destroy X` command even after flushing entries. You need to disable `nat-start` script and restart the router for them to clear properly.

## Misc

Using Entware, install:

`opkg install logrotate`

## Links

Shout out to these great resources, where I copied most steps:

https://github.com/MartineauUK/wireguard#wireguard

https://www.snbforums.com/forums/

https://github.com/ZebMcKayhan/WireguardManager#create-and-setup-ipsets

https://github.com/Xentrk/x3mRouting#4-x3mrouting-utility-scripts-1
