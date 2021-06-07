//
//  ViewController.swift
//  SoftlinkAW
//
//  Created by Admin on 2021/05/26.
//

import Cocoa
import USBDeviceSwift
import Socket
import SwiftyJSON

class ViewController: NSViewController {
    
    
    @IBAction func BtnRing(_ sender: Any) {
        print("ring")
        SendRingCmd(ring: true)
        self.ring = true
    }
    
    @IBOutlet weak var PrgImage: NSImageView!
    
    @IBOutlet weak var HookState: NSTextField!
    @IBOutlet weak var MuteState: NSTextField!
    
    
    var connectedDevice:JPLDevice?
    var isFirstConnected:Bool = false
    
    var ring:Bool = false
    var hook:Bool = true
    var mute:Bool = false
    var isPushMuteButton:Bool = false
    var isPushHookButton:Bool = false
    var isSendCmd:Bool = false
    
    var callState:String = ""
    var isFromIX:Bool = false  // check command from ix
    
    var isConnected:Bool = false
    var isRunning:Bool = false
    
    var client:Socket?
    
    // avaya callId
    var callId:String = ""
    
    
    
    @IBOutlet weak var DeviceName: NSTextField!
    @IBOutlet weak var DeviceImage: NSImageView!
    
    
    


    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()

        
        
        
        try? self.connectToAW()
        
