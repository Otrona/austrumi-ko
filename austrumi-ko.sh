#!/bin/bash
# austrumi-ko.sh v14 - remaster AUSTRUMI 5.3.0: English interface, Hangul font, fcitx5-hangul.
# Written against the real layout of austrumi64-5.3.0.iso:
#   /austrumi/austrumi.fs   squashfs (xz, 128K blocks) holding only bin lib lib64 sbin usr
#   /austrumi/austrumi.tgz  everything else (etc, var, ...); etc/skel becomes /root and /home/austrumi
#   /austrumi/isolinux.bin  the single (BIOS) El Torito boot image
# Host: Xubuntu 26.x.
#
#   sudo apt install xorriso squashfs-tools curl xz-utils
#   sudo ./austrumi-ko.sh ~/Downloads/austrumi64-5.3.0.iso
#   options, written right after "sudo":
#     WORKDIR=/some/folder  where the system is unpacked (default /var/tmp). Needs ~2.5 GB free and a
#                           Linux filesystem (ext4 ...): NTFS/exFAT/FAT drives lose owners and permissions.
#     PAUSE=1               stop and edit files by hand before the ISO is built
#     KEEP=1                keep the work files afterwards
#     NOBOLD=1              leave out the Bold weights of the two Noto fonts (saves about 13 MB of RAM)
#     NANUM_DIR=/folder     folder holding your NanumSquare*.ttf files, if the script cannot find them
#     AUTOLOGIN=FVWM2       desktop started without a login prompt on the first boot entry:
#                           FVWM2 (default), Wayfire, LabWC, Sway, or none to keep the login screen
#     TZNAME=Asia/Seoul     time zone (default Asia/Seoul; copied from this computer's /usr/share/zoneinfo)
#     RTC=utc               treat the PC's hardware clock as UTC on every boot entry. Default is "localtime",
#                           as in the original and right for PCs that also run Windows; boot entry 5
#                           (boot option clock_utc) is there for Linux-only PCs and plain QEMU.
#
# Result: austrumi64-5.3.0-ko.iso next to the original. The folder holding the ISO may be on any
# kind of drive (an external NTFS disk is fine) and needs ~1.4 GB free.

set -euo pipefail

ISO=$(readlink -f "${1:?usage: sudo $0 austrumi64-5.3.0.iso}")
OUT="${ISO%.iso}-ko.iso"
WORK="$(readlink -m "${WORKDIR:-/var/tmp}")/austrumi-ko-work"   # unpacked system: Linux filesystem only
BIG="$(dirname "$ISO")/austrumi-ko-tmp"                         # plain big files: any filesystem
FSROOT="$WORK/fs"        # unpacked austrumi.fs
SYS="$WORK/sys"          # unpacked austrumi.tgz, with the austrumi.fs dirs bound on top
SKEL="$SYS/etc/skel"

# Verified 2026-11-10 on mirrors.slackware.com (version numbers are looked up at run time)
MIRRORS="https://mirrors.slackware.com/slackware/slackware64-current/slackware64
https://mirrors.kernel.org/slackware/slackware64-current/slackware64
https://slackware.uk/slackware/slackware64-current/slackware64
https://slackware.osuosl.org/slackware64-current/slackware64
http://ftp.slackware.com/pub/slackware/slackware64-current/slackware64"
PKGS="libhangul xcb-imdkit fcitx5 fcitx5-hangul fcitx5-gtk"     # all in the x/ series
# Noto fonts, Korean-only builds (all Hangul, the hanja used in Korea, Latin): all four addresses
# answered on 2026-11-10. Family names are "Noto Sans KR" and "Noto Serif KR"; the CJK names used in
# documents ("Noto Sans CJK KR", "Noto Serif CJK KR") are mapped to them in /etc/fonts/fonts.conf.
# Sizes: Sans 4.6 + 4.8 MB, Serif 7.7 + 7.9 MB (Regular + Bold).
GH="https://raw.githubusercontent.com/notofonts/noto-cjk/main"
FONTS="Sans/SubsetOTF/KR/NotoSansKR-Regular.otf
Sans/SubsetOTF/KR/NotoSansKR-Bold.otf
Serif/SubsetOTF/KR/NotoSerifKR-Regular.otf
Serif/SubsetOTF/KR/NotoSerifKR-Bold.otf"
[ "${NOBOLD:-0}" = 1 ] && FONTS=$(echo "$FONTS" | grep -v -- '-Bold')
# NanumSquare is taken from this computer (Ubuntu package fonts-nanum: NanumSquareR.ttf, NanumSquareB.ttf)
AUTOLOGIN="${AUTOLOGIN:-FVWM2}"
TZNAME="${TZNAME:-Asia/Seoul}"

