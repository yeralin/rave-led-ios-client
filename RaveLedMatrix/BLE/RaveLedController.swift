//
//  RaveLedController.swift
//  RaveLedController
//
//  Created by Daniyar Yeralin on 10/28/19.
//  Copyright © 2019 Daniyar Yeralin. All rights reserved.
//

import Combine
import SwiftUI
import CoreBluetooth

extension Notification.Name {
    static var receivedValueFromBLE: Notification.Name {
        return .init("BluetoothController.receivedValue")
    }
}

struct AlertContainer {
    var isInAlert = false
    var alertTitle: String?
    var alertMessage: String?
}

final class RaveLedController: ObservableObject {
    
    @Published var scannedPeripherals: [CBPeripheral] = []
    @Published var pairedPeripheral: CBPeripheral? = nil
    @Published var paired: Bool = false
    
    @Published var speed: Double = 0
    @Published var brightness: Double = 0
    
    @Published var wholesomeTexts: [String] = []
    @Published var activeTextIndex: Int = -1
    @Published var textRepeats: Double = -1
    @Published var activeColor: RGB = RGB(r: 0,g: 0,b: 255)
    @Published var isRefreshing: Bool = false
    @Published var isPickingColor: Bool = false
    
    @Published var visuals: [String] = ["TwinkleFOX", "Attract","Bounce","FlowField","Incremental Drift", "PendulumWave", "Radar", "Spiral", "Wave"]
    @Published var activeVisualIndex = -1
    
    @Published var alert: AlertContainer = AlertContainer()
    
    private var didReceiveDataCallback: ((_ payload: [String: Any]) -> ())?
    
    init() {
        BluetoothController.sharedInstance.delegate = self
    }
    
    private func serializeJson(_ dict: [String: Any]) throws -> Data {
        return try JSONSerialization.data(withJSONObject: dict, options: [])
    }
    
    private func deserializeJson(_ payload: Data) throws -> [String: Any]? {
        return try JSONSerialization.jsonObject(with: payload, options: []) as? [String : Any]
    }
    
    func syncNow() {
        do {
            let payload = try serializeJson(["op": "sync"])
            let receivedResponse: (_: [String: Any]) -> () = { payload in
                if payload["response"] as? String == "ok" {
                    self.brightness = payload["brightness"] as? Double ?? 1
                    self.speed = payload["speed"] as? Double ?? 100
                    self.textRepeats = payload["repeats"] as? Double ?? 1
                    self.activeColor = RGB(r: payload["r"] as? Int ?? 0,
                                           g: payload["g"] as? Int ?? 0,
                                           b: payload["b"] as? Int ?? 255)
                    self.activeTextIndex = payload["activeTextIndex"] as? Int ?? -1
                    self.activeVisualIndex = payload["activePatternIndex"] as? Int ?? -1
                } else {
                    self.alert = AlertContainer(isInAlert: true,
                                                alertTitle: "Unexpected activate visual response",
                                                alertMessage: "Received \(payload["reason"] ?? "unknown")")
                }
            }
            sendValue(payload, callback: receivedResponse)
        } catch let err {
            print(err)
        }
    }
    
    func refreshTexts() {
        isRefreshing = true;
        DispatchQueue.global(qos: .userInitiated).async {
            var finished = false
            for (i, text) in self.wholesomeTexts.enumerated() {
                let payload: [String: Any] = ["op": "text",
                                              "val": text,
                                              "index": i,
                                              "action": String(describing: WholesomeTextAction.insert)]
                let receivedResponse: ([String: Any]) -> () = { payload in
                    finished = true
                }
                self.sendValue(try! self.serializeJson(payload), callback: receivedResponse)
                while !finished {
                    usleep(100000)
                }
                finished = false
            }
            DispatchQueue.main.sync {
                self.isRefreshing = false
            }
        }
    }
    
