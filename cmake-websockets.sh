#!/usr/bin/env bash
cd libwebsockets
cmake -G Xcode -DLWS_WITH_SSL=OFF -DLWS_WITHOUT_TESTAPPS=OFF -DLWS_WITHOUT_CLIENT=ON
