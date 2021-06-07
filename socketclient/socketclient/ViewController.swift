//
//  ViewController.swift
//  socketclient
//
//  Created by Admin on 2021/05/26.
//

import Cocoa
import Socket
class ViewController: NSViewController {

    override func viewDidLoad() {
        super.viewDidLoad()

        print("hello")
        // Do any additional setup after loading the view.
        do{
            let registerRequestString = "{ \"vnd.avaya.clientresources.RegisterRequest.v1.1\" : { \"applicationId\" : \"Softlink\", \"transactionId\" : \"101\" } } \0";

            let path = "/Users/admin/Library/Application Support/com.avaya.Avaya-Equinox/AvayaCSDK-admin"
            let client = try Socket.create(family: .unix, type: .stream, proto: .unix)
            //try client.listen(on: path)

            //print("Listening on path: \(path)")
                            
            try client.connect(to: path)
            try client.write(from: registerRequestString)
                         
            print(try client.readString())
            client.close()
            print("end!!!")
        }
        catch{
            print(error)
        }
        
        
    }

    override var representedObject: Any? {
        didSet {
        // Update the view, if already loaded.
        }
    }


}