    func updateWholesomeTexts(text: String, action: WholesomeTextAction) {
        do {
            var receivedResponse: ([String: Any]) -> ()
            var payload: [String: Any] = ["op": "text", "action": String(describing: action)]
            switch action {
            case .insert:
                payload["val"] = text
                payload["index"] = wholesomeTexts.count
                receivedResponse = { payload in
                    if payload["response"] as? String == "inserted" {
                        self.wholesomeTexts.append(text)
                        UserDefaults.standard.set(self.wholesomeTexts, forKey: "wholesomeTexts")
                    } else {
                        self.alert = AlertContainer(isInAlert: true,
                                                   alertTitle: "Unexpected \(String(describing: action)) response",
                                                   alertMessage: "Received \(payload["reason"] ?? "unknown")")
                    }
                }
            case .activate:
                guard let i = self.wholesomeTexts.firstIndex(of: text) else {
                    fatalError("Could not find arg text")
                }
                payload["index"] = i
                receivedResponse = { payload in
                    if payload["response"] as? String == "activated" {
                        self.activeTextIndex = i
                        self.activeVisualIndex = -1
                    } else {
                        self.alert = AlertContainer(isInAlert: true,
                                                    alertTitle: "Unexpected \(String(describing: action)) response",
                                                    alertMessage: "Received \(payload["reason"] ?? "unknown")")
                    }
                }
            case .delete:
                guard let i = self.wholesomeTexts.firstIndex(of: text) else {
                    fatalError("Could not find arg text")
                }
                payload["index"] = i
                receivedResponse = { payload in
                    if payload["response"] as? String == "deleted" {
                        self.wholesomeTexts.remove(at: i)
                    } else {
                        self.alert = AlertContainer(isInAlert: true,
                                                    alertTitle: "Unexpected \(String(describing: action)) response",
                                                    alertMessage: "Received \(payload["reason"] ?? "unknown")")
                    }
                }
            case .repeats:
                payload["repeats"] = self.textRepeats
                receivedResponse = { payload in
                    if payload["response"] as? String != "updated" {
                        self.alert = AlertContainer(isInAlert: true,
                                                    alertTitle: "Unexpected \(String(describing: action)) response",
                                                    alertMessage: "Received \(payload["reason"] ?? "unknown")")
                    }
                }
            }
            sendValue(try serializeJson(payload), callback: receivedResponse)
        } catch let err {
            print(err)
        }
    }
    
    func triggerVisualTrip(index: Int) {
        do {
            let payload = try serializeJson(["op": "visual", "index": index])
            let receivedResponse: (_: [String: Any]) -> () = { payload in
                if payload["response"] as? String == "activated" {
                    self.activeVisualIndex = index
                    self.activeTextIndex = -1
                } else {
                    self.alert = AlertContainer(isInAlert: true,
                                                alertTitle: "Unexpected activate visual response",
                                                alertMessage: "Received \(payload["reason"] ?? "unknown")")
                }
            }
            sendValue(payload, callback: receivedResponse)
        } catch let err {
            print(err)
        }
    }
    
    func triggerBrightnessUpdate() {
        do {
            let payload = try serializeJson(["op": "brightness", "val": brightness])
            let receivedResponse: (_ payload: [String: Any]) -> () = { payload in
                if payload["response"] as? String != "updated" {
                    self.alert = AlertContainer(isInAlert: true,
                                                alertTitle: "Unexpected brightness update response",
                                                alertMessage: "Received \(payload["reason"] ?? "unknown")")
                }
            }
            sendValue(payload, callback: receivedResponse)
        } catch let err {
            print(err)
        }
    }
    
    func triggerSpeedUpdate() {
        do {
            let payload = try serializeJson(["op": "speed", "val": speed])
            let receivedResponse: (_ payload: [String: Any]) -> () = { payload in
                if payload["response"] as? String != "updated" {
                    self.alert = AlertContainer(isInAlert: true,
                                                alertTitle: "Unexpected speed update response",
                                                alertMessage: "Received \(payload["reason"] ?? "unknown")")
                }
            }
            sendValue(payload, callback: receivedResponse)
        } catch let err {
            print(err)
        }
    }
    
