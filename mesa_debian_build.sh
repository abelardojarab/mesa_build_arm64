#!/bin/bash

mesa_branch=${mesa_branch:-"master"}
mesa_repo=${mesa_repo:-"https://gitlab.freedesktop.org/mesa/mesa.git"}
base_dir=${src_dir:-"${HOME}/workspace/mesa_build_arm64/mesa"}
src_dir=${src_dir:-"${base_dir}/mesa"}
build_dir=${build_dir:-"${base_dir}/build"}
patches_dir=${patches_dir:-"${base_dir}/patches"}
llvm_ver=${llvm_ver:-"12"}
cpuarch=${cpuarch:-"native"} # Zen 2 by default. Change to your arch or "native" accordingly.

build_32=${build_32:-false} # Debian Mesa 32-bit cross compilation is currently broken
build_debug=${build_debug:-false}
verbose=${verbose:-false}
update_sources=${update_sources:-true}
reset_sources=${reset_sources:-true}
apply_patches=${apply_patches:-true}

if $build_debug; then
   build_type='debug'
else
   build_type='release'
fi

if [[ "$mesa_branch" != "mesa"* ]]; then
   mesa_dir=${mesa_dir:-"/usr"}
else
   mesa_dir=${mesa_dir:-"/usr"}
fi

dest_dir=${dest_dir:-"${HOME}/builds/mesa"}
arch_dir["64"]="lib/aarch64-linux-gnu"

function assert() {
   rc=$1
   message="$2"
   if ((rc != 0)); then
      echo $message
      exit $rc
   fi
}

function ensure() {
   local rc=1
   while (($rc != 0)); do
      $@
      rc=$?
      if (($rc != 0)); then
         sleep 1
      fi
   done
}

function common_prepare() {
   echo "=== Common setup ===="
   mkdir -p ${dest_dir}
   rm -rfv ${dest_dir}/${mesa_dir}/*

   # ensure sudo apt-get install build-essential git

   cd $(dirname "$src_dir")
   git clone "$mesa_repo" $(basename "$src_dir")
   cd "$src_dir"

   # If updating, reset is enforced regardless of the $reset_sources, to avoid possible merging confusion
   if $reset_sources || $update_sources; then
     git reset --hard HEAD
     git clean -df
   fi

   if $update_sources; then
     git checkout master
     git pull --rebase --prune
   fi

   git checkout $mesa_branch

   if $apply_patches; then
      mkdir -p "$patches_dir"
      for patch in ${patches_dir}/*; do
        patch -p 1 < ${patch}
        assert $? "Failed to apply patch ${patch}"
      done
   fi

   mkdir -p "$build_dir"
   rm -rfv ${build_dir}/*
}

function prepare_64() {
   echo "=== Preparing 64-bit build ===="

   # ensure sudo apt-get build-dep mesa
   # ensure sudo apt-get install llvm-${llvm_ver}-dev libclang-${llvm_ver}-dev
}

configure_64() {
   echo "==== Configuring 64-bit build ===="
   cd "$build_dir"

   local ndebug=true
   local strip_option="--strip"
   if $build_debug; then
      ndebug=false
      strip_option=""
   fi

   local native_config
   read -r -d '' native_config <<EOF
[binaries]
llvm-config = '/usr/bin/llvm-config-${llvm_ver}'
EOF

   export CFLAGS="-march=${cpuarch} -fdebug-prefix-map=${HOME}/build=. -fstack-protector-strong -Wformat -Werror=format-security -Wall  -O3 -ftree-vectorize -g0 -fno-semantic-interposition"
   export CPPFLAGS="-Wdate-time -D_FORTIFY_SOURCE=2"
   export CXXFLAGS="-march=${cpuarch} -fdebug-prefix-map=${HOME}/build=. -fstack-protector-strong -Wformat -Werror=format-security -Wall -O3"
   export LDFLAGS="-Wl,-z,relro"

   LC_ALL=C.UTF-8 meson "$src_dir" \
--wrap-mode=nodownload \
--buildtype=$build_type \
--native-file=<(echo "$native_config") \
$strip_option \
--prefix="$mesa_dir" \
--sysconfdir=/etc \
--localstatedir=/var \
--libdir="${arch_dir["64"]}" \
--libexecdir="${arch_dir["64"]}" \
-Db_ndebug=$ndebug \
-Ddri-drivers=nouveau \
-Ddri-drivers-path="${arch_dir["64"]}" \
-Dglvnd=true \
-Dshared-glapi=enabled \
-Dgallium-xvmc=enabled \
-Dgallium-vdpau=enabled \
-Dgallium-omx=disabled \
-Dglx-direct=true \
-Dgbm=enabled \
-Ddri3=enabled \
"-Dplatforms=x11,wayland" \
-Dllvm=enabled \
-Dshared-llvm=disabled \
-Dgallium-extra-hud=true \
-Dgallium-vdpau=enabled \
-Dgallium-va=enabled \
-Dva-libs-path="${arch_dir["64"]}" \
-Dlmsensors=enabled \
"-Dgallium-drivers=radeonsi,r600,nouveau,zink,swrast,virgl" \
-Dgles1=disabled \
-Dgles2=enabled \
-Dvulkan-drivers=auto \
"-Dvulkan-layers=device-select,overlay" \
-Dosmesa=true \
-Dgallium-nine=true \
-Dshader-cache=enabled \
-Dopencl-spirv=true \
-Dgallium-opencl=disabled \
-Dtools=glsl,nir \

   assert $? "Configure failed!"
}

function build() {
   echo "==== Building... ===="
   cd "$build_dir"

   if $verbose; then
      LC_ALL=C.UTF-8 ninja -v
   else
      LC_ALL=C.UTF-8 ninja
   fi

   assert $? "build failed!"
}

function publish() {
  cd "$build_dir"
  DESTDIR="$dest_dir" LC_ALL=C.UTF-8 ninja install
}

function clean_64() {
   # ensure sudo apt-get purge llvm-${llvm_ver}-dev libclang-${llvm_ver}-dev
   # ensure sudo apt-get autoremove --purge
   echo "done"
}

################################################

shopt -s nullglob
common_prepare

prepare_64
configure_64
build
publish
clean_64