[ "$(id -u)" = 0 ] || { echo "run with sudo"; exit 1; }
case "$WORK" in *" "*) echo "the work folder path must not contain spaces"; exit 1;; esac
for t in xorriso unsquashfs mksquashfs curl xz tar findmnt; do
  command -v "$t" >/dev/null || { echo "missing tool: $t"; exit 1; }
done
[ -e "$OUT" ] && { echo "$OUT already exists, remove it first"; exit 1; }

unmount_all() {
  local m
  for m in $(findmnt -rno TARGET | grep "^$WORK/" | sort -r); do umount "$m" || umount -l "$m"; done
}
trap unmount_all EXIT
unmount_all
if findmnt -rno TARGET | grep -q "^$WORK/"; then echo "mounts still active under $WORK"; exit 1; fi
rm -rf --one-file-system "$WORK" "$BIG"
mkdir -p "$WORK/isomnt" "$WORK/cfg" "$WORK/pkg" "$SYS" "$BIG"

FSTYPE=$(findmnt -no FSTYPE -T "$WORK")
case "$FSTYPE" in
  ext2|ext3|ext4|btrfs|xfs|f2fs|zfs|jfs|reiserfs|bcachefs) ;;
  *) echo "work folder $WORK is on a '$FSTYPE' filesystem, which cannot hold Linux owners and permissions."
     echo "choose a folder on your Linux disk:  sudo WORKDIR=/some/folder $0 $ISO"; exit 1;;
esac
free_mb() { df --output=avail -BM "$1" | tail -n1 | tr -dc '0-9'; }
[ "$(free_mb "$WORK")" -ge 2500 ] || { echo "need 2500 MB free in $WORK, have $(free_mb "$WORK") MB"; exit 1; }
[ "$(free_mb "$BIG")" -ge 1400 ] || { echo "need 1400 MB free in $(dirname "$ISO"), have $(free_mb "$BIG") MB"; exit 1; }

echo "== 1. open ISO"
mount -o loop,ro "$ISO" "$WORK/isomnt"
FS="$WORK/isomnt/austrumi/austrumi.fs"; TGZ="$WORK/isomnt/austrumi/austrumi.tgz"
[ -f "$FS" ] && [ -f "$TGZ" ] || { echo "austrumi.fs / austrumi.tgz not found - not a 5.x layout"; exit 1; }
cp "$WORK/isomnt/isolinux.cfg" "$WORK/isomnt/syslinux.cfg" "$WORK/isomnt/EFI/BOOT/refind.conf" "$WORK/cfg/"
chmod u+w "$WORK/cfg/"*
OLDSIZE=$(stat -c %s "$FS")
COMP=$(unsquashfs -s "$FS" | awk '/^Compression/ {print $2}')
BLOCK=$(unsquashfs -s "$FS" | awk '/^Block size/ {print $3}')

echo "== 2. unpack austrumi.fs ($COMP, block $BLOCK) and austrumi.tgz"
unsquashfs -d "$FSROOT" "$FS" >/dev/null
tar --numeric-owner -xzpf "$TGZ" -C "$SYS"
[ -d "$SKEL" ] || { echo "etc/skel missing in austrumi.tgz"; exit 1; }

echo "== 3. assemble the system the way AUSTRUMI's init does"
CREATED=""
for d in $(ls "$FSROOT"); do
  [ -d "$FSROOT/$d" ] || continue
  [ -e "$SYS/$d" ] || { mkdir "$SYS/$d"; CREATED="$CREATED $d"; }
  mount --bind "$FSROOT/$d" "$SYS/$d"
done
for d in dev proc tmp; do [ -e "$SYS/$d" ] || { mkdir "$SYS/$d"; CREATED="$CREATED $d"; }; done
mount --bind /dev "$SYS/dev"
mount -t proc proc "$SYS/proc"
[ -x "$SYS/bin/sh" ] || { echo "no /bin/sh in the assembled system"; exit 1; }

fetch_pkg() {   # fetch_pkg <series> <name>  -> prints local file; tries each mirror in turn
  local series="$1" name="$2" pat m idx f
  pat=$(printf '%s' "$name" | sed 's/[+.]/\\&/g')
  for m in $MIRRORS; do
    idx="$WORK/pkg/index-$series-$(printf '%s' "$m" | tr -c 'A-Za-z0-9' _).html"
    [ -s "$idx" ] || curl -fsSL --connect-timeout 15 --retry 2 "$m/$series/" -o "$idx" 2>/dev/null \
      || { rm -f "$idx"; continue; }
    f=$(grep -oE "\"$pat-[0-9][^\"/]*\.txz\"" "$idx" | tr -d '"' | sort -u | tail -n1)
    [ -n "$f" ] || continue
    if [ -s "$WORK/pkg/$f" ] && xz -t "$WORK/pkg/$f" 2>/dev/null; then echo "$WORK/pkg/$f"; return 0; fi
    if curl -fsSL --connect-timeout 15 --retry 2 "$m/$series/$f" -o "$WORK/pkg/$f" 2>/dev/null \
       && xz -t "$WORK/pkg/$f" 2>/dev/null; then
      echo "$WORK/pkg/$f"; return 0
    fi
    rm -f "$WORK/pkg/$f"
    echo "   (mirror failed, trying the next one: $m)" >&2
  done
  echo "could not download package $name from any mirror - check the network and run again" >&2
  return 1
}

