//
//  ImagesViewController.swift
//  NewtManager
//
//  Created by Antonio García on 16/10/2016.
//  Copyright © 2016 Adafruit. All rights reserved.
//

import UIKit

class ImagesViewController: NewtViewController {

    // UI
    @IBOutlet weak var baseTableView: UITableView!
    
    // Data
    fileprivate var imageVersions: [String]?
    fileprivate var bootBank: Int?
    fileprivate var selectedBankRow: Int?
    
    override func viewDidLoad() {
        super.viewDidLoad()

    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        if imageVersions == nil {
            refreshImageVersions()
        }
    }
    
    // MARK: - Navigation
    override func shouldPerformSegue(withIdentifier identifier: String, sender: Any?) -> Bool {
        return selectedBankRow != nil && imageVersions != nil && selectedBankRow! < (imageVersions?.count ?? 0)
    }
    
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if let viewController = segue.destination as? ImageBankViewController {
            viewController.blePeripheral = blePeripheral
            viewController.bankId = "\(selectedBankRow!)"
            viewController.currentImageVersion = selectedBankRow! < (imageVersions?.count ?? 0) ? imageVersions![selectedBankRow!]:nil
        }
    }

    // MARK: - Newt
    override func newtBecomeReady() {
        // Refresh if no data was previously loaded and view is visible
        if imageVersions == nil && isViewLoaded && view.window != nil {
            refreshImageVersions()
        }
    }
    
    private func refreshImageVersions() {
        guard let peripheral = blePeripheral, peripheral.isNewtManagerReady else {
            return
        }
        
        peripheral.newtRequest(with: .list) { [weak self] (imageVersionStrings, error) in
        //peripheral.newtListImages() { [weak self] (imageVersionStrings, error) in
            guard let context = self else {
                return
            }
            
            if error != nil {
                DLog("Error ListImages: \(error!)")
                context.imageVersions = nil
                
                DispatchQueue.main.async {
                    let message = "Error retrieving image list"
                    let alertController = UIAlertController(title: "Error", message: message, preferredStyle: .alert)
                    let okAction = UIAlertAction(title: "Ok", style: .default, handler: nil)
                    alertController.addAction(okAction)
                    context.present(alertController, animated: true, completion: nil)
                }
            }
            
            if let imageVersionStrings = imageVersionStrings as? [String] {
                DLog("ListImages: \(imageVersionStrings.joined(separator: ", "))")
                context.imageVersions = imageVersionStrings
            }
            
            DispatchQueue.main.async {
                context.updateUI()
            }
        }
        
    }
    
    // MARK: - UI
    private func updateUI() {
        // Reload table
        baseTableView.reloadData()
    }
}

// MARK: - UITableViewDataSource
extension ImagesViewController: UITableViewDataSource {
    func numberOfSections(in tableView: UITableView) -> Int {
        return 2
    }
    
    func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        
        var title: String?
        switch section {
        case 0:
            title = "Boot"
        case 1:
            title = "Image Banks"
        default:
            break
        }
        
        return title
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        
        var count: Int
        switch section {
        case 0:
            count = 1
        case 1:
            count = 2 // imageVersions?.count ?? 0
        default:
            count = 0
        }
        return count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        
        var cell: UITableViewCell?
        switch indexPath.section {
        case 0:
            let reuseIdentifier = "BootCell"
            cell = tableView.dequeueReusableCell(withIdentifier: reuseIdentifier)
            if cell == nil {
                cell = UITableViewCell(style: .value1, reuseIdentifier: reuseIdentifier)
            }
            
        default:
            let reuseIdentifier = "ImageBanksCell"
            cell = tableView.dequeueReusableCell(withIdentifier: reuseIdentifier)
            if cell == nil {
                cell = UITableViewCell(style: .value1, reuseIdentifier: reuseIdentifier)
            }
        }
        
        return cell!
    }
    
    func tableView(_ tableView: UITableView, willDisplay cell: UITableViewCell, forRowAt indexPath: IndexPath) {
        
        var text: String?
        var detailText: String?
        switch indexPath.section {
        case 0:
            text = "Boot Image"
            detailText = bootBank != nil ? "Bank \(bootBank)":nil
            cell.accessoryType = bootBank != nil ? .disclosureIndicator:.none
        case 1:
            text = "Bank \(indexPath.row)"
            let imageVersion: String? = indexPath.row < (imageVersions?.count ?? 0) ? imageVersions![indexPath.row] : "empty"
            detailText = imageVersion
            cell.accessoryType = .disclosureIndicator
        default:
            break
        }
        
        cell.textLabel!.text = text
        cell.detailTextLabel!.text = detailText
    }
}

// MARK: - UITableViewDelegate
extension ImagesViewController: UITableViewDelegate {
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        
        switch indexPath.section {
        case 0:
            break
        
        case 1:
            selectedBankRow = indexPath.row
            performSegue(withIdentifier: "bankSegue", sender: self)
            
        default:
            break
        }
        
        tableView.deselectRow(at: indexPath, animated: true)
    }
}
