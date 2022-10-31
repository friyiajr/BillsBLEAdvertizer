// SOURCE: https://medium.com/@kakshata12/creating-ios-application-as-bluetooth-peripheral-669404230232


//
//  ViewController.swift
//  BLEAdvertiser
//
//  Created by Daniel Friyia on 2022-10-09.
//

import UIKit
import CoreBluetooth

struct Pokemon {
    let operation: UInt64
    let index: UInt64
    
    var pokemonName: String {
        switch (self.index) {
        case 151:
            return "MEW"
        case 150:
            return "MEWTWO"
        case 149:
            return "DRAGONITE"
        case 145:
            return "ZAPDOS"
        case 143:
            return "SNORLAX"
        case 130:
            return "GYRADOS"
        default:
            return ""
        }
    }
}

class ViewController: UIViewController, CBPeripheralManagerDelegate, CBPeripheralDelegate, UITableViewDataSource, UITableViewDelegate {

    @IBOutlet weak var waitingForTrainerStackView: UIStackView!
    @IBOutlet weak var pokemonTable: UITableView!
    
    private let serviceUUID = UUID(uuidString: "D78A31FE-E14F-4F6A-A107-790AB0D58F27")
    private let pokemonPCCharacteristic = UUID(uuidString: "EBE6204C-C1EE-4D09-97B8-F77F360F7372")
    
    private var peripheralManager : CBPeripheralManager!
    private var pcCharacteristic: CBMutableCharacteristic!
    private var service: CBUUID!
    
    private var pokemon: [Pokemon]!
    private var visiblePokemon: [Pokemon]!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        pokemon = [Pokemon]()
        visiblePokemon = [Pokemon]()
        peripheralManager = CBPeripheralManager(delegate: self, queue: nil)
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return visiblePokemon.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let tableViewCell = UITableViewCell(style: .subtitle, reuseIdentifier: "heartSession")
        let cellData = visiblePokemon[indexPath.row]
        tableViewCell.textLabel?.text = cellData.pokemonName
        tableViewCell.textLabel?.font = UIFont.systemFont(ofSize: 25)
        tableViewCell.detailTextLabel?.text = "NO. \(cellData.index)"
        tableViewCell.detailTextLabel?.textColor = UIColor.gray
        tableViewCell.detailTextLabel?.font = UIFont.systemFont(ofSize: 20)
        return tableViewCell
    }
    
    func tableView(tableView: UITableView, didSelectRowAtIndexPath indexPath: NSIndexPath) {
        // cell selected code here
    }
    
    func peripheralManagerDidUpdateState(_ peripheral: CBPeripheralManager) {
        switch peripheral.state {
        case .unknown:
            print("Bluetooth Device is UNKNOWN")
        case .unsupported:
            print("Bluetooth Device is UNSUPPORTED")
        case .unauthorized:
            print("Bluetooth Device is UNAUTHORIZED")
        case .resetting:
            print("Bluetooth Device is RESETTING")
        case .poweredOff:
            print("Bluetooth Device is POWERED OFF")
        case .poweredOn:
            print("Bluetooth Device is POWERED ON")
            addServices()
        @unknown default:
            print("Unknown State")
        }
    }
    
    func startAdvertising() {
        peripheralManager.startAdvertising(
            [
                CBAdvertisementDataLocalNameKey : "Bill's PC",
                CBAdvertisementDataServiceUUIDsKey : [service]
            ]
        )
    }
    
    func addServices() {
        if let pokemonPCCharacteristic = pokemonPCCharacteristic, let serviceUUID = serviceUUID {
            pcCharacteristic = CBMutableCharacteristic(
                type: CBUUID(nsuuid: pokemonPCCharacteristic),
                properties: [.notify, .write, .read],
                value: nil,
                permissions: [.readable, .writeable]
            )
            
            service = CBUUID(nsuuid: serviceUUID)
            let myService = CBMutableService(type: service, primary: true)
            myService.characteristics = [pcCharacteristic]
            peripheralManager.add(myService)
            startAdvertising()
        }
    }
    
    func extractBit(target: UInt64, startBit: UInt64, endBit: UInt64) -> UInt64 {
        let mask: UInt64 = ((1 << endBit) - 1) << startBit;
        return target & mask
    }

    
    func deserializeData(_ data: String) {
        self.pokemon = []
        let allData: UInt64 = UInt64(data)!
        
        let kPokeIndexLength = 8
        let kOpcodeLength = 2
        
        var i = 0
        
        while i < 60 {
            let isolatedXbits = extractBit(
                target: allData,
                startBit: UInt64(i),
                endBit: UInt64(kPokeIndexLength)) >> i
            
            let opCode = extractBit(
                target: allData,
                startBit: UInt64(i + kPokeIndexLength),
                endBit: UInt64(kOpcodeLength)) >> (i + kPokeIndexLength)
            
            if(isolatedXbits > 151) {
                return
            }
            
            pokemon.append(Pokemon(operation: opCode, index: isolatedXbits))
            i += 10
        }
    }
    
    func peripheralManager(_ peripheral: CBPeripheralManager, central: CBCentral, didSubscribeTo characteristic: CBCharacteristic) {
        waitingForTrainerStackView.isHidden = true
        pokemonTable.isHidden = false
    }
    

    func peripheralManager(_ peripheral: CBPeripheralManager, didReceiveWrite requests: [CBATTRequest]) {
        
        if let value = requests.first?.value {
            let clientData = String(data: value, encoding: String.Encoding.ascii)
            deserializeData(clientData!)
            
            if(pokemon.count < 6) {
                self.peripheralManager.respond(
                    to: requests[0],
                    withResult: .requestNotSupported
                )
                
                // I'm sure there must be a better way to do this then adding delay
                // but I wasn't able to find a good solution through Google
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    self.peripheralManager.updateValue(
                        clientData!.data(using: .utf8)!,
                        for: self.pcCharacteristic,
                        onSubscribedCentrals: nil
                    )
                    self.pokemonTable.reloadData()
                }
                return
            }
            
            self.peripheralManager.respond(to: requests[0], withResult: .success)
            
            // I'm sure there must be a better way to do this then adding delay
            // but I wasn't able to find a good solution through Google
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                self.peripheralManager.updateValue(
                    clientData!.data(using: .utf8)!,
                    for: self.pcCharacteristic,
                    onSubscribedCentrals: nil
                )
                
                let newVisiblePokemon = self.pokemon.filter { pokemon in
                    return pokemon.operation == 2
                }
                
                self.visiblePokemon = newVisiblePokemon
                
                self.pokemonTable.reloadData()
            }
        }
    }
}

