# austrumi-ko

**English** | [한국어](README.ko.md)

A single script that remasters the [AUSTRUMI](https://ftp.linux.edu.lv/austrumi/) 5.3.0 live ISO into an English-language system with Korean (Hangul) input and Korean fonts.

AUSTRUMI is a small Slackware-based live Linux from Latvia that runs entirely from RAM. Out of the box it starts in Latgalian, has no Korean input method and no Korean fonts. This script fixes that and writes a new bootable ISO.

> **Status: tested only in QEMU.** It has not been written to a USB stick or DVD and booted on a real PC. See [What is tested](#what-is-tested) and [Known issues](#known-issues) before relying on it.

## What the remastered ISO has

| Area | Result |
|---|---|
| Language | English interface (`en_US.utf8`) on every boot entry |
| Hangul input | fcitx5 with fcitx5-hangul; **Right Alt** (the Hangul key) or Ctrl+Space toggles |
| Keyboard | US layout; Right Alt = Hangul key, Right Ctrl = Hanja key |
| Fonts | Noto Sans KR, Noto Serif KR (Regular + Bold), NanumSquare |
| Font names | Documents that ask for "Noto Sans CJK KR" / "Noto Serif CJK KR" are shown with the KR fonts |
| Desktop | Boots straight into FVWM2 as user `austrumi`, no login screen |
| Time | Time zone Asia/Seoul; an extra boot entry for PCs whose clock is in UTC |
| Windows | New windows are kept beside FVWM's left panel; LibreOffice's saved 1920×1080 window size is removed |
| Start menu | The category row beside the top-left icon stays open while the pointer is on the icon or the row |
| Size | About 603 MB (original 574 MB). All of it is loaded into RAM at boot |

## Requirements

- A Debian/Ubuntu-family Linux host (written and used on Xubuntu 26)
- `sudo apt install xorriso squashfs-tools curl xz-utils`
- The original ISO, `austrumi64-5.3.0.iso`, from <https://ftp.linux.edu.lv/austrumi/>
- Internet access during the build (about 70 MB of packages and fonts)
- About 2.5 GB free on a **Linux filesystem** (ext4 etc.) for the unpacked system, by default in `/var/tmp`
- About 1.4 GB free in the folder that holds the ISO (any filesystem, an NTFS drive is fine)
- NanumSquare is copied from your own computer (`sudo apt install fonts-nanum` provides it); if it is not installed the script fetches that package itself

## Build

```bash
chmod +x austrumi-ko.sh
sudo ./austrumi-ko.sh /path/to/austrumi64-5.3.0.iso
```

The result is `austrumi64-5.3.0-ko.iso` next to the original. A build takes a few minutes. The script never changes the original ISO and removes its work files when it finishes.

### Options

Write them right after `sudo`, for example `sudo NOBOLD=1 AUTOLOGIN=Wayfire ./austrumi-ko.sh file.iso`.

| Option | Default | Meaning |
|---|---|---|
| `AUTOLOGIN` | `FVWM2` | Desktop started without a login prompt: `FVWM2`, `Wayfire`, `LabWC`, `Sway`, or `none` to keep the login screen |
| `TZNAME` | `Asia/Seoul` | Time zone, copied from the host's `/usr/share/zoneinfo` |
| `RTC` | `localtime` | `utc` treats the PC clock as UTC on every boot entry (for your own Linux-only PC; do not publish such an ISO) |
| `NOBOLD` | `0` | `1` leaves out the Bold weights of the Noto fonts (saves about 13 MB of RAM) |
| `NANUM_DIR` | – | Folder holding `NanumSquare*.ttf` if the script cannot find them |
| `WORKDIR` | `/var/tmp` | Where the system is unpacked; must be a Linux filesystem |
| `PAUSE` | `0` | `1` stops before repacking so you can edit files by hand |
| `KEEP` | `0` | `1` keeps the work files |

## Test in QEMU

```bash
qemu-system-x86_64 -enable-kvm -cpu host -m 4G -rtc base=localtime -cdrom austrumi64-5.3.0-ko.iso
```

Each option matters:

- `-cpu host`: without it AUSTRUMI stops with *"Fatal glibc error: CPU does not support x86-64-v2"*.
- `-m 4G`: QEMU's default memory is far too small; the system copies about 600 MB into RAM and hangs at that stage.
- `-rtc base=localtime`: makes the virtual clock behave like a Windows PC, so boot entry 1 shows the right time.

## Using it

- Login, if asked: user `austrumi`, password `austrumi`.
- **Right Alt** switches between English and Hangul. Ctrl+Space does the same.
- Boot menu: entry 1 starts FVWM2. **Entry 5** is the same but for PCs whose hardware clock holds UTC (Linux-only PCs). Use it if the clock is 9 hours behind with entry 1.
- In FVWM: hover the top-left icon to open the start-menu row, then move onto it. Alt + left-drag moves a window, Alt + right-drag resizes it, double-click on a title bar maximizes it beside the panel.

## How it works

The AUSTRUMI 5.3.0 ISO keeps its system in two files, and the script patches both:

- `/austrumi/austrumi.fs`: a squashfs holding only `bin lib lib64 sbin usr`. Programs, fonts and keyboard data go here.
- `/austrumi/austrumi.tgz`: everything else (`etc`, `var`, …). Its `etc/skel` becomes the home folder of `root` and `austrumi` at boot, so all settings go there.

Steps: mount the ISO, unpack both files, assemble them the way AUSTRUMI's own init does, install Slackware-current packages (`libhangul`, `xcb-imdkit`, `fcitx5`, `fcitx5-hangul`, `fcitx5-gtk`), add fonts, write the settings, repack both files, and rebuild the ISO with `xorriso`, replaying the original boot record.

## What is tested

Confirmed by booting the ISO in QEMU (BIOS boot, 1280×800):

- Boots, English menus, automatic login
- Hangul input with fcitx5 in a text editor and LibreOffice Writer
- Korean fonts display; the CJK font-name mapping works in Writer
- FVWM2 session, US flag in the panel, Seoul time
- LibreOffice Writer opens beside the panel at a size that fits the screen
- US keyboard layout with Right Alt as the Hangul key
- The start-menu row stays open while the pointer is on the icon or the row, and closes when it leaves

Not tested at all:

- Booting from a USB stick or DVD on a real PC
- UEFI boot
- The LabWC, i3 and E16 sessions, and FVWM themes other than the default

## Known issues

| Symptom | Cause and what to do |
|---|---|
| *CPU does not support x86-64-v2* | QEMU without `-cpu host`; on a real PC the CPU is too old for AUSTRUMI 5.x |
| Hangs while copying to RAM | Not enough memory. Give QEMU `-m 4G`, or add `nocache` to the boot line |
| Clock is 9 hours behind | The PC clock holds UTC. Use boot entry 5, or build with `RTC=utc` for yourself |
| Build stops at a download | A mirror failed. The script tries five Slackware mirrors; run it again |
| *work folder … cannot hold Linux owners* | `WORKDIR` is on NTFS/exFAT/FAT. Point it at a folder on a Linux disk |
| ISO does not boot under UEFI | The ISO has a BIOS boot record only, exactly like the original. The UEFI files (`/EFI/BOOT`, rEFInd) are on it for USB installs done the AUSTRUMI way, which is untested here |
| `name mapping: … -> ?` during the build | Harmless. The image has no `fc-match` tool, so the check cannot run |
| Windows vanish while dragged in Wayfire (QEMU) | Probably the wobbly-windows effect without graphics acceleration; not caused by this script |
| Windows cannot be dragged in Sway | Sway is a tiling window manager; that is how it works |
| Tray shows "kr" in English mode | The image's keyboard rules lack `korean:ralt_hangul`, so the script fell back to the `kr(kr104)` layout (it prints a NOTE) |
| Right Alt stops toggling | Use Ctrl+Space and please open an issue |
| Start-menu row vanishes or stays open | The row fix misbehaves in your setup. The build prints a WARNING if it could not be added; otherwise please open an issue |
| Build fails after some months | Packages come from **slackware64-current**, which keeps changing. A newer fcitx5 may need libraries this AUSTRUMI release lacks; the build prints a WARNING listing them |

Limits to keep in mind:

- The script is written against the file layout of **AUSTRUMI 5.3.0**. Other releases may differ; the script stops if it does not find the expected files.
- Only the default FVWM theme (`fvwm2rc_5`) gets the window fitting and the start-menu fix.
- The Noto fonts are the Korean-only builds. They cover Hangul and the hanja used in Korea, not Chinese- or Japanese-only characters.

## Licenses and credits

- The script: MIT, see [LICENSE](LICENSE).
- [AUSTRUMI](https://ftp.linux.edu.lv/austrumi/) and the Slackware packages keep their own licenses. A remastered ISO contains all of them; check those licenses before you redistribute an ISO.
- [Noto CJK](https://github.com/notofonts/noto-cjk) fonts: SIL Open Font License 1.1.
- NanumSquare (NAVER): SIL Open Font License 1.1.
- [fcitx5](https://github.com/fcitx/fcitx5) and fcitx5-hangul, libhangul: their respective free licenses.

This script was developed step by step in a conversation with Claude (Anthropic's AI assistant), by inspecting the real ISO and testing each build in QEMU.
