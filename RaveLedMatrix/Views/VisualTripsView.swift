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
        return index == raveLedController.activeVisual
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
                        Button(action: {
                            self.activateVisualTrip(label)
                        }, label: {
                            self.isActiveRow(label) ?
                                Text("Running") : Text("Activate")
                        })
                        .disabled(!self.raveLedController.paired || self.isActiveRow(label))
                        .foregroundColor(self.isActiveRow(label) ? .green : (self.raveLedController.paired ? .blue : .gray))
                    }
                }
            }
            .padding()
            HStack {
                Image(systemName: "lightbulb")
                .font(.title)
                    .foregroundColor(raveLedController.paired ? .yellow : .gray)
                .padding()
                Slider(value: $raveLedController.brightness, in: 0...100, step: 1)
                .disabled(!raveLedController.paired)
            }
        }
    }
}
