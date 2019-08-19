#!/usr/bin/env bash
rm -rf deps/libwebsockets/CMakeCache.txt
mkdir -p deps/libwebsockets
cd deps/libwebsockets
export MACOSX_DEPLOYMENT_TARGET=10.12
export CMAKE_OSX_DEPLOYMENT_TARGET=10.12
cmake -G Xcode -U CMAKE_OSX_DEPLOYMENT_TARGET -DLWS_WITH_SSL=OFF -DLWS_WITHOUT_TESTAPPS=ON -DLWS_WITHOUT_CLIENT=ON ../../libwebsockets
