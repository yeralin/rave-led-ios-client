//
//  VisualTripsView.swift
//  RaveLedMatrix
//
//  Created by Daniyar Yeralin on 10/23/19.
//  Copyright © 2019 Daniyar Yeralin. All rights reserved.
//

import SwiftUI

struct VisualTripsView: View {
    
    @ObservedObject var raveLedController: RaveLedController
    
    private func isActiveRow(_ label: String) -> Bool {
        guard let index = raveLedController.visuals.firstIndex(of: label) else {
            return false
        }
        return index == raveLedController.activeVisualIndex
    }
    
    private func activateVisualTrip(_ label: String) {
        guard let i = self.raveLedController.visuals.firstIndex(of: label) else {
            print("Could not locate index of visual \(label)")
            return
        }
        raveLedController.triggerVisualTrip(index: i)
    }
    
    
    var body: some View {
        VStack {
            List {
                ForEach(raveLedController.visuals, id: \.self) { label in
                    HStack {
                        Text(label)
                        Spacer()
                        Text(self.isActiveRow(label) ? "Running" : "")
                        .disabled(!self.raveLedController.paired || self.isActiveRow(label))
                        .foregroundColor(self.isActiveRow(label) ? .green : (self.raveLedController.paired ? .blue : .gray))
                    }
                    .frame(height: 40)
                    .onTapGesture {
                        self.activateVisualTrip(label)
                    }
                }
            }.offset(y: 8)
            VStack {
                HStack {
                    Image(systemName: "speedometer")
                    .font(.title)
                    .foregroundColor(raveLedController.paired ? .red : .gray)
                    .frame(width: 30)
                    Slider(value: $raveLedController.speed, in: 1...200, step: 1, onEditingChanged: { sliding in
                        if !sliding {
                            self.raveLedController.triggerSpeedUpdate()
                        }
                    })
                }
                .padding()
                .disabled(!raveLedController.paired)
                HStack {
                    Image(systemName: "lightbulb")
                    .font(.title)
                    .foregroundColor(raveLedController.paired ? .yellow : .gray)
                    .frame(width: 30)
                    Slider(value: $raveLedController.brightness, in: 1...100, step: 1, onEditingChanged: { sliding in
                        if !sliding {
                            self.raveLedController.triggerBrightnessUpdate()
                        }
                    })
                    .disabled(!raveLedController.paired)
                }.padding()
            }.overlay(
                RoundedRectangle(cornerRadius: 0)
                    .stroke(Color.gray, lineWidth: 0.3)
            )
        }
        .onAppear(perform: {self.raveLedController.syncNow()})
    }
}
