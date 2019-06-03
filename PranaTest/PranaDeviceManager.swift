//
//  PranaDeviceManager.swift
//  Prana
//
//  Created by Luccas on 3/7/19.
//  Copyright © 2019 Prana. All rights reserved.
//

import Foundation
import CoreBluetooth

protocol PranaDeviceManagerDelegate {
    func PranaDeviceManagerDidStartScan()
    func PranaDeviceManagerDidStopScan(with error: String?)
    func PranaDeviceManagerDidDiscover(_ device: PranaDevice)
    func PranaDeviceManagerDidConnect(_ deviceName: String)
    func PranaDeviceManagerFailConnect()
    func PranaDeviceManagerDidOpenChannel()
    func PranaDeviceManagerDidReceiveData(_ parameter: CBCharacteristic)
    func PranaDeviceManagerDidReceiveLiveData(_ data: String!)
}

class PranaDeviceManager: NSObject, CBCentralManagerDelegate, CBPeripheralDelegate {
    
    static let RX_SERVICE_UUID = "6E400001-B5A3-F393-E0A9-E50E24DCCA9E"
    static let RX_CHAR_UUID = "6E400002-B5A3-F393-E0A9-E50E24DCCA9E"
    static let TX_CHAR_UUID = "6E400003-B5A3-F393-E0A9-E50E24DCCA9E"
    
    let concurrentQueue = DispatchQueue(label: "ScanningQueue")
    
    //MARK: Singleton Share PranaDeviceManager
    static let shared = PranaDeviceManager()
    
    var isRunning: Bool = false
    
    let centralManager: CBCentralManager
    
    var delegate: PranaDeviceManagerDelegate?
    private var delegates = [PranaDeviceManagerDelegate]()
    
    var currentDevice: CBPeripheral?
    var isConnected: Bool = false
    
    var rxChar: CBCharacteristic?
    
    var needStopLive = false
    
    var delaySeconds = 4
    
    override init() {
        
        self.centralManager = CBCentralManager(delegate: nil, queue: concurrentQueue, options: [CBCentralManagerOptionShowPowerAlertKey: true])
        super.init()
        self.centralManager.delegate = self
    }
    
    open func prepare() {
        
    }
    
    open func startScan() {
        isRunning = true
        if self.centralManager.state == .poweredOn {
            start()
            self.delegate?.PranaDeviceManagerDidStartScan()
            return
        }
        self.delegate?.PranaDeviceManagerDidStopScan(with: "Bluetooth is turned off.")
        return
    }
    
    open func stopScan() {
        if isRunning {
            isRunning = false
            if self.centralManager.state == .poweredOn {
                stop()
                self.delegate?.PranaDeviceManagerDidStopScan(with: nil)
                return
            }
        }
    }
    
    open func startGettingLiveData() {
        guard let char = self.rxChar else {
            return
        }
        
        needStopLive = false
        buff = nil
        currentDevice?.writeValue("start20hzdata".data(using: .utf8)!, for: char, type: .withoutResponse)
    }
    
    open func sendCommand(_ command: String) {
        guard let char = self.rxChar else {
            return
        }
        print("command " + command)
        currentDevice?.writeValue(command.data(using: .utf8)!, for: char, type: .withoutResponse)
    }
    
    open func stopGettingLiveData() {
        guard let char = self.rxChar else {
            return
        }
        
        needStopLive = true
        currentDevice?.writeValue("stopData".data(using: .utf8)!, for: char, type: .withoutResponse)
    }
    
    private func start() {
        //        self.centralManager.delegate = self
        disconnect()
        self.centralManager.scanForPeripherals(withServices: nil, options: [CBCentralManagerScanOptionAllowDuplicatesKey: false])
    }
    
    private func stop() {
        self.centralManager.stopScan()
        //        self.centralManager.delegate = nil
    }
    
    open func addDelegate(_ delegate: PranaDeviceManagerDelegate) {
        self.delegates.append(delegate)
    }
    
    open func removeDelegate(_ delegate: PranaDeviceManagerDelegate) {
        var i: Int = 0
        for item in self.delegates {
            let obj1 = delegate as! NSObject
            let obj2 = item as! NSObject
            if obj2.isEqual(obj1) {
                break
            }
            i = i + 1
        }
        self.delegates.remove(at: i)
    }
    
    open func connectTo(_ device: CBPeripheral) {
        
        let prevDevice = currentDevice
        currentDevice = device
        
        if isConnected == true {
            self.centralManager.cancelPeripheralConnection(prevDevice!)
        }
        
        isConnected = true
        
        self.centralManager.connect(currentDevice!, options: nil)
    }
    
    open func reconnect() {
        if isConnected == true {
            self.centralManager.cancelPeripheralConnection(currentDevice!)
        }
    }
    
    open func disconnect() {
        if isConnected == true {
            isConnected = false
            self.centralManager.cancelPeripheralConnection(currentDevice!)
        }
        
        currentDevice = nil
        self.rxChar = nil
    }
    
    //MARK: Notify to Delegates
    func didConnect() {
        for item in self.delegates {
            item.PranaDeviceManagerDidConnect(currentDevice?.name ?? "Unknown")
        }
    }
    
    func failConnect() {
        disconnect()
        for item in self.delegates {
            item.PranaDeviceManagerFailConnect()
        }
    }
    
