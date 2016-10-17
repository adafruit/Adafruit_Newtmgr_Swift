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
    fileprivate var selectedBankRow: Int?
    
    // Image Upload
    fileprivate struct ImageInfo {
        var name: String
        var version: String
        var hash: Data
    }
    fileprivate var imagesInternal: [ImageInfo]?
    private var uploadProgressViewController: UploadProgressViewController?

    
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
                
                if ImagesViewController.kShowAlertOnBootError {
                    DispatchQueue.main.async {
                        let message = "Error retrieving boot data"
                        let alertController = UIAlertController(title: "Error", message: message, preferredStyle: .alert)
                        let okAction = UIAlertAction(title: "Ok", style: .default, handler: nil)
                        alertController.addAction(okAction)
                        context.present(alertController, animated: true, completion: nil)
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
                        let message = "Error retrieving image list"
                        let alertController = UIAlertController(title: "Error", message: message, preferredStyle: .alert)
                        let okAction = UIAlertAction(title: "Ok", style: .default, handler: nil)
                        alertController.addAction(okAction)
                        context.present(alertController, animated: true, completion: nil)
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
            let alertController = UIAlertController(title: "Error", message: "Error reading image file", preferredStyle: .alert)
            let okAction = UIAlertAction(title: "Ok", style: .default, handler: { alertAction in
            })
            alertController.addAction(okAction)
            present(alertController, animated: true, completion: nil)
            return
        }
        
        
        let message = "Would you like to upload \(imageName)?"
        let alertController = UIAlertController(title: "Upload Image", message: message, preferredStyle: .alert)
        let okAction = UIAlertAction(title: "Ok", style: .default) {[unowned self] _ in
            
            // Create upload dialog
            self.uploadProgressViewController = (self.storyboard?.instantiateViewController(withIdentifier: "UploadProgressViewController") as! UploadProgressViewController)
            self.uploadProgressViewController?.delegate = self
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
        // Send upload request
        blePeripheral?.newtRequest(with: .upload(imageData: imageData), progress: { (progress) in
            DispatchQueue.main.async { [weak self]  in
                self?.uploadProgressViewController?.set(progress: progress)
            }
            
        }) { (result, error) in
            
            DispatchQueue.main.async { [weak self]  in
                self?.uploadProgressViewController?.dismiss(animated: true) { [weak self] in

                    guard let context = self else {
                        return
                    }
                    
                    context.uploadProgressViewController = nil
                    
                    guard error == nil else {
                        DLog("upload error: \(error!)")
                        
                        let message: String?
                        if let newtError = error as? BlePeripheral.NewtError {
                            message = newtError.description
                        }
                        else {
                            message = error!.localizedDescription
                        }
                        
                        let alertController = UIAlertController(title: "Upload image failed", message: message, preferredStyle: .alert)
                        let okAction = UIAlertAction(title: "Ok", style: .default, handler: { alertAction in
                        })
                        alertController.addAction(okAction)
                        context.present(alertController, animated: true, completion: nil)
                        return
                    }
                    
                    // Success
                    DLog("Upload finished successfully")
                    
                    let message = "Image has been succesfully uploaded"
                    let alertController = UIAlertController(title: "Uploap Finishsed", message: message, preferredStyle: .alert)
                    let okAction = UIAlertAction(title: "Ok", style: .default, handler: { alertAction in
                    })
                    alertController.addAction(okAction)
                    context.present(alertController, animated: true, completion: nil)
                    
                    // Refresh Image LIst
                    context.refreshImageList()
                }
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
            selectedBankRow = indexPath.row
            performSegue(withIdentifier: "bankSegue", sender: self)
        
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
        
    }
}
