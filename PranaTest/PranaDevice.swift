//
//  PranaDevice.swift
//  Prana
//
//  Created by Luccas on 3/7/19.
//  Copyright © 2019 Prana. All rights reserved.
//

import Foundation
import CoreBluetooth

class PranaDevice: NSObject {
    
    var name: String!
    var rssi: Double!
    var id: String!
    var peripheral: CBPeripheral
    
    init(name: String, rssi: Double, id: String, peripheral: CBPeripheral) {
        self.name = name
        self.rssi = rssi
        self.id = id
        self.peripheral = peripheral
    }
}
