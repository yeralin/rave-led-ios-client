//
//  ColorPicker.swift
//  ColorPickers
//
//  Created by Kieran Brown on 10/31/19.
//  Copyright © 2019 Kieran Brown. All rights reserved.
//

import SwiftUI

enum DragState {
    case inactive
    case pressing
    case dragging(translation: CGSize)
    
    var translation: CGSize {
        switch self {
        case .inactive, .pressing:
            return .zero
        case .dragging(let translation):
            return translation
        }
    }
    
    var isActive: Bool {
        switch self {
        case .inactive:
            return false
        case .pressing, .dragging:
            return true
        }
    }
    
    var isDragging: Bool {
        switch self {
        case .inactive, .pressing:
            return false
        case .dragging:
            return true
        }
    }
}

struct RGB {
    var r: Int
    var g: Int
    var b: Int
}

extension UIColor {
    
    static func hsb(r: Double, g: Double, b: Double) -> (h: Double, s: Double, b: Double) {
        let min = r < g ? (r < b ? r : b) : (g < b ? g : b)
        let max = r > g ? (r > b ? r : b) : (g > b ? g : b)
        
        let v = max
        let delta = max - min
        
        guard delta > 0.00001 else { return (0, 0, max) }
        guard max > 0 else { return (-1, 0, v) } // Undefined, achromatic grey
        let s = delta / max
        
        let hue: (Double, Double) -> Double = { max, delta -> Double in
            if r == max { return (g-b)/delta } // between yellow & magenta
            else if g == max { return 2 + (b-r)/delta } // between cyan & yellow
            else { return 4 + (r-g)/delta } // between magenta & cyan
        }
        let h = hue(max, delta) * 60 // In degrees
        
        return ((h < 0 ? h+360 : h)/360, s, v)
    }
    
    func rgb() -> RGB {
        let r = Int(CIColor(color: self).red * 255)
        let g = Int(CIColor(color: self).green * 255)
        let b = Int(CIColor(color: self).blue * 255)
        print("R: \(r) \(CIColor(color: self).red), G: \(g) \(CIColor(color: self).green), B: \(b) \(CIColor(color: self).blue)")
        
        return RGB(r: r, g: g, b: b)
    }
}

struct ColorPicker: View {
    @GestureState var hueState: DragState = .inactive
    @GestureState var satBrightState: DragState = .inactive
    @State var hue: Double = 0.5
    @State var saturation: Double = 1
    @State var brightness: Double = 1
    var gridSize: CGSize = CGSize(width: 300, height: 170)
    var sliderSize: CGSize = CGSize(width: 260, height: 12)
    var currentColor: RGB
    var closeCallback: (RGB) -> ()
    
    init(currentColor: RGB, closeCallback: @escaping (RGB) -> ()) {
        self.currentColor = currentColor
        self.closeCallback = closeCallback
    }
    
    /// Prevent the draggable element from going over its limit
    func limitDisplacement(_ value: Double, _ limit: CGFloat, _ state: CGFloat) -> CGFloat {
        if CGFloat(value)*limit + state > limit {
            return limit
        } else if CGFloat(value)*limit + state < 0 {
            return 0
        } else {
            return CGFloat(value)*limit + state
        }
    }
    /// Prevent values like hue, saturation and brightness from being greater than 1 or less than 0
    func limitValue(_ value: Double, _ limit: CGFloat, _ state: CGFloat) -> Double {
        if value + Double(state/limit) > 1 {
            return 1
        } else if value + Double(state/limit) < 0 {
            return 0
        } else {
            return value + Double(state/limit)
        }
    }
    
    func generateRGB() -> RGB {
        print("H: \(self.hue) \(CGFloat(self.hue)), S: \(self.saturation) \(CGFloat(self.saturation)), B: \(self.brightness) \(CGFloat(self.brightness))")
        return UIColor(hue: CGFloat(self.hue),
                saturation: CGFloat(self.saturation),
                brightness: CGFloat(self.brightness),
                alpha: 1).rgb()
    }
    
    
    /// Labels for each of the Hue, Saturation and Brightness
    var labels: some View {
        VStack {
            Text("Hue: \(limitValue(self.hue, sliderSize.width, hueState.translation.width))")
            Text("Saturation: \(limitValue(self.saturation, gridSize.width, satBrightState.translation.width))")
            Text("Brightness: \(limitValue(self.brightness, gridSize.height, satBrightState.translation.height))")
        }
    }
    
    
    var body: some View {
        VStack {
            satBrightnessGrid
            hueSlider
            Button("Picked") {
                self.closeCallback(self.generateRGB())
            }
            .foregroundColor(.blue)
            .padding(.bottom, 20)
        }
        .frame(width: 300, height: 400)
        .border(Color.gray)
        .background(Color.white)
        .foregroundColor(.black)
        .onAppear(perform: {
            print(Double(self.currentColor.r)/255, Double(self.currentColor.g)/255, Double(self.currentColor.b)/255)
            print(UIColor.hsb(r: Double(self.currentColor.r)/255,
            g: Double(self.currentColor.g)/255,
            b: Double(self.currentColor.b)/255))
            (self.hue, self.saturation, self.brightness) = UIColor.hsb(r: Double(self.currentColor.r)/255,
                                                                       g: Double(self.currentColor.g)/255,
                                                                       b: Double(self.currentColor.b)/255)
        })
    }
    
    
    // MARK: Hue Slider
    
    
    func makeHueColors(stepSize: Double) -> [Color] {
        stride(from: 0, to: 1, by: stepSize).map {
            Color(hue: $0, saturation: 1, brightness: 1)
        }
    }
    
