#!/usr/bin/env bash

ORIGDIR=`pwd`
BUILDDIR=`pwd`/xcodebuild

echo "[0] Clean"
rm -rf out xcodebuild Helper/.theos

echo "[1] Build app"
cd App
xcodebuild build -scheme Santander -configuration "Release" CODE_SIGNING_ALLOWED="NO" CODE_SIGNING_REQUIRED="NO" CODE_SIGN_IDENTITY="" BUILD_DIR=$BUILDDIR

echo "[2] Build helper"
cd ../Helper
make clean
make FINALPACKAGE=1
cd $ORIGDIR

echo "[3] Package IPA"
mkdir -p out/ipa/Payload
cp -R xcodebuild/Release-iphoneos/Santander.app out/ipa/Payload
cp Helper/.theos/obj/santanderhelper out/ipa/Payload/Santander.app/santanderhelper

ldid -SApp/entitlements.plist out/ipa/Payload/Santander.app

cd out/ipa
zip -r ../Santander.ipa .
cd $ORIGDIR
rm -rf xcodebuild

echo "IPA is in out/Santander.ipa"
