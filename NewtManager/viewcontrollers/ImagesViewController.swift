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
    private static let kShowAlertOnListError = true

    // UI
    @IBOutlet weak var baseTableView: UITableView!
    private let refreshControl = UIRefreshControl()
 
    // Boot info
    fileprivate var mainImage: String?
    fileprivate var activeImage: String?
    fileprivate var testImage: String?
    fileprivate var images: [NewtImage]?
    fileprivate var isImageInfoHidden = [Bool]()
    
    // Slots
    
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

        // Table View self-sizing
        baseTableView.rowHeight = UITableViewAutomaticDimension
        baseTableView.estimatedRowHeight = 44

        // Setup table refresh
        refreshControl.addTarget(self, action: #selector(onTableRefresh(_:)), for: UIControlEvents.valueChanged)
        baseTableView.addSubview(refreshControl)
        baseTableView.sendSubview(toBack: refreshControl)

        // Refresh images
        refreshImageFiles()
    }
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        refreshImageList()
    }
    
    // MARK: - Newt
    override func newtDidBecomeReady() {
        super.newtDidBecomeReady()

        // Refresh if view is visible
        if isViewLoaded && view.window != nil {
            refreshImageList()
        }
    }
    
    /*
    fileprivate func showImageOptions(image: NewtImage) {
        let message = "Would you like to test it and reset the device?"
        let alertController = UIAlertController(title: "Boot version \(image.version)", message: message, preferredStyle: .alert)
        let testAction = UIAlertAction(title: "Only Test", style: .default, handler: { [unowned self] alertAction in
            self.sendImageTestRequest(hash: image.hash, resetOnSuccess: false)
            //self.sendBootRequest(version: version)
        })
        alertController.addAction(testAction)
        let testAndRebootAction = UIAlertAction(title: "Test and Reset", style: .default, handler: { [unowned self] alertAction in
            self.sendImageTestRequest(hash: image.hash, resetOnSuccess: true)
        })
        alertController.addAction(testAndRebootAction)
        let cancelAction = UIAlertAction(title: "Cancel", style: .cancel, handler: nil)
        alertController.addAction(cancelAction)
        present(alertController, animated: true, completion: nil)
    }
 */
    
    // MARK: - Image List
    private func refreshImageList() {
        guard let peripheral = blePeripheral, peripheral.isNewtReady else {
            return
        }
        
        // Retrieve list info
        peripheral.newtSendRequest(with: .imageList) { [weak self] (newtImages, error) in
            guard let context = self else {
                return
            }
            
            if error != nil {
                DLog("Error ListImages: \(error!)")
                context.images = nil

                if ImagesViewController.kShowAlertOnListError {
                    DispatchQueue.main.async {
                        showErrorAlert(from: context, title: "Error", message: "Error retrieving image list")
                    }
                }
            }

            if let newtImages = newtImages as? [NewtImage] {
                context.setNewtImages(newtImages)
            }

            DispatchQueue.main.async {
                context.updateUI()
            }
        }
        
    }
    
    private func setNewtImages(_ newtImages: [NewtImage]) {
        DLog("images: \(newtImages.map({"\($0.slot)-\($0.version)"}).joined(separator: ", ") )")
        let sortedImages = newtImages.sorted(by: {$0.slot < $1.slot})
        images = sortedImages
        isImageInfoHidden = [Bool](repeating: true, count: newtImages.count)
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

    fileprivate func sendUploadRequest(imageData: Data) {
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

                    /*
                    let message = "Image has been succesfully uploaded.\nWould you like to activate it and reset the device?"
                    let alertController = UIAlertController(title: "Upload successful", message: message, preferredStyle: .alert)
                    let okAction = UIAlertAction(title: "Activate", style: .default, handler: { [unowned context] alertAction in
                        DLog("Error: Implement me")
                        
                        //context.sendBootRequest(imageData: imageData)
                    })
                    alertController.addAction(okAction)
                    let cancelAction = UIAlertAction(title: "Cancel", style: .cancel, handler: nil)
                    alertController.addAction(cancelAction)
                    context.present(alertController, animated: true, completion: nil)
                    */

                    // Refresh Image List
                    context.refreshImageList()
                }
            }
        }
    }
    
    fileprivate func sendImageConfirmRequest(hash: Data?, isTest: Bool,  resetOnSuccess: Bool) {
        guard let peripheral = blePeripheral, peripheral.isNewtReady else {
            return
        }
        
        guard !isTest || (isTest && hash != nil) else {
            return
        }
        
        let command: BlePeripheral.NmgrCommand = isTest ? .imageTest(hash: hash!): .imageConfirm(hash: hash)
        
        peripheral.newtSendRequest(with: command) { [weak self]  (newtImages, error) in
            guard let context = self else {
                return
            }
            
            guard error == nil else {
                DLog("Set test image error: \(error!)")
                
                DispatchQueue.main.async {
                    BlePeripheral.newtShowErrorAlert(from: context, title: "Set test image failed", error: error!)
                }
                return
            }

            // Success. Reset device
            DLog("Set \(isTest ? "test":"confirm") image: successful")
            
            if let newtImages = newtImages as? [NewtImage] {
                context.setNewtImages(newtImages)
            }
            
            DispatchQueue.main.async {
                context.updateUI()
            }

            if resetOnSuccess {
                context.sendResetRequest()
            }
        }
    }
    
    fileprivate func sendResetRequest() {
        guard let peripheral = blePeripheral, peripheral.isNewtReady else {
            return
        }
        
        peripheral.newtSendRequest(with: .reset) { [weak self]  (_, error) in
            guard let context = self else {
                return
            }
            
            guard error == nil else {
                DLog("reset error: \(error!)")

                DispatchQueue.main.async {
                    BlePeripheral.newtShowErrorAlert(from: context, title: "Reset device failed", error: error!)
                }
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
    
    func onTableRefresh(_ sender: AnyObject) {
        refreshImageList()
        refreshControl.endRefreshing()
    }
}

// MARK: - UITableViewDataSource
extension ImagesViewController: UITableViewDataSource {
    enum TableSections: Int {
        case imageSlots = 0
        case imageUpdates = 1
        
        var name: String {
            switch self {
            case .imageSlots: return "Image Slots"
            case .imageUpdates: return "Image Uploads"
            }
        }
    }
    
    func numberOfSections(in tableView: UITableView) -> Int {
        return TableSections.imageUpdates.rawValue+1 // 3
    }
    
    func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        
        guard let tableSection = TableSections(rawValue: section) else {return nil}

        return tableSection.name
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        
        guard let tableSection = TableSections(rawValue: section) else {return 0}

        var count: Int
        switch tableSection {
        case .imageSlots:
            count = images?.count ?? 0
        case .imageUpdates:
            count = (imagesInternal?.count ?? 0) + 1        // +1 "Upload an Image" button
        }
        return count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        
        let tableSection = TableSections(rawValue: indexPath.section) ?? .imageUpdates
        
        var cell: UITableViewCell?
        switch tableSection {
            
        case .imageSlots:
            let reuseIdentifier = "ImageSlotCell"
            cell = tableView.dequeueReusableCell(withIdentifier: reuseIdentifier)
            if cell == nil {
                cell = UITableViewCell(style: .value1, reuseIdentifier: reuseIdentifier)
            }
            
            // Note: this is not done on willDisplay to avoid self-sizing problems
            if let image = images?[indexPath.row] {
                let slotCell = cell as! ImageSlotTableViewCell
                slotCell.set(id: indexPath.row, image: image, isInfoHidden: isImageInfoHidden[indexPath.row])
                slotCell.delegate = self
                slotCell.accessoryType = .none
                slotCell.selectionStyle = .default
            }

            
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
        
        guard let tableSection = TableSections(rawValue: indexPath.section) else {return}

        switch tableSection {
            
        case .imageSlots:
            break
            
        case .imageUpdates:
            let imageInfo: ImageInfo? = indexPath.row < (imagesInternal?.count ?? 0) ? imagesInternal![indexPath.row]:nil
            cell.accessoryType = .disclosureIndicator
            cell.textLabel!.text = imageInfo != nil ? imageInfo!.name : "Upload an image"
            cell.detailTextLabel!.text = imageInfo != nil ? imageInfo!.version : nil
            cell.selectionStyle = .default
        }
        
    }
}

// MARK: - UITableViewDelegate
extension ImagesViewController: UITableViewDelegate {
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        defer {
            tableView.deselectRow(at: indexPath, animated: true)
        }
        
        guard let tableSection = TableSections(rawValue: indexPath.section) else {return}
        
        switch tableSection {
        case .imageSlots:
            let slotCell = tableView.cellForRow(at: indexPath) as! ImageSlotTableViewCell
            slotCell.onClickInfo(self)
            
        case .imageUpdates:
            if let imageInfo: ImageInfo? = indexPath.row < (imagesInternal?.count ?? 0) ? imagesInternal![indexPath.row]:nil {
                uploadImage(bundleFileName: imageInfo!.name)
            }
            else {
                let currentCell = self.tableView(tableView, cellForRowAt: indexPath)
                importImage(sourceView: currentCell.contentView)
            }
        }
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

// MARK: - ImageSlotTableViewCellDelegate
extension ImagesViewController: ImageSlotTableViewCellDelegate {
    func onImageSlotCellHeightChanged(index: Int, isInfoHidden: Bool) {
        isImageInfoHidden[index] = isInfoHidden

        // Animate table changes
        baseTableView.beginUpdates()
        baseTableView.endUpdates()
    }
    
    func onClickImageTest(index: Int) {
        guard let image = images?[index] else { return }
        sendImageConfirmRequest(hash: image.hash, isTest: true, resetOnSuccess: false)
    }
    
    func onClickImageConfirm(index: Int) {
        guard let image = images?[index] else { return }
        sendImageConfirmRequest(hash: index == 0 ? nil:image.hash, isTest: false, resetOnSuccess: false)
    }
    
    func onClickImageReset(index: Int) {
        sendResetRequest()
    }
}
