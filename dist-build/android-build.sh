#! /bin/sh

if [ -z "$ANDROID_NDK_HOME" ]; then
    echo "You should probably set ANDROID_NDK_HOME to the directory containing"
    echo "the Android NDK"
    exit
fi

if [ ! -f ./configure ]; then
	echo "Can't find ./configure. Wrong directory or haven't run autogen.sh?"
	exit 1
fi

if [ "x$TARGET_ARCH" = 'x' ] || [ "x$ARCH" = 'x' ] || [ "x$HOST_COMPILER" = 'x' ]; then
    echo "You shouldn't use android-build.sh directly, use android-[arch].sh instead"
    exit 1
fi

export MAKE_TOOLCHAIN="${ANDROID_NDK_HOME}/build/tools/make-standalone-toolchain.sh"

export PREFIX="$(pwd)/dnscrypt-proxy-android-${TARGET_ARCH}"
export TOOLCHAIN_DIR="$(pwd)/android-toolchain-${TARGET_ARCH}"
export PATH="${PATH}:${TOOLCHAIN_DIR}/bin"

export SODIUM_ANDROID_PREFIX=${SODIUM_ANDROID_PREFIX:-/tmp/libsodium-android-${TARGET_ARCH}}
export CPPFLAGS="$CPPFLAGS -I${SODIUM_ANDROID_PREFIX}/include"
export LDFLAGS="$LDFLAGS -L${SODIUM_ANDROID_PREFIX}/lib"

export UPDATE_BINARY="dist-build/android-files/META-INF/com/google/android/update-binary"
export UPDATE_BINARY_URL="https://github.com/jedisct1/dnscrypt-proxy/blob/master/dist-build/android-files/META-INF/com/google/android/update-binary?raw=true"
export UPDATE_BINARY_SIG_URL="https://github.com/jedisct1/dnscrypt-proxy/blob/master/dist-build/android-files/META-INF/com/google/android/update-binary.minisig?raw=true"
export UPDATE_BINARY_PUBKEY="RWQf6LRCGA9i53mlYecO4IzT51TGPpvWucNSCh1CBM0QTaLn73Y7GFO3"

rm -rf "${TOOLCHAIN_DIR}" "${PREFIX}"

if [ ! -f "$UPDATE_BINARY" ]; then
  curl -v -L -o "${UPDATE_BINARY}.tmp" "$UPDATE_BINARY_URL" || exit 1
  if $(which minisign > /dev/null 2>&1); then
    curl -v -L -o "${UPDATE_BINARY}.tmp.minisig" "$UPDATE_BINARY_SIG_URL" || exit 1
    minisign -V -P "$UPDATE_BINARY_PUBKEY" -m "${UPDATE_BINARY}.tmp" || exit 1
    mv -f "${UPDATE_BINARY}.tmp.minisig" "${UPDATE_BINARY}.minisig"
  fi
  mv -f "${UPDATE_BINARY}.tmp" "$UPDATE_BINARY"
  chmod 755 "$UPDATE_BINARY"
fi

bash $MAKE_TOOLCHAIN --platform="${NDK_PLATFORM:-android-16}" \
    --arch="$ARCH" --install-dir="$TOOLCHAIN_DIR" && \
./configure \
    --bindir="${PREFIX}/system/xbin" \
    --datadir="${PREFIX}/system/etc" \
    --disable-soname-versions \
    --disable-plugins \
    --enable-relaxed-plugins-permissions \
    --host="${HOST_COMPILER}" \
    --prefix="${PREFIX}/system" \
    --sbindir="${PREFIX}/system/xbin" \
    --sysconfdir="${PREFIX}/system/etc" \
    --with-sysroot="${TOOLCHAIN_DIR}/sysroot" && \
make clean && \
make -j3 install && \
rm -fr "${PREFIX}/system/include" "${PREFIX}/system/share" "${PREFIX}/system/man" && \
mkdir -p "${PREFIX}/system/lib" && \
cp "${SODIUM_ANDROID_PREFIX}/lib/libsodium.so" "${PREFIX}/system/lib" && \
(cd dist-build/android-files && tar cpf - *) | (cd "$PREFIX" && tar xpvf -) &&
(cd "$PREFIX"; zip -9 -r "${PREFIX}.zip" *) && \
echo "dnscrypt-proxy has been installed here:" && \
echo "${PREFIX}" && \
echo "The dnscrypt-proxy ZIP file has been placed here:" && \
echo "${PREFIX}.zip"
