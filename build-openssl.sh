#!/bin/bash

# This script builds the iOS and Mac openSSL libraries with Bitcode enabled
# Download openssl http://www.openssl.org/source/ and place the tarball next to this script

# Work with Xcode 9.3 and iOS 11.3

set -e

###################################
#      OpenSSL Version
###################################
OPENSSL_VERSION="openssl-1.0.2o"
###################################

###################################
#      SDK Version
###################################
IOS_SDK_VERSION=$(xcodebuild -version -sdk iphoneos | grep SDKVersion | cut -f2 -d ':' | tr -d '[[:space:]]')
###################################

################################################
#      Minimum iOS deployment target version
################################################
MIN_IOS_VERSION="11.3"

################################################
#      Minimum OS X deployment target version
################################################
MIN_OSX_VERSION="10.13"

echo "----------------------------------------"
echo "OpenSSL version: ${OPENSSL_VERSION}"
echo "iOS SDK version: ${IOS_SDK_VERSION}"
echo "iOS deployment target: ${MIN_IOS_VERSION}"
echo "OS X deployment target: ${MIN_OSX_VERSION}"
echo "----------------------------------------"
echo " "

DEVELOPER=`xcode-select -print-path`
buildIOS()
{
  ARCH=$1

  pushd . > /dev/null
  cd "${OPENSSL_VERSION}"
  
  if [[ "${ARCH}" == "i386" || "${ARCH}" == "x86_64" ]]; then
    PLATFORM="iPhoneSimulator"
  else
    PLATFORM="iPhoneOS"
    sed -ie "s!static volatile sig_atomic_t intr_signal;!static volatile intr_signal;!" "crypto/ui/ui_openssl.c"
  fi
  echo "Start Building ${OPENSSL_VERSION} for ${PLATFORM} ${IOS_SDK_VERSION} ${ARCH}"
  
  export $PLATFORM
  export CROSS_TOP="${DEVELOPER}/Platforms/${PLATFORM}.platform/Developer"
  export CROSS_SDK="${PLATFORM}${IOS_SDK_VERSION}.sdk"
  export BUILD_TOOLS="${DEVELOPER}"
  export CC="${BUILD_TOOLS}/usr/bin/gcc -fembed-bitcode -mios-version-min=${MIN_IOS_VERSION} -arch ${ARCH}"
  
  echo "Configure"
  if [[ "${ARCH}" == "x86_64" ]]; then
    ./Configure darwin64-x86_64-cc --openssldir="/tmp/${OPENSSL_VERSION}-iOS-${ARCH}" &> "/tmp/${OPENSSL_VERSION}-iOS-${ARCH}.log"
  else
    ./Configure iphoneos-cross --openssldir="/tmp/${OPENSSL_VERSION}-iOS-${ARCH}" &> "/tmp/${OPENSSL_VERSION}-iOS-${ARCH}.log"
  fi
  # add -isysroot to CC=
  sed -ie "s!^CFLAG=!CFLAG=-isysroot ${CROSS_TOP}/SDKs/${CROSS_SDK} -mios-version-min=${MIN_IOS_VERSION} !" "Makefile"
  echo "make"
  make >> "/tmp/${OPENSSL_VERSION}-iOS-${ARCH}.log" 2>&1
  echo "make install"
  make install >> "/tmp/${OPENSSL_VERSION}-iOS-${ARCH}.log" 2>&1
  echo "make clean"
  make clean  >> "/tmp/${OPENSSL_VERSION}-iOS-${ARCH}.log" 2>&1
  popd > /dev/null
  
  echo "Done Building ${OPENSSL_VERSION} for ${ARCH}"
}
echo "Cleaning up"
rm -rf dist/include/openssl/* dist/lib/*
rm -rf /tmp/${OPENSSL_VERSION}-*
rm -rf ${OPENSSL_VERSION}
mkdir -p dist/lib
mkdir -p dist/include/openssl/
rm -rf "/tmp/${OPENSSL_VERSION}-*"
rm -rf "/tmp/${OPENSSL_VERSION}-*.log"
rm -rf "${OPENSSL_VERSION}"
if [ ! -e ${OPENSSL_VERSION}.tar.gz ]; then
  echo "Downloading ${OPENSSL_VERSION}.tar.gz"
  curl -O https://www.openssl.org/source/${OPENSSL_VERSION}.tar.gz
else
  echo "Using ${OPENSSL_VERSION}.tar.gz"
fi
echo "Unpacking openssl"
tar xfz "${OPENSSL_VERSION}.tar.gz"
buildIOS "arm64"
buildIOS "x86_64"
echo "Copying headers"
cp /tmp/${OPENSSL_VERSION}-iOS-x86_64/include/openssl/* dist/include/openssl/
echo "Building iOS libraries"
lipo "/tmp/${OPENSSL_VERSION}-iOS-arm64/lib/libcrypto.a" "/tmp/${OPENSSL_VERSION}-iOS-x86_64/lib/libcrypto.a" -create -output dist/lib/libcrypto.a
lipo "/tmp/${OPENSSL_VERSION}-iOS-arm64/lib/libssl.a" "/tmp/${OPENSSL_VERSION}-iOS-x86_64/lib/libssl.a" -create -output dist/lib/libssl.a

echo "Cleaning up"
rm -rf /tmp/${OPENSSL_VERSION}-*
rm -rf ${OPENSSL_VERSION}
echo "Done"