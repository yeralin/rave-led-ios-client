//
//  ContentView.swift
//  RaveLedMatrix
//
//  Created by Daniyar Yeralin on 10/15/19.
//  Copyright © 2019 Daniyar Yeralin. All rights reserved.
//
import Combine
import SwiftUI
import CoreBluetooth

struct ScannedPeripheralsListView: View {
    
    var scannedPeripherals: [CBPeripheral]
    var pairAction: (_ peripheral: CBPeripheral) -> ()
    
    var body: some View {
        List (scannedPeripherals, id: \.name) { peripheral in
            HStack {
                Text(peripheral.name ?? "Unknown")
                Spacer()
                Button(action: {
                    self.pairAction(peripheral)
                }) {
                    Text("Pair")
                    .foregroundColor(.blue)
                }
            }
        }
    }
}

struct PairedPeripheralView: View {
    
    var peripheral: CBPeripheral?
    var unpairAction: () -> ()
    
    var body: some View {
        List {
            HStack {
                Text(peripheral?.name ?? "Unknown")
                Spacer()
                Button(action: {
                    self.unpairAction()
                }, label: {
                    Text("Disconnect")
                    .foregroundColor(.blue)
                })
            }
        }
    }
}

struct BluetoothPairingView: View {
    
    @ObservedObject var raveLedController: RaveLedController
    
    func unpairWrapper() {
        raveLedController.disconnect()
        raveLedController.startScanning()
    }
    
    
    // REMINDER: don't use SwiftUI for another 2 years
    @ViewBuilder
    var body: some View {
        ViewBuilder.buildBlock(raveLedController.paired ?
            ViewBuilder.buildEither(first:
                PairedPeripheralView(
                    peripheral: raveLedController.pairedPeripheral,
                    unpairAction: unpairWrapper))
            :
            ViewBuilder.buildEither(second:
                ScannedPeripheralsListView(
                    scannedPeripherals: raveLedController.scannedPeripherals,
                    pairAction: raveLedController.pairWith(_:))))
        .onAppear(perform: {
            if !self.raveLedController.paired {
                self.raveLedController.startScanning()
            }
        })
        .onDisappear(perform: {self.raveLedController.stopScanning()})
    }
    
}
