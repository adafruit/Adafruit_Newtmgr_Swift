//
//  ImageBankViewController.swift
//  NewtManager
//
//  Created by Antonio García on 16/10/2016.
//  Copyright © 2016 Adafruit. All rights reserved.
//

import UIKit

class ImageBankViewController: NewtViewController {

    // Config
    private static let kInternalFirmwareSubdirectory = "/firmware"
    
    // UI
    @IBOutlet weak var baseTableView: UITableView!

    // Initial parameters
    var bankId: String!
    var currentImageVersion: String!

    // Data
    fileprivate struct ImageInfo {
        var name: String
        var version: String
        var hash: Data
    }
    
    fileprivate var images: [ImageInfo]?
    private var uploadProgressViewController: UploadProgressViewController?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        

        refreshImages()
        
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        self.title = "Bank \(bankId!)"
    }
    
    /*
    // MARK: - Navigation

    // In a storyboard-based application, you will often want to do a little preparation before navigation
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        // Get the new view controller using segue.destinationViewController.
        // Pass the selected object to the new view controller.
    }
    */

    /*
    override func newtBecomeReady() {
        // Refresh if no data was previously loaded and view is visible
        if images == nil && isViewLoaded && view.window != nil {
            refreshImages()
        }
    }*/
    
    private func refreshImages() {
        
        // Image internal firmware files
        let docsPath = Bundle.main.resourcePath! + ImageBankViewController.kInternalFirmwareSubdirectory
        let fileManager = FileManager.default
        
        do {
            let firmwareFileNames = try fileManager.contentsOfDirectory(atPath: docsPath)
            DLog("Firmware files: \(firmwareFileNames.joined(separator: ", "))")

            // Extract firmware file info
            images = [ImageInfo]()
            for firmwareFileName in firmwareFileNames {
                if let data = dataFrom(fileName: firmwareFileName, subdirectory: ImageBankViewController.kInternalFirmwareSubdirectory) {
                    let (version, hash) = BlePeripheral.readInfo(imageData: data)
                    DLog("Firmware: \(firmwareFileName): v\(version.major).\(version.minor).\(version.revision).\(version.buildNum) hash: \(hash)")
                    let imageInfo = ImageInfo(name: firmwareFileName, version: version.description, hash: hash)
                    images!.append(imageInfo)
                }
            }
            
        } catch {
            images = nil
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
    
    // MARK: - UI
    private func updateUI() {
        // Reload table
        baseTableView.reloadData()
    }
    
    // MARK: - Actions
    @IBAction func onClickLoadImage(_ sender: Any) {
        DLog("onClickLoadImage")
    }
    
    fileprivate func uploadImage(name imageName: String) {
        
        guard let imageData = dataFrom(fileName: imageName, subdirectory: ImageBankViewController.kInternalFirmwareSubdirectory) else {
            let alertController = UIAlertController(title: "Error", message: "Error reading image file", preferredStyle: .alert)
            let okAction = UIAlertAction(title: "Ok", style: .default, handler: { alertAction in
            })
            alertController.addAction(okAction)
            present(alertController, animated: true, completion: nil)
            return
        }
        
        // Create upload dialog
        uploadProgressViewController = (storyboard?.instantiateViewController(withIdentifier: "UploadProgressViewController") as! UploadProgressViewController)
        uploadProgressViewController?.delegate = self
        present(uploadProgressViewController!, animated: true) { [unowned self] in
            self.sendUploadRequest(imageData: imageData)
        }
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
                    self?.uploadProgressViewController = nil
                    
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
                        self?.present(alertController, animated: true, completion: nil)
                        return
                    }
                    
                    DLog("Upload finished successfully")
                    
                    let message = "Image has been succesfully uploaded"
                    let alertController = UIAlertController(title: "Uploap Finishsed", message: message, preferredStyle: .alert)
                    let okAction = UIAlertAction(title: "Ok", style: .default, handler: { alertAction in
                    })
                    alertController.addAction(okAction)
                    self?.present(alertController, animated: true, completion: nil)
                }
            }
        }
    }
}

// MARK: - UITableViewDataSource
extension ImageBankViewController: UITableViewDataSource {
    func numberOfSections(in tableView: UITableView) -> Int {
        return 2
    }
    
    func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        
        var title: String?
        switch section {
        case 0:
            title = ""
        case 1:
            title = "Available Images"
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
            count = images?.count ?? 0
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
        var isSelectable = true
        switch indexPath.section {
        case 0:
            text = "Current Image"
            detailText = currentImageVersion
            isSelectable = false
            cell.accessoryType = .none
        case 1:
            let image = images![indexPath.row]
            text = image.name
            detailText = image.version
            cell.accessoryType = .detailDisclosureButton
        default:
            break
        }
        
        cell.selectionStyle = isSelectable ? .gray:.none
        cell.textLabel!.text = text
        cell.detailTextLabel!.text = detailText
    }
}


// MARK: - UITableViewDelegate
extension ImageBankViewController: UITableViewDelegate {
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        
        switch indexPath.section {
        case 0:
            break
        case 1:
            let image = images![indexPath.row]
            uploadImage(name: image.name)
        default:
            break
        }
        
        tableView.deselectRow(at: indexPath, animated: true)
    }
}

extension ImageBankViewController: UploadProgressViewControllerDelegate {
    func onUploadCancel() {
        DLog("Upload cancelled")
        
    }
}
