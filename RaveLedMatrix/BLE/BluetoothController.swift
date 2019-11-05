//
//  BluetoothController.swift
//  RaveLedMatrix
//
//  Created by Daniyar Yeralin on 10/15/19.
//  Copyright © 2019 Daniyar Yeralin. All rights reserved.
//

import UIKit
import CoreBluetooth

extension String: LocalizedError {
    public var errorDescription: String? { return self }
}

// Delegate functions
@objc protocol BluetoothControllerDelegate {
    
    @objc optional func didChangeState(_ state: CBManagerState)
    
    @objc optional func didDisconnect(_ peripheral: CBPeripheral, error: NSError?)
    
    @objc optional func didReceiveData(_ data: Data)
    
    @objc optional func didDiscoverPeripheral(_ peripheral: CBPeripheral, RSSI: NSNumber?)
    
    @objc optional func didConnect(_ peripheral: CBPeripheral)
    
    @objc optional func didFailToConnect(_ peripheral: CBPeripheral, error: NSError?)

    @objc optional func isReady(_ peripheral: CBPeripheral)
}

class BluetoothController: NSObject, CBCentralManagerDelegate, CBPeripheralDelegate {
    
    static var sharedInstance: BluetoothController = BluetoothController()
    var delegate: BluetoothControllerDelegate?
    
    private var centralManager: CBCentralManager
    private var targetPeripheral: CBPeripheral?
    private var writeType: CBCharacteristicWriteType = .withoutResponse
    private weak var readWriteCharacteristic: CBCharacteristic?
    var isReady: Bool {
        get {
            return centralManager.state == .poweredOn &&
                   targetPeripheral != nil &&
                   readWriteCharacteristic != nil
        }
    }
    var isScanning: Bool {
        return centralManager.isScanning
    }
    var isPoweredOn: Bool {
        return centralManager.state == .poweredOn
    }
    
    private let serviceUUID = CBUUID(string: "0000ffe0-0000-1000-8000-00805f9b34fb")
    private let characteristicUUID = CBUUID(string: "0000ffe1-0000-1000-8000-00805f9b34fb")
    
    override init() {
        centralManager = CBCentralManager()
        super.init()
        centralManager.delegate = self
    }
    
    func startScan() throws {
        guard isPoweredOn else {
            throw "Bluetooth is not ON, but \(centralManager.state.rawValue)"
        }
        guard !isScanning else {
            throw "Bluetooth Central is already scanning"
        }
        print("Started scanning...")
        centralManager.scanForPeripherals(withServices: nil, options: nil)
        
        // retrieve peripherals that are already connected
        // see this stackoverflow question http://stackoverflow.com/questions/13286487
        /* let peripherals = centralManager.retrieveConnectedPeripherals(withServices: nil)
        for peripheral in peripherals {
            delegate?.serialDidDiscoverPeripheral(peripheral, RSSI: nil)
        } */
    }
    
    func stopScan() throws {
        guard isScanning else {
            throw "Bluetooth is not scanning, nothing to stop"
        }
        centralManager.stopScan()
    }
    
    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        delegate?.didChangeState?(central.state)
    }
    
    func connectToPeripheral(_ peripheral: CBPeripheral) {
        centralManager.connect(peripheral, options: nil)
    }
    
    func disconnect() throws {
        guard let targetPeripheral = self.targetPeripheral else {
            throw "No peripheral to disconnect from"
        }
        centralManager.cancelPeripheralConnection(targetPeripheral)
    }
    
    func sendDataToPeripheral(_ data: Data) throws {
        guard let targetPeripheral = self.targetPeripheral else {
            throw "No connected peripheral to send data to"
        }
        guard let writeCharacteristic = self.readWriteCharacteristic else {
            throw "No known write characteristic for peripheral: \(targetPeripheral)"
        }
        print("Sending data: \(String(decoding: data, as: UTF8.self))")
        targetPeripheral.writeValue(data, for: writeCharacteristic, type: self.writeType)
    }
    
    func getDataFromPeripheral() throws {
        guard let targetPeripheral = self.targetPeripheral else {
            throw "No connected peripheral to send data to"
        }
        guard let readCharacteristic = self.readWriteCharacteristic else {
            throw "No known write characteristic for peripheral: \(targetPeripheral)"
        }
        return targetPeripheral.readValue(for: readCharacteristic)
    }
    
    // CBCentralManagerDelegate impl
    
    func centralManager(_ central: CBCentralManager, didDiscover peripheral: CBPeripheral, advertisementData: [String : Any], rssi RSSI: NSNumber) {
        print("Found peripheral: \(peripheral)")
        delegate?.didDiscoverPeripheral?(peripheral, RSSI: RSSI)
    }
    
    func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        peripheral.delegate = self
        self.targetPeripheral = peripheral
        delegate?.didConnect?(peripheral)
        peripheral.discoverServices([serviceUUID])
    }
    
    func centralManager(_ central: CBCentralManager, didDisconnectPeripheral peripheral: CBPeripheral, error: Error?) {
        self.targetPeripheral = nil
        delegate?.didDisconnect?(peripheral, error: error as NSError?)
    }
    
    func centralManager(_ central: CBCentralManager, didFailToConnect peripheral: CBPeripheral, error: Error?) {
        self.targetPeripheral = nil
        delegate?.didFailToConnect?(peripheral, error: error as NSError?)
    }
    
    // CBPeripheralDelegate impl
    
    func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
        guard let services = peripheral.services else {
            return
        }
        
        for service in services {
            peripheral.discoverCharacteristics([characteristicUUID], for: service)
        }
    }
    
    func peripheral(_ peripheral: CBPeripheral, didDiscoverCharacteristicsFor service: CBService, error: Error?) {
        guard let characteristics = service.characteristics else {
            return
        }
        for characteristic in characteristics {
            if characteristic.uuid == characteristicUUID {
                print("Discovered target characteristic, ready to read/write")
                peripheral.setNotifyValue(true, for: characteristic)
                self.readWriteCharacteristic = characteristic
                self.writeType = characteristic.properties.contains(.write) ? .withResponse : .withoutResponse
                delegate?.isReady?(peripheral)
            }
        }
    }
    
    func peripheral(_ peripheral: CBPeripheral, didUpdateValueFor characteristic: CBCharacteristic, error: Error?) {
        guard let data = characteristic.value else {
            print("Could not get value from characteristic")
            return
        }
        delegate?.didReceiveData?(data)
    }
    
}