    /// Creates the `Thumb` and adds the drag gesture to it.
    func generateHueThumb(proxy: GeometryProxy) -> some View {
        
        // This gesture sequence is also directly from apples "Composing SwiftUI Gestures"
        let longPressDrag = LongPressGesture(minimumDuration: 0.05)
            .sequenced(before: DragGesture())
            .updating($hueState) { value, state, transaction in
                switch value {
                // Long press begins.
                case .first(true):
                    state = .pressing
                // Long press confirmed, dragging may begin.
                case .second(true, let drag):
                    state = .dragging(translation: drag?.translation ?? .zero)
                // Dragging ended or the long press cancelled.
                default:
                    state = .inactive
                }
        }
        .onEnded { value in
            guard case .second(true, let drag?) = value else { return }
            
            self.hue = self.limitValue(self.hue, proxy.size.width, drag.translation.width)
            
        }
        
        
        // MARK: Customize Thumb Here
        // Add the gestures and visuals to the thumb
        return Circle().overlay(hueState.isDragging ? Circle().stroke(Color.white, lineWidth: 2) : nil)
            .foregroundColor(.white)
            .frame(width: 25, height: 25, alignment: .center)
            .overlay(RoundedRectangle(cornerRadius: 25).stroke(Color.gray))
            .position(x: limitDisplacement(self.hue, self.sliderSize.width, hueState.translation.width) , y: sliderSize.height/2)
            .animation(.interactiveSpring())
            .gesture(longPressDrag)
    }
    
    var hueSlider: some View {
        GeometryReader { (proxy: GeometryProxy) in
            LinearGradient(gradient: Gradient(colors: self.makeHueColors(stepSize: 0.05)),
                                                startPoint: .leading,
                                                endPoint: .trailing)
                                        .mask(Capsule())
                                        .frame(width: self.sliderSize.width,
                                               height: self.sliderSize.height)
                                        .drawingGroup()
            .overlay(self.generateHueThumb(proxy: proxy))
        }
    }
    
    
    // MARK: Saturation and Brightness Grid
    
    
    func makeSatBrightColors(stepSize: Double) -> [Color] {
        stride(from: 0, to: 1, by: stepSize).map {
            Color(hue: limitValue(self.hue, self.sliderSize.width, hueState.translation.width), saturation: $0, brightness: $0)
        }
    }
    
    /// Creates the `Handle` and adds the drag gesture to it.
    func generateSBHandle(proxy: GeometryProxy) -> some View {
        
        // This gesture sequence is also directly from apples "Composing SwiftUI Gestures"
        let longPressDrag = LongPressGesture(minimumDuration: 0.05)
            .sequenced(before: DragGesture())
            .updating($satBrightState) { value, state, transaction in
                switch value {
                // Long press begins.
                case .first(true):
                    state = .pressing
                // Long press confirmed, dragging may begin.
                case .second(true, let drag):
                    state = .dragging(translation: drag?.translation ?? .zero)
                // Dragging ended or the long press cancelled.
                default:
                    state = .inactive
                }
        }
        .onEnded { value in
            guard case .second(true, let drag?) = value else { return }
            
            self.saturation = self.limitValue(self.saturation, proxy.size.width, drag.translation.width)
            self.brightness = self.limitValue(self.brightness, proxy.size.height, drag.translation.height)
        }
        
        
        // MARK: Customize Handle Here
        // Add the gestures and visuals to the handle
        return Circle().overlay(satBrightState.isDragging ? Circle().stroke(Color.white, lineWidth: 2) : nil)
            .foregroundColor(.white)
            .frame(width: 25, height: 25, alignment: .center)
            .position(x: limitDisplacement(self.saturation, self.gridSize.width, self.satBrightState.translation.width) , y: limitDisplacement(self.brightness, self.gridSize.height, self.satBrightState.translation.height))
            .animation(.interactiveSpring())
            .gesture(longPressDrag)
    }
    
    var satBrightnessGrid: some View {
        GeometryReader { (proxy: GeometryProxy) in
            LinearGradient(gradient: Gradient(
                colors: self.makeSatBrightColors(stepSize: 0.05)),
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing)
                .frame(width: self.gridSize.width, height: self.gridSize.height)
                .overlay(self.generateSBHandle(proxy: proxy))
        }
    }
}

