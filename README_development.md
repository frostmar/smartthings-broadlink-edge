# Development Readme

## References
Broadlink protocol
- https://blog.ipsumdomus.com/broadlink-smart-home-devices-complete-protocol-hack-bc0b4b397af1
- https://github.com/mjg59/python-broadlink/
- https://github.com/csabavirag/broadlink-dissector -- wireshark protocol dissector

SmartThings Edge drivers
- https://github.com/toddaustin07 -- source for various drivers
- https://community.smartthings.com/t/tutorial-creating-drivers-for-lan-devices-with-smartthings-edge/229501

SmartThings CLI
- https://developer.smartthings.com/docs/sdks/cli/introduction/


## Build & debug cheatsheet
```
smartthings edge:drivers:package . -I

smartthings edge:drivers:install

smartthings edge:drivers:installed

smartthings edge:drivers:logcat $DRIVER_UUID --hub-address $SMARTTHINGS_HUB_IP
```
