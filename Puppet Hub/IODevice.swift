//
//  IODevice.swift
//  Mr. Puppet Hub
//
//  Created by Edward Wellbrook on 02/08/2019.
//  Copyright © 2019 Thinko LLC. All rights reserved.
//

import Foundation
import IOKit
import IOKit.serial

func getDeviceProperty(device: io_object_t, key: String) -> AnyObject? {
    let cfKey = key as CFString
    let propValue = IORegistryEntryCreateCFProperty(device, cfKey, kCFAllocatorDefault, 0)
    return propValue?.takeUnretainedValue()
}

private func getParentProperty(device: io_object_t, key: String) -> AnyObject? {
    return IORegistryEntrySearchCFProperty(device, kIOServicePlane, key as CFString, kCFAllocatorDefault, IOOptionBits(kIORegistryIterateRecursively | kIORegistryIterateParents))
}

func availableSerialDevices() -> [(String, String)] {
    var devices: [(String, String)] = []

    var match = IOServiceMatching(kIOSerialBSDServiceValue) as? [String: AnyObject]
    match?[kIOSerialBSDTypeKey] = kIOSerialBSDAllTypes as AnyObject

    var iterator = io_iterator_t()
    IOServiceGetMatchingServices(kIOMasterPortDefault, match as CFDictionary?, &iterator)

    while case let device = IOIteratorNext(iterator), device != MACH_PORT_NULL {
        guard let calloutDevice = getDeviceProperty(device: device, key: kIOCalloutDeviceKey) as? String else {
            continue
        }

        guard getParentProperty(device: device, key: "idVendor") != nil else {
            continue
        }

        let productName = getParentProperty(device: device, key: "USB Product Name") as? String

        devices.append((productName ?? calloutDevice, calloutDevice))
    }

    return devices
}
