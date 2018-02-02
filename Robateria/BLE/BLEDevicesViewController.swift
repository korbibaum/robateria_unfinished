//
//  BLEDevicesViewController.swift
//  Robateria
//
//  Created by Korbinian Baumer on 14.01.18.
//  Copyright © 2018 Korbinian Baumer. All rights reserved.
//

import Foundation
import UIKit
import CoreBluetooth


class BLEDevicesViewController : UIViewController, CBCentralManagerDelegate, CBPeripheralDelegate, UITableViewDelegate, UITableViewDataSource{

    //Properties
    @IBOutlet weak var deviceTable: UITableView!
    @IBOutlet weak var refreshButton: UIBarButtonItem!

    //Variables
    var centralManager : CBCentralManager!
    var RSSIs = [NSNumber]()
    var data = NSMutableData()
    var writeData: String = ""
    var peripherals: [CBPeripheral] = []
    var services: [[CBService]?] = [[]]
    var characteristicValue = [CBUUID: NSData]()
    var timer = Timer()
    var characteristics = [String : CBCharacteristic]()

    var selectedDevice : CBPeripheral?
    var characteristicASCIIValue = NSString()

    var projectZeroServices: [CBUUID] = [Service0UUID, Service1UUID, Service2UUID, Service3UUID]

    @IBAction func refreshAction(_ sender: Any) {
        disconnectFromDevice()
        self.peripherals = []
        self.RSSIs = []
        self.deviceTable.reloadData()
        startScan()
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        self.deviceTable.delegate = self
        self.deviceTable.dataSource = self
        self.deviceTable.reloadData()

        centralManager = CBCentralManager(delegate: self, queue: nil)
    }

    override func viewDidAppear(_ animated: Bool) {
        disconnectFromDevice()
        super.viewDidAppear(animated)
        refreshScanView()
        print("View Cleared")
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        print("Stop Scanning")
        centralManager?.stopScan()
    }


    // start scanning
    func startScan() {
        peripherals = []
        print("Now Scanning...")
        self.timer.invalidate()
        centralManager?.scanForPeripherals(withServices: nil, options: [CBCentralManagerScanOptionAllowDuplicatesKey:false])
        Timer.scheduledTimer(timeInterval: 17, target: self, selector: #selector(self.cancelScan), userInfo: nil, repeats: false)
    }

    //stop scan
    @objc func cancelScan() {
        self.centralManager?.stopScan()
        print("Scan Stopped")
        print("Number of Peripherals Found: \(peripherals.count)")
    }


    func refreshScanView() {
        deviceTable.reloadData()
    }

    //Terminate Connection
    func disconnectFromDevice () {
        if selectedDevice != nil {
            centralManager?.cancelPeripheralConnection(selectedDevice!)
        }
    }

    func restoreCentralManager() {
        centralManager?.delegate = self
    }

    func centralManager(_ central: CBCentralManager, didDiscover peripheral: CBPeripheral,advertisementData: [String : Any], rssi RSSI: NSNumber) {

        selectedDevice = peripheral
        self.peripherals.append(peripheral)
        self.RSSIs.append(RSSI)
        peripheral.delegate = self
        self.deviceTable.reloadData()
        if selectedDevice == nil {
            print("New pheripheral devices with services")
            print("Peripheral name: \(String(describing: peripheral.name))")
            print ("Advertisement Data : \(advertisementData)")
        }
    }

    //-Connection
    func connectToDevice () {

        centralManager?.connect(selectedDevice!, options: nil)
        print ("")
        print ("")
        print("Peripheral UUID")
        print(selectedDevice?.identifier as Any)
    }


    //-Connected
    func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        print("*****************************")
        print("Connection complete")
        print("Peripheral info: \(String(describing: selectedDevice))")

        //Stop Scan because we are already connected
        centralManager?.stopScan()
        print("Scan Stopped")

        //Erase data that we might have
        data.length = 0

        //Discovery callback
        peripheral.delegate = self
        //TODO: replace nil, with array of service UUIDs that we need to discover
        peripheral.discoverServices(nil)


        //Once connected, move to new view controller to manager incoming and outgoing data
        //TODO: Segue connection
        let storyboard = UIStoryboard(name: "Main", bundle: nil)
        let CommunicationViewController = storyboard.instantiateViewController(withIdentifier: "CommunicationViewController") as! CommunicationViewController

        CommunicationViewController.btDevice = selectedDevice
        CommunicationViewController.title = selectedDevice?.name
        selectedDevice?.delegate = CommunicationViewController
        selectedDevice?.discoverServices(nil)
        CommunicationViewController.bleDeviceVC = self

        navigationController?.pushViewController(CommunicationViewController, animated: true)
    }

    /*
     Invoked when the central manager fails to create a connection with a peripheral.
     */

    func centralManager(_ central: CBCentralManager, didFailToConnect peripheral: CBPeripheral, error: Error?) {
        if error != nil {
            print("Failed to connect to peripheral")
            return
        }
    }

    func disconnectAllConnection() {
        centralManager.cancelPeripheralConnection(selectedDevice!)
    }

    func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
        print("*******************************************************")

        if ((error) != nil) {
            print("Error discovering services: \(error!.localizedDescription)")
            return
        }