        Timer.scheduledTimer(timeInterval: 1.0, target: self, selector: #selector(timerwork(timer:)), userInfo: ["score": 10], repeats: true)
        
        Timer.scheduledTimer(timeInterval: 0.5, target: self, selector: #selector(timerwork2(timer:)), userInfo: ["score": 10], repeats: true)
//
        
        isFirstConnected = false
//
        NotificationCenter.default.addObserver(self, selector: #selector(self.usbConnected), name: .HIDDeviceConnected, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(self.usbDisconnected), name: .HIDDeviceDisconnected, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(self.hidReadData), name: .HIDDeviceDataReceived, object: nil)
        
        
         
        
    }

    override var representedObject: Any? {
        didSet {
        // Update the view, if already loaded.
        }
    }
    
    
    // programm running check
    @objc func timerwork(timer: Timer)
    {
        
        let applications = NSWorkspace.shared.runningApplications
        
        
//        if(applications.contains(NSRunningApplication.))
//        {
//                print("com.avaya.Avaya-Equinox run")
//        }
        var processname:String
        // com.avaya.Avaya-Equinox
        var tempisRunning:Bool = false
        for app in applications {
            processname =  app.localizedName!
            //print(processname)
            if(processname.hasPrefix("Avaya")){
                //print(processname)  //Avaya Workplace
                tempisRunning = true
                break
            }
                
        }
        self.isRunning = tempisRunning
        
        if(self.isRunning)
        {
            PrgImage.isHidden = false
            HookState.isHidden = false
            MuteState.isHidden = false
            
            if(self.hook)
            {
                HookState.textColor = NSColor.blue
                HookState.stringValue = "Hook On"
            }
            else
            {
                HookState.textColor = NSColor.red
                HookState.stringValue = "Hook Off"
            }
            
            if(self.mute)
            {
                MuteState.textColor = NSColor.red
                MuteState.stringValue = "Mute On"
            }
            else
            {
                MuteState.textColor = NSColor.blue
                MuteState.stringValue = "Mute Off"
            }
            
        }
        else
        {
            PrgImage.isHidden = true
            HookState.isHidden = true
            MuteState.isHidden = true
        }
        
        
        
    }
    
    @objc func timerwork2(timer: Timer)
    {
        
        
        if(self.isConnected)
        {
            //print("read from socket")
            
            try? self.readdataFromAW()
            //let readdata:String = try self.client?.readString()! as! String
                
           // print( try self.client?.readString()! as Any)
            
            if(self.isPushMuteButton)
            {
                self.isPushMuteButton = false
                if(!self.hook)
                {
                    if(self.mute)
                    {
                        let muteString:String = "{ \"vnd.avaya.clientresources.call.MuteRequest.v1.1\" : { \"callId\": \"" + self.callId + "\", \"muted\": \"true\", \"transactionId\": \"101\" } } \0";
                        
                        do{
                            try client?.write(from: muteString)
                        }
                        catch{
                            
                        }
                    }
                    else{
                        let muteString:String = "{ \"vnd.avaya.clientresources.call.MuteRequest.v1.1\" : { \"callId\": \"" + self.callId + "\", \"muted\": \"false\", \"transactionId\": \"101\" } } \0";
                        
                        do{
                            try client?.write(from: muteString)
                        }
                        catch{
                            
                        }
                    }
                }
                
            }
            
            if(self.isPushHookButton)
            {
                self.isPushHookButton = false

                print("isPushHookButton","hook",self.hook)
                print("callState",self.callState)
                print("self.isFromIX",self.isFromIX)
                print("self.ring",self.ring)
                
                if(self.callState == "alerting" )
                {
                    print("if ring AcceptRequest "+self.callId)

                    let CallString:String = "{ \"vnd.avaya.clientresources.call.AcceptRequest.v1.1\" : {  \"callId\": \"" + self.callId + "\", \"transactionId\": \"101\" } } \0";

                    do{
                        try client?.write(from: CallString)
                    }
                    catch{
                        print(error)
                    }
                    
                    

                }
                else if(self.hook)
                {
                    print("self.isFromIX",self.isFromIX)
                    
                    let CallString:String = "{ \"vnd.avaya.clientresources.call.TerminateRequest.v1.1\" : { \"callId\": \"" + self.callId + "\", \"transactionId\": \"101\" } } \0";

                    do{
                        try client?.write(from: CallString)
                    }
                    catch{

                    }
                }
                
                self.isFromIX = false
            }
            
            
        }
        else
        {
            //print("do nothing")
        }
    }
    
    @objc func usbConnected(notification: NSNotification) {
        
        print("usbConnected")
        
        
        guard let nobj = notification.object as? NSDictionary else {
            return
        }
        
        guard let deviceInfo:HIDDevice = nobj["device"] as? HIDDevice else {
            return
        }
        
        let device = JPLDevice(deviceInfo)
        
        
        
        DispatchQueue.main.async {
            //self.deviceName.stringValue = deviceInfo.name
            let rtnInfo = self.selectDeviceImage(devicename: deviceInfo.name)
            //print("vid",deviceInfo.vendorId)
            //print("pid",deviceInfo.productId)
          
            let h1 = String(deviceInfo.vendorId, radix: 16)
            //print("vid 0x",h1) // "3d"
            let h2 = String(deviceInfo.productId, radix: 16)
            //print("pid 0x",h2) // "3d"
            
            print("vid",h1,"pid",h2)
            
            
            self.DeviceName.stringValue = rtnInfo.1
            
            
            //print(rtnInfo.0)
            //print(rtnInfo.1)
            
            let image = NSImage(named: rtnInfo.0)
            
            self.DeviceImage.image = image
            
            self.isFirstConnected = true
            
            if(!self.isFirstConnected){
                
            }
            else {
               
            }
            
            // init
            self.ring = false
            self.hook = true
            self.mute = false
            

            
            self.connectedDevice = device
            
           
        }
        
    }
    
    @objc func usbDisconnected(notification: NSNotification) {
        
        print("usbDisconnected")
        
        
        DispatchQueue.main.async {
            print("usbDisconnected 3 ")
            self.DeviceName.stringValue = "No Device"
            
            
            let image = NSImage(named: "NOUSB")
            self.DeviceImage.image = image
            self.connectedDevice = nil
            
            self.ring = false
            self.hook = true
            self.mute = false
            
            
            
            
        }
    }
    
    // usb -> softlink
    @objc func hidReadData(notification: Notification) {
        let obj = notification.object as! NSDictionary
        let data = obj["data"] as! Data
        
        //print(data[0],data[1],data[2],data[3],data[4],data[5],data[6],data[7],data[8])
        if let str = self.connectedDevice?.convertByteDataToString(data) {
            
            DispatchQueue.main.async {
                if(str.count>0)
                {
                    print("usb -> app hid msg",str," self.isFromIX  ",self.isFromIX,"self.isSendCmd",self.isSendCmd)
                    
                    if(str == "hookon")
                    {
                        if(!self.hook)
                        {
                            self.isPushHookButton = true
                            
                        }
                        
                        //self.SendHookCmd(hook: true)
                        
                       
                        
                        self.hook = true
                        self.ring = false
                        self.mute = false
                        self.isFromIX = false
                        self.isSendCmd = false
                    }
                    else if(str == "hookoff")
                    {
                        self.isPushHookButton = true
                        //print("hiddata hookoff")
                        if(self.ring)
                        {
                            self.SendHookCmd(hook: false)
                            self.hook = false
                            self.ring = false
                            print("ring stop -> hook off")
                        }
                        

                    }
                    
                    if(str == "mute")
                    {
                        self.isPushMuteButton = true
                        if(!self.mute)
                        {
                            print("app mute off --> on")
                            
                        }
                        else
                        {
                            print("app mute on --> off")
                        }
                        
                        self.mute = !self.mute
                       
                    }
                }
                    
            }
            
        }
    }
    
    func connectToAW() throws
    {
        
        
        print("try to connectToAW")
        
        let username = NSUserName()
        print("username",username)
        let path = "/Users/"+username+"/Library/Application Support/com.avaya.Avaya-Equinox/AvayaCSDK-"+username
        
        self.client = try Socket.create(family: .unix, type: .stream, proto: .unix)
        // "/Users/admin/Library/Application Support/com.avaya.Avaya-Equinox/AvayaCSDK-admin"
        print("path",path)
        try self.client?.connect(to: path)
        self.isConnected = true
//
        print("connectToAW isconnected")
        
        print("write register")
        let registerRequestString = "{ \"vnd.avaya.clientresources.RegisterRequest.v1.1\" : { \"applicationId\" : \"Softlink\", \"transactionId\" : \"101\" } } \0";
        try client?.write(from: registerRequestString)
    }

    func readdataFromAW() throws
    {
        //print("read data from AW 1")
        try self.client?.setReadTimeout(value: 1)
        //print(try self.client?.readString() ?? "default value")
        let rtnstr:String = try self.client?.readString() ?? ""
        
        //print("readdataFromAW")
        
        

        
        if(rtnstr.count>0)
        {
            let rtnStringArr = rtnstr.components(separatedBy: "\0")
            //print("json array count",rtnStringArr.count)
            
            for item in rtnStringArr {
    
                
                //print("item",item)
                //print("item count",item.count)
                //print("item last",item.last)
                
                if(item.count>0)
                {
                    if let dataFromString = item.data(using: .utf8, allowLossyConversion: false) {
                        let json = try JSON(data: dataFromString)
                        
                        //print("json",json)
                        
                        let callState = json["vnd.avaya.clientresources.call.UpdatedEvent.v1.1"]["vnd.avaya.clientresources.Call.v1.1"]["callState"]
        
        
                        let muted =  json["vnd.avaya.clientresources.call.UpdatedEvent.v1.1"]["vnd.avaya.clientresources.Call.v1.1"]["muted"]
        
                        let callId = json["vnd.avaya.clientresources.call.UpdatedEvent.v1.1"]["vnd.avaya.clientresources.Call.v1.1"]["callId"]
                        
                        let audioDirection = json["vnd.avaya.clientresources.call.UpdatedEvent.v1.1"]["vnd.avaya.clientresources.Call.v1.1"]["audioDirection"]
                        //"audioDirection" : "send_receive",
                        
                        print("IX callState",callState,"muted",muted)
                       
                        self.callState = callState.stringValue
                        
                        if(callState.stringValue == "ignored")
                        {
                            self.isFromIX = true
                            
                            if(self.ring)
                            {
                                self.ring = false
                                SendRingCmd(ring: false)
                            }
                            
                            if(!self.hook)
                            {
                                SendHookCmd(hook: true)
                                self.hook = true
                            }
                            
                            
                        }
                        else if(callState.stringValue == "ended")
                        {
                            self.isFromIX = true
                            print("received call ended from ix")
                            
                            if(self.ring)
                            {
                                self.ring = false
                                SendRingCmd(ring: false)
                            }
                            
                            self.mute = false
                            SendMuteCmd(mute: false)
                            
                            SendHookCmd(hook: true)
                            self.hook = true

                            return
                        }
                        else if(callState.stringValue == "established")
                        {
                            print("callState init 1")
                            if(muted == "true")
                            {
                                self.mute = true
                                SendMuteCmd(mute: true)
                            }
                            else
                            {
                                self.mute = false
                                SendMuteCmd(mute: false)
                            }
                            
                        }
                        
                        if(!callState.isEmpty)
                        {
                            
                            
                            print("callId",callId)
                        }
                        
                        
                        
                        if(audioDirection.stringValue == "send_receive"||callState.stringValue == "alerting")
                        {
                            if(callId.stringValue != "")
                            {
                                self.callId = callId.stringValue
                                print("self.callId",self.callId)
                                
                                
                                if(callState.stringValue == "alerting")
                                {
                                    self.ring = true
                                    SendRingCmd(ring: true)
                                }
                               
                                
                                // ix -> softlink
                                else if(callState.stringValue == "established")
                                {
                                    self.isFromIX = true
                                    if(self.ring)
                                    {
                                        self.ring = false
                                        SendRingCmd(ring: false)
                                    }
                                    self.hook = false
                                    SendHookCmd(hook: false)
                                    
                                    
                                }
                                
                                
                            }
                        }
                        
                        
                        
                        
                        
                        
                        
                                        
                    }
                }
            }
  
        }

    }

    
    func SendHookCmd(hook:Bool)
    {
        self.isSendCmd = true
        
        //print(hook)
        if (hook)
        {
            //print("app->usb : hook on cmd", hook)
            let writeData = Data([ 0x02, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00  ])
            connectedDevice?.write(writeData);

        }
        else
        {
            //print("app->usb : hook off cmd", hook)
            let writeData = Data([ 0x02, 0x01, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00 ])
            connectedDevice?.write(writeData);

        }
    }
    
    func SendMuteCmd(mute:Bool)
    {
        if (mute)
        {
            //print("app->usb : mute on cmd", mute)
            let writeData = Data([ 0x03, 0x01, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00  ])
            connectedDevice?.write(writeData);
            

           
            
        }
        else
        {
            //print("app->usb : mute off cmd", mute)
            let writeData = Data([ 0x03, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00 ])
            connectedDevice?.write(writeData);
            
     
            
           
        }
    }
    
    func SendRingCmd(ring:Bool)
    {
        //print(hook)
        if (ring)
        {
            print("app->usb : ring on cmd", ring)
            let writeData = Data([ 0x04, 0x01, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00 ])
           
            connectedDevice?.write(writeData);

        }
        else
        {
            print("app->usb : ring off cmd", ring)
            let writeData = Data([ 0x04, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00 ])
            connectedDevice?.write(writeData);

        }
    }
    
    func selectDeviceImage(devicename: String) -> (String,String) {
        
        var rtnDeviceName = "Lync_new"
        var rtnDeviceImageName = "Lync_new"
        
        rtnDeviceName = devicename
        
        if (devicename.count>0)
        {
            if (devicename=="Lync USB Headset1")
            {
                rtnDeviceImageName = "Lync_new"
            }
            else if (devicename=="Lync USB Headset")
            {
                rtnDeviceImageName = "Lync_new"
            }
            else if (devicename=="DSU-08M")
            {
                rtnDeviceImageName = "DSU-08M"
            }
            else if (devicename=="BL-052L")
            {
                rtnDeviceImageName = "DSU-08M"
            }
                //===============================================================================
            else if (devicename=="DSU-09M")
            {
                rtnDeviceImageName = "DSU-09M"
            }
            else if (devicename=="BL-05MS")
            {
                rtnDeviceImageName = "DSU-09M"
            }
            else if (devicename=="DSU-09MT")
            {
                rtnDeviceImageName = "DSU-09M"
            }
            else if (devicename=="DSU-09ML")
            {
                rtnDeviceImageName = "DSU-09M"
            }
            else if (devicename=="DSU-09M-2CH")
            {
                rtnDeviceImageName = "DSU-09M"
            }
            else if (devicename=="JPL-400M")
            {
                rtnDeviceImageName = "JPL400M"
            }
            else if (devicename=="JPL-400B")
            {
                rtnDeviceImageName = "JPL400B"
            }
                //=============================================================================
            else if (devicename=="DSU-10M")
            {
                rtnDeviceImageName = "DSU-10M"
            }
            else if (devicename=="DSU-10M-2CH")
            {
                rtnDeviceImageName = "DSU-10M"
            }
            else if (devicename=="DSU-10ML-2CH")
            {
                rtnDeviceImageName = "DSU-10M"
            }
            else if (devicename=="BL-053")
            {
                rtnDeviceImageName = "BL-053"
            }
            else if (devicename=="BL-05")
            {
                rtnDeviceImageName = "JPL-611-IB"
            }
                //=============================================================================
            else if (devicename=="DSU-11M")
            {
                rtnDeviceImageName = "DSU-11M"
            }
            else if (devicename=="DSU-11M-2CH")
            {
                rtnDeviceImageName = "DSU-11M"
            }
            else if (devicename=="BL-054MS")
            {
                rtnDeviceImageName = "DSU-11MBL-054MS"
            }
                //=============================================================================
            else if (devicename=="DSU-15M")
            {
                rtnDeviceImageName = "DSU-15M"
            }
            else if (devicename=="DW-779U Lync")
            {
                rtnDeviceImageName = "DW-779U1"
            }
            else if (devicename=="X-400")
            {
                rtnDeviceImageName = "Lync_new"
            }
            else if (devicename=="DW-800U")
            {
                rtnDeviceImageName = "X500_Base_with_USB_Module"
                
            }
            else if (devicename=="X-500U")
            {
                rtnDeviceImageName = "X500_Base_with_USB_Module"
            }
            else if (devicename=="VoicePro 575")
            {
                rtnDeviceImageName = "VoicePro_575"
            }
            else if (devicename=="JPL Companion")
            {
                rtnDeviceImageName = "VoicePro-575"
            }
            else if (devicename=="DA-575")
            {
                rtnDeviceImageName = "VoicePro-575"
            }
            else if (devicename=="EHS-CI-01")
            {
                rtnDeviceImageName = "LYNC"
            }
            else if (devicename=="BT-200")
            {
                rtnDeviceImageName = "BT200"
            }
            else if (devicename=="BT-200U")
            {
                rtnDeviceImageName = "BT200"
            }
            
        }
        //rtnDeviceImageName = "DSU-08M"
        //rtnDeviceImageName = "VoicePro-575"
        //rtnDeviceImageName = "LYNC"
        // rtnDeviceImageName = "DSU-11MBL-054MS"
        //print (rtnDeviceImageName)
        
        return (rtnDeviceImageName,rtnDeviceName)
    }


}
