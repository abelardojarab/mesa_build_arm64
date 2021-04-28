# mesa_build_arm64

This repository contains script:

* Manually build Mesa 21 with Honeycomb LX2 `radeonsi` patch so GTK windows do not appear distorted when using `amdgpu` driver.
* Also contains `debhelper` rules to create the corresponding `.deb` package.

```
$ debuild -us -uc
```
