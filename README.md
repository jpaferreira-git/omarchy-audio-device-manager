# Audio Devices for Omarchy

A bar widget for the Omarchy shell that lists your audio outputs and inputs and lets you:

- **Rename** a device: click its name, type, press Enter (Escape cancels).
- **Disable** a device with the switch, so it disappears from the system and from Omarchy's own audio menu. It stays listed here, grayed out, so you can turn it back on.
- **Reset** a device to its original name with the restore icon.

Omarchy's built-in audio panel picks the default device and sets the volume. This one handles the names and hides devices you never use.

The interface is in Brazilian Portuguese.

## Install

```bash
omarchy plugin add https://github.com/jpaferreira-git/omarchy-audio-device-manager.git --enable
```

It asks which bar section to place the widget in. To update later:

```bash
omarchy plugin update jferreira.audio-device-manager
```

Requires the Omarchy shell (tested on Omarchy 4.0.6), PipeWire, WirePlumber and `jq`, all of which Omarchy installs by default.

## How it works

The panel calls the `omarchy-audio-device-manager` script in this folder. You can also run it from a terminal:

```bash
adm=~/.config/omarchy/plugins/jferreira.audio-device-manager/omarchy-audio-device-manager
$adm list
$adm set-name <node-name> <sink|source> "<name>"
$adm set-disabled <node-name> <sink|source> <true|false>
$adm reset <node-name>
```

Each change rewrites `~/.config/wireplumber/wireplumber.conf.d/90-omarchy-audio-device-manager.conf` with WirePlumber rules (`node.description`, `node.nick`, `node.disabled`) and restarts `wireplumber.service`. Sound cuts out for a moment, and a Bluetooth audio device may disconnect and need reconnecting.

Your choices are stored in `~/.local/state/omarchy/audio-device-overrides.json`. The original device names are cached in `audio-device-known.json`, next to it, so a disabled device still shows a readable name.

A rename is tied to the device's PipeWire node name, which includes its port, USB serial number or Bluetooth address. If a device moves to another port, for example a TV on a different HDMI input, the name doesn't follow it.

## Uninstall

```bash
omarchy plugin remove jferreira.audio-device-manager
```

That removes the widget, but your renames and disabled devices stay in effect. To drop them too:

```bash
rm ~/.config/wireplumber/wireplumber.conf.d/90-omarchy-audio-device-manager.conf \
   ~/.local/state/omarchy/audio-device-overrides.json \
   ~/.local/state/omarchy/audio-device-known.json
systemctl --user restart wireplumber
```

## License

MIT
