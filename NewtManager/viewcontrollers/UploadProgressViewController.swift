//
//  UploadProgressViewController.swift
//  NewtManager
//
//  Created by Antonio García on 17/10/2016.
//  Copyright © 2016 Adafruit. All rights reserved.
//

import UIKit

class UploadProgressViewController: UIViewController {

    @IBOutlet weak var progressView: UIProgressView!
    @IBOutlet weak var progressLabel: UILabel!
    
    
    override func viewDidLoad() {
        super.viewDidLoad()

        // Do any additional setup after loading the view.
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    func set(progress: Float) {
        progressView.progress = progress
        progressLabel.text = String.init(format: "%0.1f%%", progress / 100)
    }

    /*
    // MARK: - Navigation

    // In a storyboard-based application, you will often want to do a little preparation before navigation
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        // Get the new view controller using segue.destinationViewController.
        // Pass the selected object to the new view controller.
    }
    */

}
