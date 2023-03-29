# SmartThings edge driver for Broadlink IR Remote

This is a driver for Samsung SmartThings home automation hubs, allowing a hub to find and control a Broadlink learning Infrared remote. It's a SmartThings "edge" driver (written in LUA, runs on the hub).


## Limitations
⚠️ This is a very basic proof-of-concept. It was a hobby project when a firmware update stopped my TV supporting wake-on-lan reliably. It's only writen and tested with the single Broadlink device I had, and isn't particularly user-friendly.

- Only supports the Broadlink "RM mini 3" device  
  Specifically, devices that report a deviceId listed in [src/devicetypes.lua](./src/devicetypes.lua)). Small protocol differences mean even similar-ish products such as the "RM4 mini" are unlikely to work without changes.
- Only supports discovery of a single Broadlink device on the network
- Probably riddled with bugs
- Unlikely to be maintained or extended  
  I don't have the time or enthusiasm to add support for other devices, or get involved with fixing bugs you may find. If this works for you as you find it, or you'd like to change and extend it, that's great.


## Use
1. Install the driver to your SmartThings account. Either:
   1. Use the source here to compile your own driver
   1. Use invite url https://bestow-regional.api.smartthings.com/invite/Pw2D66Qadbj3 to add `frostmar Shared Drivers` channel to your hub; from the list of available drivers install driver `Broadlink Remote`
2. In your SmartThings mobile app, `Add a device` → `Scan`
3. A `Broadlink Remote` device will immediately be created (if a supported Broadlink IR remote is found on the local network)
   This is a parent device, use it's options to learn adn display a remote code, and to create one or more "Virtual remote" devices.
4. In the app, select `Broadlink Remote` device, to: 
   - Use it's `learn code` button to put the Broadlink into learning mode, the next IR code received will be recorded and displayed.
   - View the last code learned  
     As of Dec 2023 it's not possible to copy values shown in the mobile app, so go to https://my.smartthings.com/ to copy a learned code from the device history on the web dashboard 
   - Use it's `NewVirtualRemoteDevice` to create a new device. Each device has a single momentary button, which can be configured to send a single remote code


## Developers

This code is at a very basic proof-of-concept level. Please do fork/extend/improve. The Broadlink protocol is fairly similar for many different devices, with a few tweaks and testing the same approach could run different device types, as well as other remote models.
See [README_development](./README_development.md) for some notes.


## Dependencies
Embeds encryption from the `smartthings_edge` branch of `lua-lockbox` - https://github.com/rtyle/lua-lockbox/blob/smartthings-edge/lockbox/init.lua  
Many thanks to Ross Tyler for the SmartThings-compatible fork of this useful libray.
