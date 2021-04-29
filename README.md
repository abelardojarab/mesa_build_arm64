# mesa_build_arm64

This repository contains script:

* Manually build Mesa 21 with Honeycomb LX2 `radeonsi` patch so GTK windows do not appear distorted when using `amdgpu` driver.
https://github.com/abelardojarab/mesa_build_arm64/blob/master/mesa/patches/0001-radeonsi-Fix-rendering-corruption-with-glamor.patch

* Also contains `debhelper` rules to create the corresponding `.deb` package.

```
$ debuild -us -uc
```
# Note

Be sure that `llvm-10-tools` is not installed as `cmake` defaults to oldest `llvm` installation.
