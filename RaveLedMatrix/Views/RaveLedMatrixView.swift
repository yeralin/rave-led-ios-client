//
//  RaveLedMatrixView.swift
//  RaveLedMatrix
//
//  Created by Daniyar Yeralin on 10/22/19.
//  Copyright © 2019 Daniyar Yeralin. All rights reserved.
//

import SwiftUI

struct PairedIndicatorView: View {
    
    @ObservedObject var raveLedController: RaveLedController
    
    var body: some View {
        HStack {
            Text(raveLedController.paired ? "Connected" : "Disonnected")
                .foregroundColor(raveLedController.paired ? .green : .red)
            .font(.subheadline)
            Image(systemName: raveLedController.paired ? "bolt.fill" : "bolt.slash")
                .foregroundColor(raveLedController.paired ? .green : .red)
        }
    }
}

struct RaveLedMatrixView: View {
    
    @ObservedObject private var raveLedController = RaveLedController()
    @State private var currentTab: Int = 0
    
    private var navTitleView: Text {
        switch currentTab {
        case 0: return Text("Wholesome Texts")
        case 1: return Text("Visual Trips")
        case 2: return Text("Bluetooth Pairing")
        default: fatalError("Not possible")
        }
    }
    
    var body: some View {
        NavigationView {
            VStack(alignment: .leading, spacing: 0) {
                TabView(selection: $currentTab) {
                    WholesomeTextsView(raveLedController: raveLedController)
                    .tabItem({
                        Image(systemName: "textbox")
                        Text("Wholesome Texts")
                        }).tag(0)
                    VisualTripsView(raveLedController: raveLedController)
                    .tabItem({
                        Image(systemName: "burn")
                        Text("Visual Trips")
                    }).tag(1)
                    BluetoothPairingView(raveLedController: raveLedController)
                    .tabItem({
                        Image(systemName: "antenna.radiowaves.left.and.right")
                        Text("Bluetooth")
                    }).tag(2)
                }
            }
            .alert(isPresented: $raveLedController.alert.isInAlert) {
                Alert(title: Text(raveLedController.alert.alertTitle ?? "Unknown"),
                      message: Text(raveLedController.alert.alertMessage ?? "Unknown"),
                      dismissButton: .default(Text("OK")))
            }
            .navigationBarItems(leading:
                                    Button(action: {self.raveLedController.syncNow()},
                                           label: {Text("Sync")})
                                        .disabled(!raveLedController.paired),
                                trailing: PairedIndicatorView(raveLedController: raveLedController))
            .navigationBarTitle(navTitleView)
        }
    }
}

struct RaveLedController_Previews: PreviewProvider {
    static var previews: some View {
        RaveLedMatrixView()
    }
}