        guard let services = peripheral.services else {
            return
        }
        //We need to discover the all characteristic
        for service in services {

            peripheral.discoverCharacteristics(nil, for: service)
            // bleService = service
        }
        print("Discovered Services: \(services)")
    }

    /*
     Invoked when you discover the characteristics of a specified service.
     This method is invoked when your app calls the discoverCharacteristics(_:for:) method. If the characteristics of the specified service are successfully discovered, you can access them through the service's characteristics property. If successful, the error parameter is nil. If unsuccessful, the error parameter returns the cause of the failure.
     */

    func peripheral(_ peripheral: CBPeripheral, didDiscoverCharacteristicsFor service: CBService, error: Error?) {

        print("*******************************************************")

        if ((error) != nil) {
            print("Error discovering services: \(error!.localizedDescription)")
            return
        }

        guard let characteristics = service.characteristics else {
            return
        }

        print("Found \(characteristics.count) characteristics!")

        for characteristic in characteristics {
            //looks for the right characteristic

            print("Characteristic: \(characteristic.uuid)")
            peripheral.discoverDescriptors(for: characteristic)
            print("value: \(peripheral.readValue(for: characteristic))")
            print("---setNotify---")
            print(peripheral.setNotifyValue(true, for: characteristic))

        }
    }

    // Getting Values From Characteristic

    /*After you've found a characteristic of a service that you are interested in, you can read the characteristic's value by calling the peripheral "readValueForCharacteristic" method within the "didDiscoverCharacteristicsFor service" delegate.
     */
    func peripheral(_ peripheral: CBPeripheral, didUpdateValueFor characteristic: CBCharacteristic, error: Error?) {

            if let ASCIIstring = NSString(data: characteristic.value!, encoding: String.Encoding.utf8.rawValue) {
                characteristicASCIIValue = ASCIIstring
                print("Value Recieved: \((characteristicASCIIValue as String))")
                NotificationCenter.default.post(name:NSNotification.Name(rawValue: "Notify"), object: nil)

        }
    }


    func peripheral(_ peripheral: CBPeripheral, didDiscoverDescriptorsFor characteristic: CBCharacteristic, error: Error?) {
        print("*******************************************************")

        if error != nil {
            print("\(error.debugDescription)")
            return
        }
        if ((characteristic.descriptors) != nil) {

            for x in characteristic.descriptors!{
                let descript = x as CBDescriptor!
                print("function name: DidDiscoverDescriptorForChar \(String(describing: descript?.description))")
            }
        }
    }


    func peripheral(_ peripheral: CBPeripheral, didUpdateNotificationStateFor characteristic: CBCharacteristic, error: Error?) {
        print("*******************************************************")

        if (error != nil) {
            print("Error changing notification state:\(String(describing: error?.localizedDescription))")

        } else {
            print("Characteristic's value subscribed")
        }

        if (characteristic.isNotifying) {
            print ("Subscribed. Notification has begun for: \(characteristic.uuid)")
        }
    }



    func centralManager(_ central: CBCentralManager, didDisconnectPeripheral peripheral: CBPeripheral, error: Error?) {
        print("Disconnected")
    }


    func peripheral(_ peripheral: CBPeripheral, didWriteValueFor characteristic: CBCharacteristic, error: Error?) {
        guard error == nil else {
            print("Error discovering services: error")
            return
        }
        print("Message sent")
    }

    func peripheral(_ peripheral: CBPeripheral, didWriteValueFor descriptor: CBDescriptor, error: Error?) {
        guard error == nil else {
            print("Error discovering services: error")
            return
        }
        print("Succeeded!")
    }

    //Table View Functions
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return self.peripherals.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        //Connect to device where the peripheral is connected
        let cell = tableView.dequeueReusableCell(withIdentifier: "BLEDeviceInfoCell") as! PeripheralTableViewCell
        let peripheral = self.peripherals[indexPath.row]
        let RSSI = self.RSSIs[indexPath.row]

        if peripheral.name == nil {
            cell.peripheralLabel.text = "nil"
        } else {
            cell.peripheralLabel.text = peripheral.name
        }
        cell.rssiLabel.text = "RSSI: \(RSSI)"

        return cell
    }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        selectedDevice = peripherals[indexPath.row]
        connectToDevice()
    }

    /*
     Invoked when the central manager’s state is updated.
     This is where we kick off the scan if Bluetooth is turned on.
     */
    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        if central.state == CBManagerState.poweredOn {
            // We will just handle it the easy way here: if Bluetooth is on, proceed...start scan!
            print("Bluetooth Enabled")
            startScan()

        } else {
            //If Bluetooth is off, display a UI alert message saying "Bluetooth is not enable" and "Make sure that your bluetooth is turned on"
            print("Bluetooth Disabled- Make sure your Bluetooth is turned on")

            let alertVC = UIAlertController(title: "Bluetooth is not enabled", message: "Make sure that your bluetooth is turned on", preferredStyle: UIAlertControllerStyle.alert)
            let action = UIAlertAction(title: "ok", style: UIAlertActionStyle.default, handler: { (action: UIAlertAction) -> Void in
                self.dismiss(animated: true, completion: nil)
            })
            alertVC.addAction(action)
            self.present(alertVC, animated: true, completion: nil)
        }
    }
}