    func didReceiveData(_ parameter: CBCharacteristic) {
        for item in self.delegates {
            item.PranaDeviceManagerDidReceiveData(parameter)
        }
        
        processLiveData(parameter)
    }
    
    var buff: String?
    
    func processLiveData(_ parameter: CBCharacteristic) {
        guard let data  = String(data: parameter.value!, encoding: .utf8) else {
            return
        }
        
        if data.starts(with: "20hz,") || data.starts(with: "Upright,") {
            if let raw = buff {
                if !needStopLive {
                    for item in self.delegates {
                        item.PranaDeviceManagerDidReceiveLiveData(raw)
                    }
                }
            }
            
            buff = data
        }
        else {
            if let _ = buff {
                buff = buff! + data
            }
            else {
                buff = data
            }
        }
    }
    
    
    //MARK: CBCentralManagerDelegate
    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        if central.state == .poweredOn {
            if isRunning {
                start()
                self.delegate?.PranaDeviceManagerDidStartScan()
            }
        }
        else {
            if isRunning {
                stop()
                self.delegate?.PranaDeviceManagerDidStopScan(with: "Bluetooth is turned off.")
            }
        }
    }
    
    func centralManager(_ central: CBCentralManager, didDiscover peripheral: CBPeripheral, advertisementData: [String : Any], rssi RSSI: NSNumber) {
        
//        Log.d("discover a peripheral - \(peripheral.name ?? "Unknown")")
        //        if peripheral.name?.starts(with: "PM5") == true {
        let c2device = PranaDevice(name: peripheral.name ?? "Unknown", rssi: RSSI.doubleValue, id: peripheral.identifier.uuidString, peripheral: peripheral)
        self.delegate?.PranaDeviceManagerDidDiscover(c2device)
        //        }
        
    }
    
    func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
//        Log.d("didConnect: \(peripheral.identifier)")
        if isConnected == true {
            if peripheral.isEqual(currentDevice) {
                didConnect()
                peripheral.delegate = self
                peripheral.discoverServices([CBUUID(string: PranaDeviceManager.RX_SERVICE_UUID)])
            }
        }
    }
    
    func centralManager(_ central: CBCentralManager, didFailToConnect peripheral: CBPeripheral, error: Error?) {
//        Log.d("didFailToConnect")
        if isConnected == true {
            if peripheral.isEqual(currentDevice) {
                failConnect()
            }
        }
    }
    
    func centralManager(_ central: CBCentralManager, didDisconnectPeripheral peripheral: CBPeripheral, error: Error?) {
//        Log.d("didDisConnectPeripheral")
        // try to re-connect
        if isConnected == true {
            if peripheral.isEqual(currentDevice) {
                failConnect()
//                tryReconnect()
            }
        }
    }
    
    func tryReconnect() {
        let peripherals = self.centralManager.retrievePeripherals(withIdentifiers: [currentDevice!.identifier])
        
        if let item = peripherals.first {
            currentDevice = item
            self.centralManager.connect(currentDevice!, options: nil)
        }
        else {
            isConnected = false
            currentDevice = nil
            failConnect()
        }
    }
    
    //MARK: CBPeripheralDelegate
    func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
        if error != nil {
//            Log.e((error?.localizedDescription)!)
            return
        }
        
        if let services = peripheral.services {
            for service in services {
//                Log.d("discovered service - \(service.uuid.uuidString)")
                
                if service.uuid.uuidString == PranaDeviceManager.RX_SERVICE_UUID {
                    peripheral.discoverCharacteristics(nil, for: service)
                }
            }
        }
        
    }
    
    func peripheral(_ peripheral: CBPeripheral, didDiscoverCharacteristicsFor service: CBService, error: Error?) {
        if error != nil {
//            Log.e((error?.localizedDescription)!)
            return
        }
        
        if let chars = service.characteristics {
            for char in chars {
//                Log.d("discovered characteristic - \(char.uuid.uuidString)")

                switch char.uuid.uuidString {
                case PranaDeviceManager.TX_CHAR_UUID:
                    peripheral.setNotifyValue(true, for: char)
                case PranaDeviceManager.RX_CHAR_UUID:
                    self.rxChar = char
                default:
                    continue
                }
            }
        }
    }
    
    func peripheral(_ peripheral: CBPeripheral, didUpdateNotificationStateFor characteristic: CBCharacteristic, error: Error?) {
        if error != nil {
//            Log.e((error?.localizedDescription)!)
            return
        }
        
        if characteristic.isNotifying {
//            Log.d("start subscribing from - \(characteristic.uuid.uuidString)")
            concurrentQueue.asyncAfter(deadline: DispatchTime.now() + .seconds(delaySeconds)) {
                for item in self.delegates {
                    item.PranaDeviceManagerDidOpenChannel()
                }
            }
        }
        else {
//            Log.d("end subscribing from - \(characteristic.uuid.uuidString)")
        }
    }
    
    func peripheral(_ peripheral: CBPeripheral, didUpdateValueFor characteristic: CBCharacteristic, error: Error?) {
        if error != nil {
//            Log.e((error?.localizedDescription)!)
            return
        }
        
//        Log.d("received data - \(String(describing: String(data: characteristic.value!, encoding: .utf8)))")
        
        didReceiveData(characteristic)
    }
}