echo "== 4. Slackware packages"
for p in $PKGS; do
  f=$(fetch_pkg x "$p") || exit 1
  echo "   $(basename "$f")"
  rm -rf "$SYS/install"
  tar -xJf "$f" -C "$SYS"
  # Slackware keeps symlinks and post-install steps in install/doinst.sh
  if [ -f "$SYS/install/doinst.sh" ]; then
    chroot "$SYS" /bin/sh -c 'cd / && sh install/doinst.sh' >/dev/null 2>&1 || true
  fi
  rm -rf "$SYS/install"
done
chroot "$SYS" /sbin/ldconfig || true

echo "== 5. Korean fonts"
for u in $FONTS; do
  f=${u##*/}
  echo "   $f"
  curl -fsSL --connect-timeout 15 --retry 3 "$GH/$u" -o "$FSROOT/usr/share/fonts/OTF/$f" \
    || { echo "font download failed - check the network and run again"; exit 1; }
  chmod 644 "$FSROOT/usr/share/fonts/OTF/$f"
done
# NanumSquare only (no Round, no Neo, no other Nanum family)
find_nanum() {
  { find "$@" -type f \( -iname 'NanumSquare*.ttf' -o -iname 'NanumSquare*.otf' \) \
         ! -iname '*Round*' ! -iname '*Neo*' 2>/dev/null || true; } | sort
}
USERHOME=$(getent passwd "${SUDO_USER:-root}" | cut -d: -f6)
NANUM=$(find_nanum ${NANUM_DIR:+"$NANUM_DIR"} /usr/share/fonts /usr/local/share/fonts \
                   "$USERHOME/.fonts" "$USERHOME/.local/share/fonts")
if [ -z "$NANUM" ]; then
  echo "   NanumSquare not installed here - fetching Ubuntu's fonts-nanum package"
  mkdir -p "$WORK/pkg/nanum"
  ( cd "$WORK/pkg/nanum" && apt-get download fonts-nanum >/dev/null 2>&1 && \
    for d in fonts-nanum_*.deb; do dpkg-deb -x "$d" x; done ) || true
  NANUM=$(find_nanum "$WORK/pkg/nanum")
fi
[ -n "$NANUM" ] || { echo "NanumSquare font files not found - run again with NANUM_DIR=/folder/with/the/ttf/files"; exit 1; }
SEEN=" "
echo "$NANUM" | while IFS= read -r f; do
  n=$(basename "$f")
  case "$SEEN" in *" $n "*) continue;; esac
  SEEN="$SEEN$n "
  echo "   $n"
  cp "$f" "$FSROOT/usr/share/fonts/TTF/$n"; chmod 644 "$FSROOT/usr/share/fonts/TTF/$n"
done
# documents that name the CJK families get the Korean-only fonts
FCONF="$SYS/etc/fonts/fonts.conf"
if [ -f "$FCONF" ] && ! grep -q 'Noto Serif CJK KR' "$FCONF"; then
  sed -i 's|</fontconfig>|<alias binding="same"><family>Noto Sans CJK KR</family><prefer><family>Noto Sans KR</family></prefer></alias>\n<alias binding="same"><family>Noto Serif CJK KR</family><prefer><family>Noto Serif KR</family></prefer></alias>\n</fontconfig>|' "$FCONF"
fi
grep -q 'Noto Serif CJK KR' "$FCONF" 2>/dev/null || echo "   WARNING: could not add the font name mapping to etc/fonts/fonts.conf"
chroot "$SYS" /usr/bin/fc-cache -f || true

echo "== 6. register the fcitx5 GTK3 input module"
# AUSTRUMI ships no gtk-query-immodules-3.0, so borrow it from Slackware's gtk+3 package.
IMDIR="usr/lib64/gtk-3.0/3.0.0"
IMSO=$(cd "$FSROOT" && ls $IMDIR/immodules/im-fcitx*.so 2>/dev/null | head -n1 || true)
GTKIM=no
if [ -n "$IMSO" ]; then
  if g=$(fetch_pkg l "gtk+3") && \
     tar -xJf "$g" -C "$WORK/pkg" --wildcards '*bin/gtk-query-immodules-3.0' 2>/dev/null; then
    cp "$WORK/pkg/usr/bin/gtk-query-immodules-3.0" "$SYS/tmp/q-im"
    chroot "$SYS" /tmp/q-im --update-cache >/dev/null 2>&1 || true
    rm -f "$SYS/tmp/q-im"
  fi
  if ! grep -q fcitx "$FSROOT/$IMDIR/immodules.cache" 2>/dev/null; then   # fallback: add the entry by hand
    cat >> "$FSROOT/$IMDIR/immodules.cache" <<EOF

