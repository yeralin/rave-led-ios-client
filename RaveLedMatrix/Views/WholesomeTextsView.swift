//
//  WholesomeTextsView.swift
//  RaveLedMatrix
//
//  Created by Daniyar Yeralin on 10/23/19.
//  Copyright © 2019 Daniyar Yeralin. All rights reserved.
//

import SwiftUI

enum WholesomeTextAction {
    case insert
    case delete
    case activate
}

extension UIApplication {
    func endEditing() {
        sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
    }
}

struct WholesomeTextsView: View {
    
    @ObservedObject var raveLedController: RaveLedController
    @State private var inputText: String = ""
    
    
    private func isActiveRow(_ label: String) -> Bool {
        guard let index = raveLedController.wholesomeTexts.firstIndex(of: label) else {
            return false
        }
        return index == raveLedController.activeText
    }
    
    private func activateVisualTrip(_ label: String) {
        raveLedController.updateWholesomeTexts(text: label, action: .activate)
    }
    
    private func deleteTextEntry(at offsets: IndexSet) {
        guard offsets.count == 1, let i = offsets.first else {
            print("Not supposed to have more than one entry to delete")
            return
        }
        raveLedController.updateWholesomeTexts(text: raveLedController.wholesomeTexts[i], action: .delete)
    }
    
    private func appendTextEntry() {
        guard inputText.count > 0 else {
            print("Input text is NaN")
            return
        }
        raveLedController.updateWholesomeTexts(text: inputText, action: .insert)
        inputText = ""
        UIApplication.shared.endEditing()
    }
    
    var body: some View {
        VStack {
            HStack {
                TextField("Wholesome to append", text: $inputText)
                    .disabled(!raveLedController.paired)
                .textFieldStyle(RoundedBorderTextFieldStyle())
                Button(action: appendTextEntry,
                       label: { Text("Add").fontWeight(.bold) })
                .disabled(!raveLedController.paired)
            }
            .padding()
            List {
                ForEach(raveLedController.wholesomeTexts, id: \.self) { label in
                    HStack {
                        Text(label)
                        Spacer()
                        Button(action: {
                            
                        }, label: {
                            self.isActiveRow(label) ?
                                Text("Running") : Text("Activate")
                        })
                        .disabled(!self.raveLedController.paired || self.isActiveRow(label))
                        .foregroundColor(self.isActiveRow(label) ? .green : (self.raveLedController.paired ? .blue : .gray))
                    }
                }
                .onDelete(perform: deleteTextEntry)
            }
            HStack {
                Image(systemName: "lightbulb")
                .font(.title)
                .foregroundColor(raveLedController.paired ? .yellow : .gray)
                .padding()
                Slider(value: $raveLedController.brightness, in: 0...100, step: 1, onEditingChanged: { sliding in
                    if !sliding {
                        self.raveLedController.triggerBrightnessUpdate()
                    }
                })
                .disabled(!raveLedController.paired)
            }
        }
    }
}
