//
//  ConnectViewController.swift
//  Prana
//
//  Created by Luccas on 3/14/19.
//  Copyright © 2019 Prana. All rights reserved.
//

import UIKit
import CoreBluetooth


class ConnectViewController: UIViewController {

    var isScanning = false
    var isConnected = false
    var isTutorial = true
    
    @IBOutlet weak var lblConnected: UILabel!
    
    var needStartImmediately = true
    var needStopImmediately = true
    
    @IBOutlet weak var lalBattery: UILabel!
    
    @IBOutlet weak var lblLowBattery: UILabel!
    
    @IBOutlet weak var lblReady: UILabel!
    
    @IBOutlet weak var logView: UITextView!
    
    func appendLog(_ message: String) {
        if let original = logView.text {
            logView.text = "\(original)\n\(message)"
        }
        else {
            logView.text = message
        }
        
        if logView.text.count > 0 {
            let location = logView.text.count - 1
            let bottom = NSMakeRange(location, 1)
            logView.scrollRangeToVisible(bottom)
        }

    }
    
    override func viewDidLoad() {
        super.viewDidLoad()

        // Do any additional setup after loading the view.
        
        lblConnected.textColor = .lightGray
        lblLowBattery.textColor = .lightGray
        
        lblReady.textColor = .lightGray
        PranaDeviceManager.shared.delegate = self
        PranaDeviceManager.shared.addDelegate(self)
        
        appendLog("add delegate")
        
        appendLog("try to start scanning")
        startScanPrana()
        
        
    }
    
    @IBAction func onStart(_ sender: Any) {
        appendLog("command start live")
        PranaDeviceManager.shared.startGettingLiveData()
    }
    @IBAction func onStop(_ sender: Any) {
        appendLog("command stop live")
        PranaDeviceManager.shared.stopGettingLiveData()
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        
        if self.isMovingFromParent {
            appendLog("going back")
            appendLog("try to stop scanning")
            stopScanPrana()
            
            if PranaDeviceManager.shared.isConnected {
                appendLog("prana is still connected")
                appendLog("command stop live")
                PranaDeviceManager.shared.stopGettingLiveData()
                appendLog("command disconnect")
                PranaDeviceManager.shared.disconnect()
                appendLog("remove delegate")
                PranaDeviceManager.shared.removeDelegate(self)
                PranaDeviceManager.shared.delegate = nil
            }
        }
    }
    
    @IBAction func onBack(_ sender: Any) {
        self.navigationController?.popViewController(animated: true)
    }
    
    func startScanPrana() {
        isScanning = true
        
        appendLog("command start scan")
        PranaDeviceManager.shared.startScan()
    }
    
    func stopScanPrana() {
        guard isScanning else {
            return
        }
        
        isScanning = false
        DispatchQueue.main.async {
            self.appendLog("command stop scan")
        }
        PranaDeviceManager.shared.stopScan()
        
    }
    
    func connectPrana(_ device: PranaDevice) {
        DispatchQueue.main.async {
            self.appendLog("command connect to \(device.peripheral.identifier)")
        }
        
        PranaDeviceManager.shared.connectTo(device.peripheral)
    }
    
    func onNewLiveData(_ raw: String) {
        appendLog("new live data\n\(raw)")
        
        lblReady.textColor = .lightGray

        let paras = raw.split(separator: ",")
        
        if paras[0] == "20hz" {
            if paras.count != 7 {
                appendLog("wrong packet")
                return
            }
            
            if needStopImmediately {
                appendLog("need to stop immediately")
                appendLog("command stop live")
                PranaDeviceManager.shared.stopGettingLiveData()
            }
            
            let level = Int(paras[6])!
            
            appendLog("get battery level \(level)%")
            lalBattery.text = "Battery Level \(level)%"

            if level < 50 {
                appendLog("low battery warning")
                lblLowBattery.textColor = .red
            }
            else {
                lblLowBattery.textColor = .lightGray
            }
            
            lblReady.textColor = .red
            appendLog("Now Prana is ready to use!")
        }
        
        appendLog("processing live data end")
    }
    
    /*
    // MARK: - Navigation

    // In a storyboard-based application, you will often want to do a little preparation before navigation
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        // Get the new view controller using segue.destination.
        // Pass the selected object to the new view controller.
    }
    */

}

extension ConnectViewController: PranaDeviceManagerDelegate {
    func PranaDeviceManagerDidOpenChannel() {
        if needStartImmediately {
            DispatchQueue.main.async {
                self.appendLog("channel is opened")
                self.appendLog("command start live")
            }
            PranaDeviceManager.shared.startGettingLiveData()
        }
        else {
            DispatchQueue.main.async {
                self.appendLog("channel is opened")
            }
        }
    }
    
    func PranaDeviceManagerDidReceiveLiveData(_ data: String!) {
        DispatchQueue.main.async {
            self.onNewLiveData(data)
        }
    }
    
    func PranaDeviceManagerDidStartScan() {
        DispatchQueue.main.async {
            self.appendLog("scanning started")
        }

    }
    
    func PranaDeviceManagerDidStopScan(with error: String?) {
        DispatchQueue.main.async {
            self.appendLog("scanning stopped")
        }

    }
    
    func PranaDeviceManagerDidDiscover(_ device: PranaDevice) {
        
        DispatchQueue.main.async {
            self.appendLog("a device is discovered: \(device.name)")
        }
        
        if device.name.contains("Prana Tech")
            || device.name.contains("iPod touch") {
            stopScanPrana()
            connectPrana(device)
        }
    }
    
    func PranaDeviceManagerDidConnect(_ deviceName: String) {
        DispatchQueue.main.async {
            self.appendLog("device is connected: \(deviceName)")
            self.lblConnected.textColor = .red
        }
    }
    
    func PranaDeviceManagerFailConnect() {
        DispatchQueue.main.async {
            self.appendLog("device fail connect")
            self.lblConnected.textColor = .lightGray
        }
    }
    
    func PranaDeviceManagerDidReceiveData(_ parameter: CBCharacteristic) {
        
    }
    
    
}