"/$IMSO"
"fcitx" "Fcitx5 (Flexible Input Method Framework5)" "fcitx5" "/usr/share/locale" "ja:ko:zh:*"
"fcitx5" "Fcitx5 (Flexible Input Method Framework5)" "fcitx5" "/usr/share/locale" "ja:ko:zh:*"
EOF
  fi
  GTKIM=yes
fi
echo "   module: ${IMSO:-not found}   registered: $GTKIM"

echo "== 7. configuration (goes into austrumi.tgz)"
ENVLINES="QT_IM_MODULE=fcitx
XMODIFIERS=@im=fcitx"
[ "$GTKIM" = yes ] && ENVLINES="GTK_IM_MODULE=fcitx
$ENVLINES"

# login shells and anything that sources /etc/profile (it runs executable /etc/profile.d/*.sh)
echo "$ENVLINES" | sed 's/^/export /' > "$SYS/etc/profile.d/fcitx5.sh"
chmod 755 "$SYS/etc/profile.d/fcitx5.sh"

# X session: /usr/bin/startfvwm2 sources ~/.xprofile before starting fvwm
{ echo; echo "# Hangul input"; echo "$ENVLINES" | sed 's/^/export /'
  echo 'fcitx5 -d >/dev/null 2>&1 &'; } >> "$SKEL/.xprofile"
chmod 755 "$SKEL/.xprofile"

# labwc: KEY=value file plus autostart (the file ends in "exec swayidle", so insert at the top)
if [ -f "$SKEL/.config/labwc/autostart" ]; then
  { echo; echo "# Hangul input"; echo "$ENVLINES"; } >> "$SKEL/.config/labwc/environment"
  sed -i '1a fcitx5 -d >/dev/null 2>\&1 \&' "$SKEL/.config/labwc/autostart"
fi
# sway
if [ -f "$SKEL/.config/sway/config" ]; then
  printf '\n# Hangul input\nexec fcitx5 -d\n' >> "$SKEL/.config/sway/config"
fi
# wayfire
if [ -f "$SKEL/.config/wayfire.ini" ]; then
  sed -i '/^\[autostart\]/a fcitx5 = fcitx5 -d' "$SKEL/.config/wayfire.ini"
fi

# --- English interface (the image has en_US.utf8; it has no ko_KR locale, none is needed to type Hangul)
# every place 5.3.0 hardcodes Latgalian:
for f in "$SYS/etc/profile.d/lang.sh" "$SKEL/.profile" "$SKEL/.xinitrc" "$SKEL/.bashrc"; do
  [ -f "$f" ] && sed -i 's/^export LANG=.*/export LANG=en_US.utf8/' "$f"
done
[ -f "$SYS/etc/lxdm/lxdm.conf" ] && sed -i 's/^last_lang=.*/last_lang=en_US.utf8/' "$SYS/etc/lxdm/lxdm.conf"
# keyboard: US layout with the XKB options korean:ralt_hangul / korean:rctrl_hanja, so Right Alt is
# the Hangul key and Right Ctrl the Hanja key while the layout (and fcitx5's tray label) stays "us".
# Checked against xkeyboard-config: the options resolve to kr(ralt_hangul) and kr(rctrl_hanja).
# Fallback when the image's rules do not know the options: layout kr(kr104), tray label "kr".
XKBDIR="$FSROOT/usr/share/X11/xkb"
XKBKR="$XKBDIR/symbols/kr"
if ! grep -q '"ralt_hangul"' "$XKBKR" 2>/dev/null; then
  if grep -q '"ralt_hangul"' /usr/share/X11/xkb/symbols/kr 2>/dev/null && [ -d "$XKBDIR/symbols" ]; then
    echo "   kr keyboard symbols missing in the image - copying them from this computer"
    cp /usr/share/X11/xkb/symbols/kr "$XKBKR"; chmod 644 "$XKBKR"
  else
    echo "no kr keyboard symbols (Hangul key) in the image or on this computer"; exit 1
  fi
fi
if grep -q 'korean:ralt_hangul.*=.*+kr(ralt_hangul)' "$XKBDIR/rules/evdev" 2>/dev/null; then
  KB_LAYOUT=us; KB_VARIANT=""; KB_OPTS="korean:ralt_hangul,korean:rctrl_hanja"; KB_FCITX=us
