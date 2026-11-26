# Aqara Cube T1 Pro – Automate Prime Edition

A SmartThings Edge Zigbee driver for the Aqara Cube T1 Pro (LUMI `lumi.remote.cagl02`).

The driver decodes face changes, shake, slides, double taps, 90° and 180° flips, scene flips, and clockwise or counterclockwise rotation. Which gestures the Cube reports depends on its mode. To request a mode change, set **Request Cube mode** in device settings. Tap the Cube’s LINK button once or wait for the next check-in.

## Building from source

The Edge driver files are at the repository root. The profile references SmartThings capabilities `concerttheme23846.cubeActionExtended` and `stse.cubeFace`. If developing under another SmartThings namespace, register the extended action capability and its presentation from the JSON files in `capabilities/` and update the capability ID in the device profile and `src/init.lua`.

## Credits and license

Maintained by **Automate Prime**, with assistance from ChatGPT. Based on the [Aqara Cube driver in SmartThings Edge Drivers](https://github.com/SmartThingsCommunity/SmartThingsEdgeDrivers/tree/564d8779cbf8fe83d537e973cf1737dcbda0bced/drivers/Aqara/aqara-cube), credited to its original developers and contributors.

This edition modifies the original driver to target the T1 Pro, adds gesture and rotation decoding, extends SmartThings action events, and adds a mode request preference. Distributed under the [Apache License 2.0](LICENSE).
