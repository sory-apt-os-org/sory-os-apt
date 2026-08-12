import os, subprocess, shutil, tempfile
tmpdir = tempfile.mkdtemp(prefix='soryos-deb-')
os.makedirs(os.path.join(tmpdir, 'DEBIAN'))
os.makedirs(os.path.join(tmpdir, 'usr/share/doc/soryos-desktop'))
control = (
    "Package: soryos-desktop\n"
    "Version: 1.0.0+soryos1\n"
    "Architecture: all\n"
    "Maintainer: SoryOS\n"
    "Description: SoryOS desktop metapackage\n"
    "Depends: cosmic-applets, cosmic-applibrary, cosmic-bg,"
    " cosmic-edit, cosmic-files, cosmic-greeter, cosmic-initial-setup,"
    " cosmic-launcher, cosmic-osd, cosmic-panel, cosmic-player,"
    " cosmic-randr, cosmic-screenshot, cosmic-session, cosmic-settings,"
    " cosmic-settings-daemon, cosmic-store, cosmic-term,"
     " cosmic-wallpapers, cosmic-workspaces-epoch, soryos-launcher,"
     " soryos-launcher-power,"
    " xdg-desktop-portal-cosmic\n"
)
with open(os.path.join(tmpdir, "DEBIAN/control"), "w") as f:
    f.write(control)
with open(os.path.join(tmpdir, "usr/share/doc/soryos-desktop/README"), "w") as f:
    f.write("SoryOS Desktop metapackage\n")
out = os.path.expanduser("~/Bureau/soryos/soryos-apt/pool/soryos-desktop_1.0.0+soryos1_all.deb")
r = subprocess.run(["dpkg-deb", "--build", tmpdir, out], capture_output=True, text=True)
print(r.stdout or r.stderr, "Code:", r.returncode)
if r.returncode == 0:
    sz = os.path.getsize(out)
    print(f"OK: {out} ({sz/1024:.0f} KB)")
shutil.rmtree(tmpdir)
