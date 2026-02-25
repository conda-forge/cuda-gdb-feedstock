#!/bin/bash

# Install to conda style directories
[[ -d lib64 ]] && mv lib64 lib

[[ ${target_platform} == "linux-64" ]] && targetsDir="targets/x86_64-linux"
[[ ${target_platform} == "linux-ppc64le" ]] && targetsDir="targets/ppc64le-linux"
[[ ${target_platform} == "linux-aarch64" && ${arm_variant_type} == "sbsa" ]] && targetsDir="targets/sbsa-linux"
[[ ${target_platform} == "linux-aarch64" && ${arm_variant_type} == "tegra" ]] && targetsDir="targets/aarch64-linux"

mkdir -p "${PREFIX}/${targetsDir}"
mv -v extras/Debugger/include "${PREFIX}/${targetsDir}"

# No python support for the debugger in non-x86 platforms on CUDA 12.9
if [[ ${target_platform} == "linux-64" ]]; then
    rm bin/cuda-gdb
    if [[ ${PY_VER:-0} == "0" ]]; then
        mv -v "bin/cuda-gdb-minimal" bin/cuda-gdb
    else
        # Due to an issue similar to https://github.com/astral-sh/python-build-standalone/issues/197,
        # we need to strip an unneeded link to libcrypt.so.1
        patchelf --remove-needed libcrypt.so.1 "bin/cuda-gdb-python${PY_VER}-tui"
        mv -v "bin/cuda-gdb-python${PY_VER}-tui" bin/cuda-gdb
    fi
fi

for i in `ls`; do
    [[ $i == "build_env_setup.sh" ]] && continue
    [[ $i == "conda_build.sh" ]] && continue
    [[ $i == "metadata_conda_debug.yaml" ]] && continue

    if [[ $i == "bin" ]]; then
        for j in `ls "${i}"`; do
            [[ -f "bin/${j}" ]] || continue

            echo patchelf --force-rpath --set-rpath "\$ORIGIN/../lib:\$ORIGIN/../${targetsDir}/lib" "${i}/${j}" ...
            patchelf --force-rpath --set-rpath "\$ORIGIN/../lib:\$ORIGIN/../${targetsDir}/lib" "${i}/${j}"
        done
    fi

    cp -rv $i ${PREFIX}
done

check-glibc "$PREFIX"/lib*/*.so.* "$PREFIX"/bin/* "$PREFIX"/targets/*/lib*/*.so.* "$PREFIX"/targets/*/bin/*
