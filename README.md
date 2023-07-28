# Useful shell scripts to make AOSP/kernel development easy for begonia

*To build kernel*:
- Clone kernel source & cd into it
- Clone this repo and move config.env, kranul-build.sh and KSU.patch to main kernel source path
- Check config.env, do your changes and run kranul-build.sh

*To use setup aosp env script*:
- run `wget https://raw.githubusercontent.com/MrErenK/Scripts/main/setup-aosp-environment.sh && chmod +x ./setup-aosp-environment.sh && ./setup-aosp-environment.sh`

It's better to use those scripts with Ubuntu 22.04+