else
  echo "   NOTE: image keyboard rules lack korean:ralt_hangul - using layout kr(kr104); tray label will be kr"
  KB_LAYOUT=kr; KB_VARIANT=kr104; KB_OPTS=""; KB_FCITX=kr-kr104
fi
echo "   keyboard: layout=$KB_LAYOUT variant=${KB_VARIANT:-none} options=${KB_OPTS:-none}"
# X (FVWM): ~/.xprofile
sed -i "s/-layout \"ltg(apostrophe),us(basic),lv(basic)\"/-layout $KB_LAYOUT${KB_VARIANT:+ -variant $KB_VARIANT}/" "$SKEL/.xprofile"
[ -n "$KB_OPTS" ] && sed -i "/setxkbmap/s/grp:alt_shift_toggle/$KB_OPTS/" "$SKEL/.xprofile"
# sway
if [ -f "$SKEL/.config/sway/config" ]; then
  sed -i -e "s/^\(\s*xkb_layout\) .*/\1 \"$KB_LAYOUT\"/" -e "s/^\(\s*xkb_variant\) .*/\1 \"$KB_VARIANT\"/" \
         -e "s/^\(\s*xkb_options\) .*/\1 \"$KB_OPTS\"/" "$SKEL/.config/sway/config"
fi
# labwc
if [ -f "$SKEL/.config/labwc/environment" ]; then
  sed -i -e '/^XKB_DEFAULT_VARIANT=/d' -e '/^XKB_DEFAULT_OPTIONS=/d' \
         -e "s/^XKB_DEFAULT_LAYOUT=.*/XKB_DEFAULT_LAYOUT=$KB_LAYOUT\nXKB_DEFAULT_VARIANT=$KB_VARIANT\nXKB_DEFAULT_OPTIONS=$KB_OPTS/" \
         "$SKEL/.config/labwc/environment"
fi
# wayfire
if [ -f "$SKEL/.config/wayfire.ini" ]; then
  sed -i -e '/^xkb_variant = /d' -e '/^xkb_options = /d' \
         -e "s/^xkb_layout = .*/xkb_layout = $KB_LAYOUT\nxkb_variant = $KB_VARIANT\nxkb_options = $KB_OPTS/" "$SKEL/.config/wayfire.ini"
fi
# AUSTRUMI's own switch: /etc/rc.d/rc.local sets English when the kernel line has lang_en
sed -i '/^APPEND /{/lang_en/!s/\s*$/ lang_en/}' "$WORK/cfg/isolinux.cfg" "$WORK/cfg/syslinux.cfg"
sed -i '/options "initrd=\/austrumi/{/lang_en/!s/"\s*$/ lang_en"/}' "$WORK/cfg/refind.conf"

# --- FVWM (default theme, fvwm2rc_5): keep windows beside the left panel.
# Tested with fvwm 2.7.0: a new window larger than the free area is maximized into it, one that
# sticks out (or sits under the panel) is moved in, and double-clicking a title bar maximizes
# beside the panel instead of over it. Full screen stays on double-click of the maximize button.
RC5="$FSROOT/usr/share/fvwm/fvwm2rc_5"
if [ -f "$RC5" ] && grep -q '^\*FvwmEvent: add_window FuncMoveEmelfm3' "$RC5"; then
  sed -i -e 's/^+ D Maximize ewmhiwa\s*$/+ D Maximize/' \
         -e 's/^\*FvwmEvent: add_window FuncMoveEmelfm3\s*$/*FvwmEvent: add_window NewWindowFunc/' "$RC5"
  cat >> "$RC5" <<'EOF_FVWM'

#############################
#   Keep new windows beside the panel (added by austrumi-ko.sh)
###############################
DestroyFunc FitToWorkArea
AddToFunc FitToWorkArea
+ I ThisWindow (Maximizable, !Sticky, !Transient, !FixedPosition, !Iconic, Layer 4) PipeRead ' \
  PX=$[w.x]; PY=$[w.y]; PW=$[w.width]; PH=$[w.height]; \
  AX=$[wa.x]; AY=$[wa.y]; AW=$[wa.width]; AH=$[wa.height]; \
  if xprop -id $[w.id] _NET_WM_STATE 2>/dev/null | grep -q FULLSCREEN; then exit 0; fi; \
  if [ $PW -gt $AW ] || [ $PH -gt $AH ]; then echo "Maximize False"; echo "Maximize True"; \
  else MX=$PX; MY=$PY; \
    [ $((PX + PW)) -gt $((AX + AW)) ] && MX=$((AX + AW - PW)); \
    [ $((PY + PH)) -gt $((AY + AH)) ] && MY=$((AY + AH - PH)); \
    [ $MX -lt $AX ] && MX=$AX; [ $MY -lt $AY ] && MY=$AY; \
    if [ $MX -ne $PX ] || [ $MY -ne $PY ]; then echo "Move ${MX}p ${MY}p ewmhiwa"; fi; \
  fi'

