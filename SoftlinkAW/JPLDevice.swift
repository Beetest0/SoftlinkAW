//
//  JPLDevice.swift
//  DasanFactoryApp
//
//  Created by Admin on 2021/04/25.
//

import Cocoa
import USBDeviceSwift

class JPLDevice: NSObject {
    let deviceInfo:HIDDevice
    
    var hookStatus:Bool = true
    var clickMute:Bool = false
    
    required init(_ deviceInfo:HIDDevice) {
        self.deviceInfo = deviceInfo
    }
    
    func write(_ data:Data) {
        let count = data.count / MemoryLayout<UInt8>.size
        var bytesArray = [UInt8](repeating: 0, count: count)
        
        data.copyBytes(to: &bytesArray, count:count * MemoryLayout<UInt8>.size)
        
        
       
        
        let correctData = Data(bytes: UnsafePointer<UInt8>(bytesArray), count: self.deviceInfo.reportSize)
        
        IOHIDDeviceSetReport(
            self.deviceInfo.device,
            kIOHIDReportTypeOutput,
            CFIndex(bytesArray[0]),
            (correctData as NSData).bytes.bindMemory(to: UInt8.self, capacity: correctData.count),
            correctData.count
        )
    }
    
    // Additional: convertion bytes to specific string, removing garbage etc.
    func convertByteDataToString(_ data:Data) -> String {
        let count = data.count / MemoryLayout<UInt8>.size
        var array = [UInt8](repeating: 0, count: count)
        //print("count",count)
        
        data.copyBytes(to: &array, count:count * MemoryLayout<UInt8>.size)
        
        
        
        print("msg id : ",array[0],array[1],array[2])
        
        
        if(array[0]==0x01)
        {
            
            if(self.clickMute)
            {
                self.clickMute = false
                return ""
            }
            
            if(array[1]==0x08 && array[2]==0x00)
            {
                
                return "hookon"
            }
            
            if(array[1]==0x08 && array[2]==0x08)
            {
                self.clickMute = true
                return "mute"
            }
            
//            if(array[1]==0x08)
//            {
//                self.clickMute = true
//                return "mute"
//            }
            
            
            
            if(array[2]==0x00)
            {
                
                return "hookon"
            }
            
            if(array[2]==0x08)
            {
                
                return "hookoff"
            }
            
        }
        
        if(array[0]==0x05)
        {
            if(array[1]==0x02)
            {
                
                return "volumedown"
            }
            
            if(array[1]==0x01)
            {
                
                return "volumeup"
            }
            
            
            
        }
        
        return ""
    }
}

