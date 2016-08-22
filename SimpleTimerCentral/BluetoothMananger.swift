//
//  BluetoothMananger.swift
//  SimpleTimerCentral
//
//  Created by Jay Tucker on 6/30/15.
//  Copyright (c) 2015 Imprivata. All rights reserved.
//

import Foundation
import CoreBluetooth

class BluetoothManager: NSObject {
    
    private let serviceUUID        = CBUUID(string: "193DB24F-E42E-49D2-9A70-6A5616863A9D")
    private let characteristicUUID = CBUUID(string: "43CDD5AB-3EF6-496A-A4CC-9933F5ADAF68")
    
    private let timeoutInSecs = 5.0
    
    private var centralManager: CBCentralManager!
    private var peripheral: CBPeripheral!
    private var characteristic: CBCharacteristic!
    private var isPoweredOn = false
    private var scanTimer: NSTimer!
    
    private var isBusy = false
    
    // See:
    // http://stackoverflow.com/questions/24218581/need-self-to-set-all-constants-of-a-swift-class-in-init
    // http://stackoverflow.com/questions/24441254/how-to-pass-self-to-initializer-during-initialization-of-an-object-in-swift
    override init() {
        super.init()
        centralManager = CBCentralManager(delegate:self, queue:nil)
    }
    
    private func timestamp() -> String {
        let dateFormatter = NSDateFormatter()
        dateFormatter.dateFormat = "YYYY-MM-dd HH:mm:ss.SSS"
        return dateFormatter.stringFromDate(NSDate())
    }
    
    private func log(message: String) {
        print("[\(timestamp())] \(message)")
    }
    
    func go() {
        log("go")
        if (isBusy) {
            log("busy, ignoring request")
            return
        }
        isBusy = true
        startScanForPeripheralWithService(serviceUUID)
    }
    
    private func startScanForPeripheralWithService(uuid: CBUUID) {
        log("startScanForPeripheralWithService")
        centralManager.stopScan()
        scanTimer = NSTimer.scheduledTimerWithTimeInterval(timeoutInSecs, target: self, selector: #selector(BluetoothManager.timeout), userInfo: nil, repeats: false)
        centralManager.scanForPeripheralsWithServices([uuid], options: nil)
    }
    
    // can't be private because called by timer
    func timeout() {
        log("timed out")
        centralManager.stopScan()
        isBusy = false
    }
    
}

extension BluetoothManager: CBCentralManagerDelegate {
    
    func centralManagerDidUpdateState(central: CBCentralManager) {
        var caseString: String!
        switch centralManager.state {
        case .Unknown:
            caseString = "Unknown"
        case .Resetting:
            caseString = "Resetting"
        case .Unsupported:
            caseString = "Unsupported"
        case .Unauthorized:
            caseString = "Unauthorized"
        case .PoweredOff:
            caseString = "PoweredOff"
        case .PoweredOn:
            caseString = "PoweredOn"
        }
        log("centralManagerDidUpdateState \(caseString)")
        isPoweredOn = (centralManager.state == .PoweredOn)
        if isPoweredOn {
            // go()
        }
    }
    
    
    func centralManager(central: CBCentralManager, didDiscoverPeripheral peripheral: CBPeripheral, advertisementData: [String : AnyObject], RSSI: NSNumber) {
        log("centralManager didDiscoverPeripheral")
        scanTimer.invalidate()
        centralManager.stopScan()
        self.peripheral = peripheral
        centralManager.connectPeripheral(peripheral, options: nil)
    }
    
    func centralManager(central: CBCentralManager, didConnectPeripheral peripheral: CBPeripheral) {
        log("centralManager didConnectPeripheral")
        self.peripheral.delegate = self
        peripheral.discoverServices([serviceUUID])
    }
    
}

extension BluetoothManager: CBPeripheralDelegate {
    
    func peripheral(peripheral: CBPeripheral, didDiscoverServices error: NSError?) {
        if error == nil {
            log("peripheral didDiscoverServices ok")
        } else {
            log("peripheral didDiscoverServices error \(error!.localizedDescription)")
            return
        }
        for service in peripheral.services! {
            log("service \(service.UUID)")
            peripheral.discoverCharacteristics(nil, forService: service)
        }
    }
    
    func peripheral(peripheral: CBPeripheral, didDiscoverCharacteristicsForService service: CBService, error: NSError?) {
        if error == nil {
            log("peripheral didDiscoverCharacteristicsForService \(service.UUID) ok")
        } else {
            log("peripheral didDiscoverCharacteristicsForService error \(error!.localizedDescription)")
            return
        }
        for characteristic in service.characteristics! {
            log("characteristic \(characteristic.UUID)")
            if characteristic.UUID == characteristicUUID {
                self.characteristic = characteristic 
            }
        }
        peripheral.writeValue(NSData(), forCharacteristic: characteristic, type: CBCharacteristicWriteType.WithResponse)
    }
    
    func peripheral(peripheral: CBPeripheral, didWriteValueForCharacteristic characteristic: CBCharacteristic, error: NSError?) {
        if error == nil {
            log("peripheral didWriteValueForCharacteristic ok")
        } else {
            log("peripheral didWriteValueForCharacteristic error \(error!.localizedDescription)")
        }
        disconnect()
    }
    
    private func disconnect() {
        log("disconnect")
        centralManager.cancelPeripheralConnection(peripheral)
        peripheral = nil
        characteristic = nil
        isBusy = false
    }
    
}
