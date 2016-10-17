//
//  UploadProgressViewController.swift
//  NewtManager
//
//  Created by Antonio García on 17/10/2016.
//  Copyright © 2016 Adafruit. All rights reserved.
//

import UIKit

protocol UploadProgressViewControllerDelegate: class {
    func onUploadCancel()
}

class UploadProgressViewController: UIViewController {

    @IBOutlet weak var progressView: UIProgressView!
    @IBOutlet weak var progressLabel: UILabel!
    @IBOutlet weak var dialogView: UIView!
    
    weak var delegate: UploadProgressViewControllerDelegate?
    
    override func viewDidLoad() {
        super.viewDidLoad()

        // UI
        dialogView.layer.cornerRadius = 8
        dialogView.layer.masksToBounds = true
        
        // Initial state
        set(progress: 0)
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    func set(progress: Float) {
        progressView.progress = progress
        progressLabel.text = String(format: "%.1f%%", progress * 100.0)
    }

    /*
    // MARK: - Navigation

    // In a storyboard-based application, you will often want to do a little preparation before navigation
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        // Get the new view controller using segue.destinationViewController.
        // Pass the selected object to the new view controller.
    }
    */

    @IBAction func onClickCancel(_ sender: Any) {
        delegate?.onUploadCancel()
    }
}
