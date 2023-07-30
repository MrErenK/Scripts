# Useful shell scripts to make AOSP/kernel development easy for begonia (Other devices can use aswell, you need to do some changes)

*To build kernel*:
- Clone kernel source & cd into it
- Clone this repo and move config.env, kranul-build.sh and KSU.patch to main kernel source path
- Check config.env, do your changes and run kranul-build.sh

*To use setup aosp env script*:
- run `wget https://raw.githubusercontent.com/MrErenK/Scripts/main/aosp/setup-aosp-environment.sh && chmod +x ./setup-aosp-environment.sh && ./setup-aosp-environment.sh`

It's better to use those scripts with Ubuntu 22.04+
