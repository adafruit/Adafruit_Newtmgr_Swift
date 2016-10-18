//
//  ImagesViewController.swift
//  NewtManager
//
//  Created by Antonio García on 16/10/2016.
//  Copyright © 2016 Adafruit. All rights reserved.
//

import UIKit

class ImagesViewController: NewtViewController {
    
    // Config
    private static let kInternalFirmwareSubdirectory = "/firmware"
    private static let kShowAlertOnBootError = false
    private static let kShowAlertOnListError = true

    // UI
    @IBOutlet weak var baseTableView: UITableView!
    
    // Boot info
    fileprivate var bootImage: String?
    fileprivate var imageVersions: [String]?
//    fileprivate var selectedBankRow: Int?
    
    // Image Upload
    fileprivate struct ImageInfo {
        var name: String
        var version: String
        var hash: Data
    }
    fileprivate var imagesInternal: [ImageInfo]?
    private var uploadProgressViewController: UploadProgressViewController?
    fileprivate var isUploadCancelled = false
    
    override func viewDidLoad() {
        super.viewDidLoad()

        refreshImageFiles()

    }
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        refreshBootVersion()
        refreshImageList()
    }
    
    // MARK: - Navigation
    /*
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
 */
    
    // MARK: - Newt
    override func newtBecomeReady() {
        super.newtBecomeReady()

        // Refresh if view is visible
        if isViewLoaded && view.window != nil {
            refreshBootVersion()
            refreshImageList()
        }
    }
    
    
    // MARK: - Boot Info
    private func refreshBootVersion() {
        guard let peripheral = blePeripheral, peripheral.isNewtManagerReady else {
            return
        }
        
        // Retrieve Boot info
        peripheral.newtRequest(with: .boot) { [weak self] (bootImageString, error) in
            guard let context = self else {
                return
            }
            
            if error != nil {
                DLog("Error Boot: \(error!)")
                context.bootImage = "error retrieving info"
                
                if ImagesViewController.kShowAlertOnBootError {
                    DispatchQueue.main.async {
                        showErrorAlert(from: context, title: "Error", message: "Error retrieving boot data")
                    }
                }
                
            }
            
            if let bootImageString = bootImageString as? String {
                DLog("BootImage: \(bootImageString)")
                context.bootImage = bootImageString
            }
            
            DispatchQueue.main.async {
                context.updateUI()
            }
        }
    }
    
    
    // MARK: - Image List
    private func refreshImageList() {
        guard let peripheral = blePeripheral, peripheral.isNewtManagerReady else {
            return
        }
        
        // Retrieve list info
        peripheral.newtRequest(with: .list) { [weak self] (imageVersionStrings, error) in
            guard let context = self else {
                return
            }
            
            if error != nil {
                DLog("Error ListImages: \(error!)")
                context.imageVersions = nil
                
                if ImagesViewController.kShowAlertOnListError {
                    DispatchQueue.main.async {
                        showErrorAlert(from: context, title: "Error", message: "Error retrieving image list")
                    }
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
    
    // MARK: - Boot
    
    fileprivate func boot(bankId: Int) {
        DLog("boot bank: \(bankId)")
    }
    
    // MARK: - Image Update
    private func refreshImageFiles() {
        
        // Image internal firmware files
        let docsPath = Bundle.main.resourcePath! + ImagesViewController.kInternalFirmwareSubdirectory
        let fileManager = FileManager.default
        
        do {
            let firmwareFileNames = try fileManager.contentsOfDirectory(atPath: docsPath)
            DLog("Firmware files: \(firmwareFileNames.joined(separator: ", "))")
            
            // Extract firmware file info
            imagesInternal = [ImageInfo]()
            for firmwareFileName in firmwareFileNames {
                if let data = dataFrom(fileName: firmwareFileName, subdirectory: ImagesViewController.kInternalFirmwareSubdirectory) {
                    let (version, hash) = BlePeripheral.readInfo(imageData: data)
                    DLog("Firmware: \(firmwareFileName): v\(version.major).\(version.minor).\(version.revision).\(version.buildNum) hash: \(hash)")
                    let imageInfo = ImageInfo(name: firmwareFileName, version: version.description, hash: hash)
                    imagesInternal!.append(imageInfo)
                }
            }
            
        } catch {
            imagesInternal = nil
            DLog("Error reading images: \(error)")
        }
        
        // Update UI
        updateUI()
    }
    
    private func urlFrom(fileName: String, subdirectory: String) -> URL? {
        let name = fileName as NSString
        let fileUrl = Bundle.main.url(forResource: name.deletingPathExtension, withExtension: name.pathExtension, subdirectory: subdirectory)
        
        return fileUrl
    }
    
    private func dataFrom(fileName: String, subdirectory: String) -> Data? {
        // Get Url
        guard let fileUrl = urlFrom(fileName: fileName, subdirectory: subdirectory) else {
            DLog("Error reading file path")
            return nil
        }
        
        // Read data
        var data: Data?
        do {
            data = try Data(contentsOf: fileUrl)
            
        } catch {
            DLog("Error reading file: \(error)")
        }
        
        return data
    }
    
    
    fileprivate func uploadImage(name imageName: String) {
        
        guard let imageData = dataFrom(fileName: imageName, subdirectory: ImagesViewController.kInternalFirmwareSubdirectory) else {
            showErrorAlert(from: self, title: "Error", message: "Error reading image file")
            return
        }
        
        let message = "Would you like to upload \(imageName)?"
        let alertController = UIAlertController(title: "Upload Image", message: message, preferredStyle: .alert)
        let okAction = UIAlertAction(title: "Ok", style: .default) {[unowned self] _ in
            
            // Create upload dialog
            self.uploadProgressViewController = (self.storyboard?.instantiateViewController(withIdentifier: "UploadProgressViewController") as! UploadProgressViewController)
            self.uploadProgressViewController!.delegate = self
            self.uploadProgressViewController!.imageName = imageName
            self.uploadProgressViewController!.imageSize = String(format: "%.0f KB", Double(imageData.count)/1024.0)
            self.present(self.uploadProgressViewController!, animated: true) { [unowned self] in
                self.sendUploadRequest(imageData: imageData)
            }
            
        }
        alertController.addAction(okAction)
        let cancelAction = UIAlertAction(title: "Cancel", style: .cancel, handler: nil)
        alertController.addAction(cancelAction)
        present(alertController, animated: true, completion: nil)
      
    }
    
    private func sendUploadRequest(imageData: Data) {
        guard let peripheral = blePeripheral, peripheral.isNewtManagerReady else {
            return
        }
        
        isUploadCancelled = false
        
        // Send upload request
        peripheral.newtRequest(with: .upload(imageData: imageData), progress: { [weak self] (progress) -> Bool in
            
            DispatchQueue.main.async {
                self?.uploadProgressViewController?.set(progress: progress)
            }
            return self?.isUploadCancelled ?? true
            
        }) { (result, error) in
            
            DispatchQueue.main.async { [weak self]  in
                self?.uploadProgressViewController?.dismiss(animated: true) { [weak self] in
                    guard let context = self else {
                        return
                    }
                    
                    context.uploadProgressViewController = nil
                    
                    guard error == nil else {
                        DLog("upload error: \(error!)")
                        
                        BlePeripheral.newtShowErrorAlert(from: context, title: "Upload image failed", error: error!)
                        return
                    }
                    
                    // Success. Ask if should activate
                    DLog("Upload successful")
                    
                    let message = "Image has been succesfully uploaded.\nWould you like to activate it and reset the device?"
                    let alertController = UIAlertController(title: "Upload successful", message: message, preferredStyle: .alert)
                    let okAction = UIAlertAction(title: "Activate", style: .default, handler: { [unowned context] alertAction in
                        
                        context.sendActivateRequest(imageData: imageData)
                    })
                    alertController.addAction(okAction)
                    let cancelAction = UIAlertAction(title: "Cancel", style: .cancel, handler: nil)
                    alertController.addAction(cancelAction)
                    context.present(alertController, animated: true, completion: nil)
                    
                    // Refresh Image LIst
                    context.refreshImageList()
                }
            }
        }
    }
    
    
    private func sendActivateRequest(imageData: Data) {
        guard let peripheral = blePeripheral, peripheral.isNewtManagerReady else {
            return
        }
        
        peripheral.newtRequest(with: .activate(imageData: imageData)) { [weak self]  (_, error) in
            guard let context = self else {
                return
            }
            
            guard error == nil else {
                DLog("activate error: \(error!)")
                
                BlePeripheral.newtShowErrorAlert(from: context, title: "Activate image failed", error: error!)
                return
            }
            
            // Success. Reset dvice
            DLog("Activate successful")
            context.sendResetRequest()
        }
    }

    
    private func sendResetRequest() {
        guard let peripheral = blePeripheral, peripheral.isNewtManagerReady else {
            return
        }
        
        peripheral.newtRequest(with: .reset) { [weak self]  (_, error) in
            guard let context = self else {
                return
            }
            
            guard error == nil else {
                DLog("reset error: \(error!)")
                
                BlePeripheral.newtShowErrorAlert(from: context, title: "Reset device failed", error: error!)
                return
            }
            
            // Success. Reset dvice
            DLog("Reset successful")
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
        return 3
    }
    
    func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        
        var title: String?
        switch section {
        case 0:
            title = "Boot"
        case 1:
            title = "Image Banks"
        case 2:
            title = "Image Updates"
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
            count = imageVersions?.count ?? 0
        case 2:
            count = (imagesInternal?.count ?? 0) + 1        // +1 "Upload an Image" button
            
        default:
            count = 0
        }
        return count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        
        var cell: UITableViewCell?
        switch indexPath.section {
            /*
        case 0:
            let reuseIdentifier = "BootCell"
            cell = tableView.dequeueReusableCell(withIdentifier: reuseIdentifier)
            if cell == nil {
                cell = UITableViewCell(style: .value1, reuseIdentifier: reuseIdentifier)
            }

        case 1:
            let reuseIdentifier = "ImageBanksCell"

            */
        default:
            let reuseIdentifier = "ImageCell"
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
            detailText = bootImage != nil ? bootImage:"no info"
            cell.accessoryType = .none
        case 1:
            text = "Bank \(indexPath.row)"
            let imageVersion: String? = imageVersions![indexPath.row] //indexPath.row < (imageVersions?.count ?? 0) ? imageVersions![indexPath.row] : "empty"
            detailText = imageVersion
            cell.accessoryType = indexPath.row != 0 ? .disclosureIndicator:.none
            
        case 2:
            let imageInfo: ImageInfo? = indexPath.row < (imagesInternal?.count ?? 0) ? imagesInternal![indexPath.row]:nil
            text = imageInfo != nil ? imageInfo!.name : "Upload an image"
            detailText = imageInfo != nil ? imageInfo!.version : nil
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
//            selectedBankRow = indexPath.row
//            performSegue(withIdentifier: "bankSegue", sender: self)
        
            boot(bankId: indexPath.row)
            
        case 2:
            if let imageInfo: ImageInfo? = indexPath.row < (imagesInternal?.count ?? 0) ? imagesInternal![indexPath.row]:nil {
                uploadImage(name: imageInfo!.name)
            }
            else {
                DLog("Show image picker")
            }
            
        default:
            break
        }
        
        tableView.deselectRow(at: indexPath, animated: true)
    }
}

// MARK: - UploadProgressViewControllerDelegate
extension ImagesViewController: UploadProgressViewControllerDelegate {
    func onUploadCancel() {
        DLog("Upload cancelled")
        isUploadCancelled = true
    }
}