    func triggerRepeatsUpdate() {
        do {
            let payload = try serializeJson(["op": "repeats", "val": textRepeats])
            let receivedResponse: (_ payload: [String: Any]) -> () = { payload in
                if payload["response"] as? String != "updated" {
                    self.alert = AlertContainer(isInAlert: true,
                                                alertTitle: "Unexpected speed update response",
                                                alertMessage: "Received \(payload["reason"] ?? "unknown")")
                }
            }
            sendValue(payload, callback: receivedResponse)
        } catch let err {
            print(err)
        }
    }
    
    
    func triggerColorUpdate() {
        do {
            let rgb = self.activeColor
            let payload = try serializeJson(["op": "color", "r": rgb.r, "g": rgb.g, "b": rgb.b])
            let receivedResponse: (_ payload: [String: Any]) -> () = { payload in
                if payload["response"] as? String != "updated" {
                    self.alert = AlertContainer(isInAlert: true,
                                                alertTitle: "Unexpected color update response",
                                                alertMessage: "Received \(payload["reason"] ?? "unknown")")

                }
            }
            sendValue(payload, callback: receivedResponse)
        } catch let err {
            print(err)
        }
    }
}

// BluetoothControllerDelegate Impl
// Another reason not to use SwiftUI for another few years! :/

extension RaveLedController: BluetoothControllerDelegate {
    
    func didChangeState(_ state: CBManagerState) {
        switch state {
        case .unknown:
            print("State is unknown")
        case .resetting:
            print("State is resetting")
        case .unsupported:
            print("State is unsupported")
        case .unauthorized:
            print("State is unauthorized")
        case .poweredOff:
            print("State is poweredOff")
        case .poweredOn:
            print("State is poweredOn")
        @unknown default:
            print("State is \(state.rawValue)")
        }
    }
    
    func isScanning() -> Bool {
         return BluetoothController.sharedInstance.isScanning
     }
     
     func startScanning() {
         do {
             try BluetoothController.sharedInstance.startScan()
         } catch let err {
             print(err)
         }
     }
     
     func stopScanning() {
         do {
             try BluetoothController.sharedInstance.stopScan()
         } catch let err {
             print(err)
         }
     }
     
     func pairWith(_ peripheral: CBPeripheral) {
        BluetoothController.sharedInstance.connectToPeripheral(peripheral)
     }
     
     func disconnect() {
        do {
            try BluetoothController.sharedInstance.disconnect()
        } catch let err {
            print(err)
        }
    }
    
    func didConnect(_ peripheral: CBPeripheral) {
        print("Connected to peripheral: \(peripheral)")
        self.pairedPeripheral = peripheral
        self.paired = true
        try? BluetoothController.sharedInstance.stopScan()
        self.scannedPeripherals.removeAll()
    }
    
    func didDisconnect(_ peripheral: CBPeripheral, error: NSError?) {
        print("Disconnected from peripheral: \(peripheral)")
        self.pairedPeripheral = nil
        self.paired = false
    }
    
    func didDiscoverPeripheral(_ peripheral: CBPeripheral, RSSI: NSNumber?) {
        if !self.scannedPeripherals.contains(peripheral){
            self.scannedPeripherals.append(peripheral)
        }
    }
    
    func pollData() {
        do {
            try BluetoothController.sharedInstance.getDataFromPeripheral()
        } catch let err {
            print(err)
        }
    }
    
    func didReceiveData(_ data: Data) {
        do {
            print("Received data: \(String(decoding: data, as: UTF8.self))")
            guard let callback = didReceiveDataCallback else {
                return
            }
            guard let payload = try deserializeJson(data) else {
                throw "Could not deserialize received payload"
            }
            callback(payload)
        } catch let err {
            print(err)
        }
        self.didReceiveDataCallback = nil
    }
    
    func sendValue(_ data: Data, callback: (([String: Any]) -> ())?) {
        do {
            try BluetoothController.sharedInstance.sendDataToPeripheral(data)
            pollData()
            self.didReceiveDataCallback = callback
        } catch let err {
            print(err)
        }
    }
    
}