DestroyFunc NewWindowFunc
AddToFunc NewWindowFunc
+ I FuncMoveEmelfm3
+ I FitToWorkArea
+ I Schedule 700 WindowId $[w.id] FitToWorkArea
+ I Schedule 2500 WindowId $[w.id] FitToWorkArea
+ I Schedule 6000 WindowId $[w.id] FitToWorkArea
EOF_FVWM
  echo "   FVWM: window fitting added to fvwm2rc_5"
  # Start menu: the row of categories that opens beside the top-left icon used to vanish when the
  # pointer moved from the icon onto it. Tested with fvwm 2.7.0 and scripted pointer movement.
  if grep -q '^+ I Module FvwmButtons FvwmDockA\s*$' "$RC5" && grep -q '^DestroyFunc RestoreButton' "$RC5"; then
    sed -i 's/^+ I Module FvwmButtons FvwmDockA\s*$/+ I None (FvwmDockA, CirculateHit) Module FvwmButtons FvwmDockA/' "$RC5"
    cat >> "$RC5" <<'EOF_DOCK'

#############################
#   Start-menu row: stay open while the pointer is on the icon or the row (added by austrumi-ko.sh)
###############################
# The original closed the row with timers set on enter/leave events, which lost a race when the
# pointer moved from the icon onto the row. Now a watcher looks at where the pointer really is.
DestroyFunc EnterHandler
AddToFunc EnterHandler
+ I ThisWindow (FvwmDock) SendToModule FvwmDock ChangeButton D10 Icon "/usr/share/pixmaps/gerbs.svg:42x42"
+ I ThisWindow (FvwmDock) MakeMenuFvwmRootTop
+ I ThisWindow (FvwmDock) CreateActiveButton

DestroyFunc LeaveHandler
AddToFunc LeaveHandler
+ I ThisWindow SetEnv last_winid $[w.id]

AddToFunc CreateActiveButton
+ I Deschedule 65
+ I Schedule 400 65 DockWatch

DestroyFunc DockWatch
AddToFunc DockWatch
+ I PointerWindow (FvwmDock*) Schedule 250 65 DockWatch
+ I TestRc (Match) Break
+ I SendToModule FvwmDock ChangeButton D10 Icon /usr/share/pixmaps/gerbs.svg:40x40
+ I All (FvwmDockA, CirculateHit) Close
+ I KillModule FvwmButtons FvwmDockA
EOF_DOCK
    echo "   FVWM: start-menu row fix added to fvwm2rc_5"
  else
    echo "   WARNING: start-menu section of fvwm2rc_5 is not as expected - row fix not added"
  fi
else
  echo "   WARNING: fvwm2rc_5 is not as expected - window fitting not added"
fi

# --- LibreOffice: the image ships a saved window size from a 1920x1080 screen (e.g. 1271x1052 at
# 59,27), which opens Writer larger than a smaller screen. Remove it so LibreOffice sizes its
# window for the screen it actually runs on.
LOREG="$SKEL/.config/libreoffice/4/user/registrymodifications.xcu"
if [ -f "$LOREG" ]; then
  sed -i 's#<item [^>]*><prop oor:name="ooSetupFactoryWindowAttributes"[^>]*><value>[^<]*</value></prop></item>##g' "$LOREG"
  echo "   LibreOffice saved window sizes left: $(grep -c ooSetupFactoryWindowAttributes "$LOREG" || true) (0 expected)"
fi

# --- keyboard flag in the FVWM panel (xxkb): the first (now only) layout showed the Latgalian flag
if [ -f "$SKEL/.xxkbrc" ]; then
  sed -i -e 's/^\(XXkb\.mainwindow\.image\.1:\s*\).*/\1us.xpm/' \
         -e 's/^\(XXkb\.mainwindow\.label\.text\.1:\s*\).*/\1US/' "$SKEL/.xxkbrc"
fi

# --- time zone (the image only carries Europe/Riga, so the zone file comes from this computer)
ZI="/usr/share/zoneinfo/$TZNAME"
[ -f "$ZI" ] || { echo "time zone $TZNAME not found in /usr/share/zoneinfo on this computer"; exit 1; }
mkdir -p "$FSROOT/usr/share/zoneinfo/$(dirname "$TZNAME")"
cp -L "$ZI" "$FSROOT/usr/share/zoneinfo/$TZNAME"; chmod 644 "$FSROOT/usr/share/zoneinfo/$TZNAME"
rm -f "$SYS/etc/localtime" "$SYS/etc/localtime-copied-from"
cp -L "$ZI" "$SYS/etc/localtime"; chmod 644 "$SYS/etc/localtime"
ln -s "/usr/share/zoneinfo/$TZNAME" "$SYS/etc/localtime-copied-from"
sed -i "s|^export TZ=.*|export TZ='$TZNAME'|" "$SKEL/.profile"

