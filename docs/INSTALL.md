# Installing Orion Unchained

## Requirements

You need an Acer Predator Orion desktop (see [HARDWARE.md](HARDWARE.md)), Linux 6.8 or newer, systemd, Python 3.8 or newer, and the tools to build a kernel module through DKMS. The driver is tested on Linux 7.2 and compile-tested against 6.8 and 6.12.

Install the build tools and the headers that match your running kernel:

```bash
# Fedora, Nobara
sudo dnf install kernel-devel dkms make gcc python3

# Debian, Ubuntu, Linux Mint, Pop!_OS
sudo apt install linux-headers-$(uname -r) dkms make gcc python3

# Arch, EndeavourOS, CachyOS (use the headers package for your kernel, e.g. linux-zen-headers)
sudo pacman -S --needed linux-headers dkms make gcc python

# openSUSE
sudo zypper install kernel-default-devel dkms make gcc python3
```

The app also needs PySide6 6.8 or newer, the official Python bindings for Qt. The driver and orionctl work without it.

```bash
# Fedora, Nobara
sudo dnf install python3-pyside6

# Arch, EndeavourOS, CachyOS
sudo pacman -S --needed pyside6

# openSUSE Tumbleweed
sudo zypper install python3-pyside6

# Debian 13, Ubuntu 26.04 and newer
sudo apt install python3-pyside6.qtquick python3-pyside6.qtquickcontrols2 python3-pyside6.qtwidgets \
    qml6-module-qtquick qml6-module-qtquick-controls qml6-module-qtquick-layouts \
    qml6-module-qtquick-shapes qml6-module-qtquick-effects qml6-module-qtquick-dialogs \
    qml6-module-qtquick-window qml6-module-qtcore qt6-svg-plugins
```

## Install

```bash
git clone https://github.com/s0t0h/orion-unchained
cd orion-unchained
sudo make install
```

This does the following:

1. Copies the driver source to `/usr/src/acer-predator-dt-rgb-VERSION` and builds and installs it with DKMS, after removing any older version. DKMS rebuilds it by itself whenever a new kernel is installed.
2. Installs `orionctl` and the app, `orion-unchained`, to `/usr/local/bin`, adds the app to your menu, and puts the style library in `/usr/local/share/orion-unchained/styles`.
3. Creates the `orion-rgb` group and adds the account that ran `sudo`. A udev rule gives that group write access to the lighting controls, and nothing else.
4. Creates `/var/lib/orion-unchained`, where your current look is saved.
5. Enables `orion-unchained.service`, which restores your look at boot, and `orion-unchained-resume.service`, which re-applies it after suspend or hibernation.
6. Loads the driver.

Your account only picks up the new group at the next login. Until then orionctl and the app run themselves through `sg orion-rgb`, which works without logging out. Then check the result:

```bash
orionctl doctor
```

The driver loads automatically at every boot from then on: the kernel matches it to the firmware's WMI device.

## Secure Boot

With Secure Boot enabled, the kernel only loads modules signed by a key it trusts. DKMS signs the module with its own key and prints where the certificate is, in a line starting with "Public certificate (MOK)". If another DKMS driver such as NVIDIA's already works on your machine, that key is enrolled and there is nothing to do. Otherwise enrol it once, using the path DKMS printed (Fedora uses `/var/lib/dkms/mok.pub`, Ubuntu `/var/lib/shim-signed/mok/MOK.der`):

```bash
sudo mokutil --import /var/lib/dkms/mok.pub
```

Pick a one-time password, reboot, and choose "Enroll MOK" in the blue screen that appears. `mokutil --sb-state` tells you whether Secure Boot is on at all.

## Other Orion models

The driver binds by itself only on models that have been tested (currently the PO7-660). On another Predator Orion you can try it with:

```bash
sudo modprobe acer_predator_dt_rgb force=1
orionctl status
```

It reads which zones the firmware reports and changes nothing until you ask it to. If the zones make sense and the lights react, please send a model report (see [HARDWARE.md](HARDWARE.md)) so your model can be enabled for everyone. To keep `force=1` across reboots in the meantime:

```bash
echo "options acer_predator_dt_rgb force=1" | sudo tee /etc/modprobe.d/orion-unchained.conf
```

## Trying it without installing

```bash
make
sudo insmod driver/acer_predator_dt_rgb.ko
bin/orionctl status
bin/orion-unchained
```

`bin/orion-unchained --demo` runs the app with a simulated PO7-660, without the driver.

`make shortcut`, run without sudo, adds Orion Unchained to your app menu and puts an icon on your desktop. Both start the app from this checkout. `make unshortcut` removes them; run it before `sudo make install` so the checkout entry does not hide the installed one.

`sudo rmmod acer_predator_dt_rgb` unloads it again. Unloading leaves the lights as they are.

## Updating

```bash
git pull
sudo make install
```

## Uninstalling

```bash
sudo make uninstall
```

This removes the driver, orionctl, the app, the styles, the udev rule and the services. It keeps `/var/lib/orion-unchained` and the `orion-rgb` group, in case you reinstall; delete them by hand if you want them gone (`sudo rm -r /var/lib/orion-unchained`, `sudo groupdel orion-rgb`).

## Packaging

The Makefile honours `DESTDIR` and `PREFIX`. With `DESTDIR` set it only stages files and skips DKMS, users, udev reloads and systemd, which a distribution package does in its own scripts. `packaging/` contains the DKMS, udev, sysusers.d, tmpfiles.d and systemd sources.

## Troubleshooting

`orionctl doctor` checks each part of the installation and says what to do about anything that fails. Beyond that:

- `sudo dmesg | grep acer-predator` shows why the driver did not bind. "unverified model" means your model is not on the tested list yet; see "Other Orion models" above.
- "Key was rejected by service" when loading means Secure Boot refused an unsigned or unenrolled module; see "Secure Boot".
- If a zone accepts changes but the light does not follow, `sudo cat /sys/kernel/debug/acer_predator_dt_rgb/state` shows what the firmware itself reports for every area. Please include it in a bug report.
