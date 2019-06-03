//
//  ViewController.swift
//  PranaTest
//
//  Created by Guru on 5/31/19.
//  Copyright © 2019 Luccas. All rights reserved.
//

import UIKit

class ViewController: UIViewController {

    @IBOutlet weak var tfDelayTime: UITextField!
    @IBOutlet weak var swStartImm: UISwitch!
    @IBOutlet weak var swStopImm: UISwitch!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        self.title = "Prana Connect Test"
        // Do any additional setup after loading the view.
    }


    @IBAction func onStart(_ sender: Any) {
        guard let delaystring = tfDelayTime.text, let delaySecs = Int(delaystring) else {
            let alert = UIAlertController(title: "Warning", message: "Please insert valid delay time", preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: "Ok", style: .cancel, handler: nil))
            self.present(alert, animated: true, completion: nil)
            return
        }
        
        PranaDeviceManager.shared.delaySeconds = delaySecs
        
        let storyboard = UIStoryboard(name: "Main", bundle: nil)
        let controller = storyboard.instantiateViewController(withIdentifier: "ConnectViewController") as! ConnectViewController
        
        controller.needStartImmediately = swStartImm.isOn
        controller.needStopImmediately = swStopImm.isOn
        
        self.navigationController?.pushViewController(controller, animated: true)
    }
    
}