# --- hardware clock. /etc/hardwareclock says "localtime": the PC clock is shown as it is, which is right
# for PCs that also run Windows. Boot option clock_utc (menu entry 5) is for PCs whose clock holds UTC
# (Linux-only PCs, plain QEMU); it also makes shutdown write the clock back as UTC.
[ "${RTC:-localtime}" = utc ] && sed -i 's/^localtime/UTC/' "$SYS/etc/hardwareclock"
cat >> "$SYS/etc/rc.d/rc.local" <<'EOF'

# boot option clock_utc: the hardware clock holds UTC (Linux-only PC, QEMU default)
if grep -qw clock_utc /proc/cmdline && [ -x /sbin/hwclock ]; then
  sed -i 's/^localtime/UTC/' /etc/hardwareclock
  /sbin/hwclock --utc --hctosys
fi
EOF

# --- boot menus: name entry 1 after the desktop it starts, add entry 5 (clock in UTC)
if [ "$AUTOLOGIN" != none ]; then
  sed -i "s/^MENU LABEL ^1\. Wayland\s*$/MENU LABEL ^1. $AUTOLOGIN desktop/" "$WORK/cfg/isolinux.cfg" "$WORK/cfg/syslinux.cfg"
fi
cat >> "$WORK/cfg/isolinux.cfg" <<'EOF'

LABEL utc
MENU LABEL ^5. Same as 1, PC clock in UTC (Linux-only PC, QEMU)
TEXT HELP
 Use this when the clock is 9 hours behind with entry 1
  login:austrumi  password:austrumi
ENDTEXT
KERNEL /austrumi/bzImage
APPEND initrd=/austrumi/initrd.gz dolivecd greetd emb_user lang_en clock_utc
EOF
cat >> "$WORK/cfg/syslinux.cfg" <<'EOF'

LABEL utc
MENU LABEL ^5. Same as 1, PC clock in UTC (Linux-only PC, QEMU)
TEXT HELP
 Use this when the clock is 9 hours behind with entry 1
  login:austrumi  password:austrumi
ENDTEXT
KERNEL /austrumi/bzImage
APPEND dousb greetd emb_user lang_en clock_utc
INITRD /austrumi/amd-ucode.cpio,/austrumi/intel-ucode.cpio,/austrumi/initrd.gz
EOF
sed -i '/submenuentry "XServer session" {/i\    submenuentry "PC clock in UTC (Linux-only PC)" {\n        options "initrd=/austrumi/amd-ucode.cpio initrd=/austrumi/intel-ucode.cpio initrd=/austrumi/initrd.gz dousb emb_user greetd lang_en clock_utc"\n    }' "$WORK/cfg/refind.conf"

echo "   flag / time lines now:"
{ grep -H -E 'image\.1:|label\.text\.1:' "$SKEL/.xxkbrc"; grep -H '^export TZ=' "$SKEL/.profile"
  grep -H -v '^#' "$SYS/etc/hardwareclock" | grep -v ':$'; ls -l "$SYS/etc/localtime-copied-from" | sed 's/.*etc\//etc\//'; } 2>/dev/null | sed "s|$SYS/||; s/^/     /"
echo "   language lines now:"
grep -H -E '^export LANG=|^last_lang=|^\s*xkb_(layout|variant|options)|^XKB_DEFAULT_(LAYOUT|VARIANT|OPTIONS)=|setxkbmap' \
  "$SYS/etc/profile.d/lang.sh" "$SKEL/.profile" "$SKEL/.xinitrc" "$SKEL/.bashrc" "$SYS/etc/lxdm/lxdm.conf" \
  "$SKEL/.xprofile" "$SKEL/.config/sway/config" "$SKEL/.config/labwc/environment" "$SKEL/.config/wayfire.ini" \
  2>/dev/null | sed "s|$SYS/||; s/^/     /"
echo "   boot lines now:"
grep -h -E '^APPEND |options "initrd' "$WORK/cfg/isolinux.cfg" "$WORK/cfg/refind.conf" | sed 's/^\s*/     /'

# --- start the desktop without a login prompt (greetd "initial session", used once per boot)
GREETD="$SYS/etc/greetd/config.toml"
if [ "$AUTOLOGIN" != none ]; then
  [ -x "$FSROOT/usr/local/bin/$AUTOLOGIN" ] || { echo "no session launcher /usr/local/bin/$AUTOLOGIN in the image"; exit 1; }
  [ -f "$GREETD" ] || { echo "etc/greetd/config.toml missing in austrumi.tgz"; exit 1; }
  if ! grep -q '^\[initial_session\]' "$GREETD"; then
    # a login shell, so /etc/profile (language, input method variables) is read first
    printf '\n[initial_session]\ncommand = "bash -l -c /usr/local/bin/%s"\nuser = "austrumi"\n' "$AUTOLOGIN" >> "$GREETD"
  fi
  echo "   automatic login: austrumi -> $AUTOLOGIN"
