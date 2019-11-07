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
    case repeats
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
        return index == raveLedController.activeTextIndex
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
        ZStack {
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
                        GeometryReader { g -> Text in
                            let frame: CGRect = g.frame(in: CoordinateSpace.global)

                            if frame.origin.y > 250 {
                                if !self.raveLedController.isRefreshing && self.raveLedController.paired {
                                    self.raveLedController.refreshTexts()
                                }
                                return Text(self.raveLedController.paired ? "Refreshing" : "")
                            } else {
                                return Text("")
                            }
                        }
                        .frame(height: 0)
                        ForEach(raveLedController.wholesomeTexts, id: \.self) { label in
                            HStack {
                                Text(label)
                                Spacer()
                                Text(self.isActiveRow(label) ? "Running" : "")
                                .disabled(!self.raveLedController.paired || self.isActiveRow(label))
                                .foregroundColor(self.isActiveRow(label) ? .green : (self.raveLedController.paired ? .blue : .gray))
                            }
                            .frame(height: 40)
                            .onTapGesture {
                                print("tap")
                                self.raveLedController.updateWholesomeTexts(text: label, action: .activate)
                            }
                        }
                        .onDelete(perform: deleteTextEntry)
                    }.offset(y: 8)
                    VStack {
                        ZStack {
                            RoundedRectangle(cornerRadius: 10)
                                .fill(Color(red:   Double(self.raveLedController.activeColor.r)/255,
                                            green: Double(self.raveLedController.activeColor.g)/255,
                                            blue:  Double(self.raveLedController.activeColor.b)/255, opacity: 1))
                                .frame(width: 360, height: 35)
                            Button("Pick") {
                                self.raveLedController.isPickingColor = true
                            }
                            .foregroundColor(raveLedController.paired ? .white : .gray)
                        }
                        .offset(y: 10)
                        .disabled(!raveLedController.paired)
                        HStack {
                            ZStack {
                                Image(systemName: "arrow.2.squarepath")
                                .font(.title)
                                .foregroundColor(raveLedController.paired ? .blue : .gray)
                                Text(raveLedController.textRepeats <= 0 ? "" : "\(Int(raveLedController.textRepeats))")
                                .font(.caption)
                            }
                            .frame(width: 30)
                            Slider(value: $raveLedController.textRepeats, in: 1...10, step: 1, onEditingChanged: { sliding in
                                if !sliding {
                                    self.raveLedController.triggerRepeatsUpdate()
                                }
                            })
                        }.padding()
                        .disabled(!raveLedController.paired)
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
                        }.padding()
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
                
            
            
            if self.raveLedController.isPickingColor {
                ColorPicker(currentColor: self.raveLedController.activeColor) {
                    self.raveLedController.activeColor = $0
                    self.raveLedController.isPickingColor = false
                    self.raveLedController.triggerColorUpdate()
                }
            }
        }
        .onAppear(perform: {
            self.raveLedController.syncNow()
            self.raveLedController.wholesomeTexts = UserDefaults.standard.object(forKey: "wholesomeTexts") as? [String] ?? [String]()
        })
    }
}

