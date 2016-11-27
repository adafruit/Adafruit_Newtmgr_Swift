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
    private static let kShowAlertOnBootError = true
    private static let kShowAlertOnListError = true

    // UI
    @IBOutlet weak var baseTableView: UITableView!
    
    // Boot info
    fileprivate var mainImage: String?
    fileprivate var activeImage: String?
    fileprivate var testImage: String?
    fileprivate var imageVersions: [String]?
    
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
    
    // MARK: - Newt
    override func newtDidBecomeReady() {
        super.newtDidBecomeReady()

        // Refresh if view is visible
        if isViewLoaded && view.window != nil {
            refreshBootVersion()
            refreshImageList()
        }
    }
    
    // MARK: - Boot Info
    private func refreshBootVersion() {
        guard let peripheral = blePeripheral, peripheral.isNewtReady else {
            return
        }
        
        // Retrieve Boot info
        peripheral.newtSendRequest(with: .boot) { [weak self] (bootImages, error) in
            guard let context = self else {
                return
            }
            
            if error != nil {
                DLog("Error Boot: \(error!)")
                context.mainImage = "error retrieving info"
                context.activeImage = "error retrieving info"
                
                if ImagesViewController.kShowAlertOnBootError {
                    DispatchQueue.main.async {
                        showErrorAlert(from: context, title: "Error", message: "Error retrieving boot data")
                    }
                }
            }
            
            if let (mainImage, activeImage, testImage) = bootImages as? (String?, String?, String?) {
                context.mainImage = mainImage
                context.activeImage = activeImage
                context.testImage = testImage
            }
            
    
            DispatchQueue.main.async {
                context.updateUI()
            }
        }
    }
    
    fileprivate func boot(version: String) {
        let message = "Would you like to activate it and reset the device?"
        let alertController = UIAlertController(title: "Boot version \(version)", message: message, preferredStyle: .alert)
        let okAction = UIAlertAction(title: "Activate", style: .default, handler: { [unowned self] alertAction in
            
            self.sendBootRequest(version: version)
        })
        alertController.addAction(okAction)
        let cancelAction = UIAlertAction(title: "Cancel", style: .cancel, handler: nil)
        alertController.addAction(cancelAction)
        present(alertController, animated: true, completion: nil)
        
    }
    
    // MARK: - Image List
    private func refreshImageList() {
        guard let peripheral = blePeripheral, peripheral.isNewtReady else {
            return
        }
        
        // Retrieve list info
        peripheral.newtSendRequest(with: .list) { [weak self] (imageVersionStrings, error) in
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
                if let url = urlFrom(bundleFileName: firmwareFileName, subdirectory: ImagesViewController.kInternalFirmwareSubdirectory), let data = dataFrom(url: url) {
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
    
    private func urlFrom(bundleFileName: String, subdirectory: String) -> URL? {
        let name = bundleFileName as NSString
        let fileUrl = Bundle.main.url(forResource: name.deletingPathExtension, withExtension: name.pathExtension, subdirectory: subdirectory)
        
        return fileUrl
    }
    
    private func dataFrom(url: URL) -> Data? {
        // Read data
        var data: Data?
        do {
            data = try Data(contentsOf: url)
            
        } catch {
            DLog("Error reading file: \(error)")
        }
        
        return data
    }
    
    
    fileprivate func uploadImage(bundleFileName: String) {
        guard let fileUrl = urlFrom(bundleFileName: bundleFileName, subdirectory: ImagesViewController.kInternalFirmwareSubdirectory) else {
            DLog("Error reading file path")
            return
        }
        
        uploadImage(url: fileUrl)
    }
    
    fileprivate func uploadImage(url: URL) {
        guard let imageData = dataFrom(url: url) else {
            showErrorAlert(from: self, title: "Error", message: "Error reading image file")
            return
        }
        
        let imageName = url.lastPathComponent
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
    
    // MARK: - Requests

    private func sendUploadRequest(imageData: Data) {
        guard let peripheral = blePeripheral, peripheral.isNewtReady else {
            return
        }
        
        isUploadCancelled = false
        
        // Send upload request
        peripheral.newtSendRequest(with: .upload(imageData: imageData), progress: { [weak self] (progress) -> Bool in
            
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
                        
                        context.sendBootRequest(imageData: imageData)
                    })
                    alertController.addAction(okAction)
                    let cancelAction = UIAlertAction(title: "Cancel", style: .cancel, handler: nil)
                    alertController.addAction(cancelAction)
                    context.present(alertController, animated: true, completion: nil)
                    
                    // Refresh Image List
                    context.refreshBootVersion()
                    context.refreshImageList()
                }
            }
        }
    }
    
    private func sendBootRequest(imageData: Data) {
        guard let peripheral = blePeripheral, peripheral.isNewtReady else {
            return
        }
        
        peripheral.newtSendRequest(with: .bootImage(data: imageData)) { [weak self]  (_, error) in
            guard let context = self else {
                return
            }
            
            guard error == nil else {
                DLog("boot image error: \(error!)")
                
                BlePeripheral.newtShowErrorAlert(from: context, title: "Boot image failed", error: error!)
                return
            }
            
            // Success. Reset device
            DLog("Boot image successful")
            context.sendResetRequest()
        }
    }

    
    private func sendBootRequest(version: String) {
        guard let peripheral = blePeripheral, peripheral.isNewtReady else {
            return
        }
        
        peripheral.newtSendRequest(with: .bootVersion(version: version)) { [weak self]  (_, error) in
            guard let context = self else {
                return
            }
            
            guard error == nil else {
                DLog("boot version error: \(error!)")
                
                BlePeripheral.newtShowErrorAlert(from: context, title: "Boot version failed", error: error!)
                return
            }
            
            // Success. Reset device
            DLog("Boot version successful")
            context.sendResetRequest()
        }
    }
    
    
    private func sendResetRequest() {
        guard let peripheral = blePeripheral, peripheral.isNewtReady else {
            return
        }
        
        peripheral.newtSendRequest(with: .reset) { [weak self]  (_, error) in
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
    
    // MARK: Custom images
    fileprivate func importImage(sourceView: UIView) {
        let importMenu = UIDocumentMenuViewController(documentTypes: ["public.data", "public.content"], in: .import)
        importMenu.delegate = self
        importMenu.popoverPresentationController?.sourceView = sourceView
        present(importMenu, animated: true, completion: nil)
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
            count = 3
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
            if indexPath.row == 0 {
                text = "Main Image"
                detailText = mainImage != nil ? mainImage!:"empty"
            }
            else if indexPath.row == 1 {
                text = "Active Image"
                detailText = activeImage != nil ? activeImage!:"empty"
            }
            else {
                text = "Test Image"
                detailText = testImage != nil ? testImage!:"empty"
            }
            cell.accessoryType = .none
            
        case 1:
            text = "Bank \(indexPath.row)"
            let imageVersion = imageVersions![indexPath.row]
            detailText = imageVersion
            cell.accessoryType = .disclosureIndicator
            
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
            let imageVersion = imageVersions![indexPath.row]
            boot(version: imageVersion)
            
        case 2:
            if let imageInfo: ImageInfo? = indexPath.row < (imagesInternal?.count ?? 0) ? imagesInternal![indexPath.row]:nil {
                uploadImage(bundleFileName: imageInfo!.name)
            }
            else {
                let currentCell = self.tableView(tableView, cellForRowAt: indexPath)
                importImage(sourceView: currentCell.contentView)
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

// MARK: - UIDocumentMenuDelegate
extension ImagesViewController: UIDocumentMenuDelegate {
    
    func documentMenu(_ documentMenu: UIDocumentMenuViewController, didPickDocumentPicker documentPicker: UIDocumentPickerViewController) {
        documentPicker.delegate = self
        present(documentPicker, animated: true, completion: nil)
    }
}

// MARK: - UIDocumentPickerDelegate
extension ImagesViewController: UIDocumentPickerDelegate {
    func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentAt url: URL) {
        DLog("picked: \(url.absoluteString)")
        uploadImage(url: url)
    }

}