fi

# Pre-select Hangul so no setup is needed after boot (toggle: Right Alt = Hangul key, or Ctrl+Space)
mkdir -p "$SKEL/.config/fcitx5"
cat > "$SKEL/.config/fcitx5/profile" <<'EOF'
[Groups/0]
Name=Default
Default Layout=@KB_FCITX@
DefaultIM=hangul

[Groups/0/Items/0]
Name=keyboard-@KB_FCITX@
Layout=

[Groups/0/Items/1]
Name=hangul
Layout=

[GroupOrder]
0=Default
EOF
sed -i "s/@KB_FCITX@/$KB_FCITX/" "$SKEL/.config/fcitx5/profile"

# Switch keys, written out so they do not depend on fcitx5's built-in defaults
cat > "$SKEL/.config/fcitx5/config" <<'EOF'
[Hotkey]
EnumerateWithTriggerKeys=True

[Hotkey/TriggerKeys]
0=Hangul
1=Control+space
EOF

echo "== 8. checks"
echo "   name mapping: Noto Serif CJK KR -> $(chroot "$SYS" /usr/bin/fc-match -f '%{family}' 'Noto Serif CJK KR' 2>/dev/null || echo '?')," \
     "Noto Sans CJK KR -> $(chroot "$SYS" /usr/bin/fc-match -f '%{family}' 'Noto Sans CJK KR' 2>/dev/null || echo '?')"
echo "   Korean fonts seen by fontconfig:"
chroot "$SYS" /bin/sh -c 'fc-list :lang=ko family | sort -u | sed "s/^/     /"' || true
MISSING=$(chroot "$SYS" /bin/sh -c \
  'ldd /usr/bin/fcitx5 /usr/lib64/fcitx5/*.so /usr/lib64/libhangul.so.* /usr/lib64/gtk-3.0/3.0.0/immodules/im-fcitx*.so 2>&1 | grep "not found" | sort -u' || true)
if [ -n "$MISSING" ]; then
  echo "   WARNING - unresolved libraries (send me this list):"
  echo "$MISSING" | sed 's/^/     /'
else
  echo "   all fcitx5 libraries resolve"
fi

if [ "${PAUSE:-0}" = 1 ]; then
  echo "   system files: $FSROOT    config files: $SYS/etc (skel = home directory)"
  read -r -p "   edit now, then press Enter to build the ISO... "
fi

echo "== 9. repack austrumi.tgz and austrumi.fs"
unmount_all
for d in $CREATED; do rmdir "$SYS/$d" 2>/dev/null || true; done
tar --numeric-owner --format=gnu -C "$SYS" -czf "$BIG/new.tgz" .
mksquashfs "$FSROOT" "$BIG/new.fs" -comp "$COMP" -b "$BLOCK" -noappend -no-progress >/dev/null
NEWSIZE=$(stat -c %s "$BIG/new.fs")
echo "   austrumi.fs: $((OLDSIZE/1048576)) MB -> $((NEWSIZE/1048576)) MB (all of it is copied to RAM at boot)"

echo "== 10. build ISO (boot record replayed from the original)"
xorriso -indev "$ISO" -outdev "$OUT" -boot_image any replay \
        -map "$BIG/new.fs"  /austrumi/austrumi.fs \
        -map "$BIG/new.tgz" /austrumi/austrumi.tgz \
        -map "$WORK/cfg/isolinux.cfg" /isolinux.cfg \
        -map "$WORK/cfg/syslinux.cfg" /syslinux.cfg \
        -map "$WORK/cfg/refind.conf" /EFI/BOOT/refind.conf
[ -n "${SUDO_USER:-}" ] && chown "$SUDO_USER": "$OUT" 2>/dev/null || true

echo
echo "done: $OUT"
echo "size: $(($(stat -c %s "$OUT")/1048576)) MB (original: $(($(stat -c %s "$ISO")/1048576)) MB)"
echo "test: qemu-system-x86_64 -enable-kvm -cpu host -m 4G -rtc base=localtime -cdrom '$OUT'"
echo "      (-rtc base=localtime gives QEMU a PC clock in local time, as on a Windows PC; without it use boot entry 5)"
if [ "${KEEP:-0}" = 1 ]; then
  echo "work files kept: $WORK and $BIG"
else
  rm -rf --one-file-system "$WORK" "$BIG"
fi
