//
//  ImageSlotTableViewCell.swift
//  MynewtManager
//
//  Created by Antonio García on 02/12/2016.
//  Copyright © 2016 Adafruit. All rights reserved.
//

import UIKit

protocol ImageSlotTableViewCellDelegate: class {
    func onImageSlotCellHeightChanged(index: Int, isInfoHidden: Bool, height: CGFloat)
    func onClickImageTest(index: Int)
    func onClickImageConfirm(index: Int)
    func onClickImageReset(index: Int)
}

class ImageSlotTableViewCell: UITableViewCell {
    // Config
    static let kDefaultImageCellHeiht: CGFloat = 70

    // UI
    @IBOutlet weak var slotIdLabel: UILabel!
    @IBOutlet weak var versionLabel: UILabel!
    @IBOutlet weak var statusLabel: UILabel!
    @IBOutlet weak var actionsStackView: UIStackView!
    @IBOutlet weak var infoStackView: UIStackView!
    @IBOutlet weak var hashView: UIView!
    @IBOutlet weak var hashValueLabel: UILabel!
    @IBOutlet weak var expandInfoButton: UIButton!
    @IBOutlet weak var expandedStackView: UIStackView!
    
    // Data
    private var cellIndex: Int = -1
    private var newtImage: NewtHandler.Image?
    private var isInfoHidden = true
    
    // Params
    weak var delegate: ImageSlotTableViewCellDelegate?
    
    enum Status {
        case unknown
        case bootable
        case notBootable
        case active
        case activeOnReset
        case testing
        case testOnReset
        
        var description: String {
            switch self {
            case .unknown: return "Unknown"
            case .bootable: return "Bootable"
            case .notBootable: return "Not Bootable"
            case .active: return "Active"
            case .activeOnReset: return "Active on reset (Revert)"
            case .testing: return "Testing"
            case .testOnReset: return "Test on reset"
            }
        }
    }
    
    enum ImageAction {
        case test
        case confirm
        case reset
        
        var description: String {
            switch self {
            case .test: return "Test"
            case .confirm: return "Confirm"
            case .reset: return "Reset"
            }
        }
    }
    
    override func awakeFromNib() {
        super.awakeFromNib()
        // Initialization code
        
        for subview in actionsStackView.arrangedSubviews {
            subview.layer.borderColor = tintColor.cgColor
            subview.layer.borderWidth = 1
            subview.layer.cornerRadius = 8
            subview.layer.masksToBounds = true
        }
        
        infoStackView.layoutMargins = UIEdgeInsets(top: 0, left: 20, bottom: 0, right: 0)
        infoStackView.isLayoutMarginsRelativeArrangement = true
        
        setInfoVisiblity(isHidden: true)
    }

    override func prepareForReuse() {
        newtImage = nil
        expandInfoButton.transform = .identity
        
        super.prepareForReuse()
    }
    
    override func setSelected(_ selected: Bool, animated: Bool) {
        super.setSelected(selected, animated: animated)

        // Configure the view for the selected state
    }
    
    func set(id: Int, image: NewtHandler.Image, isInfoHidden: Bool) {
        cellIndex = id
        self.newtImage = image
        slotIdLabel.text = id == 0 ? "Main Slot" : "Temporary Slot"
        versionLabel.text = "\(image.version)"
        statusLabel.text = status(image: image).description.uppercased()
        
        self.isInfoHidden = isInfoHidden
        /*
        infoStackView.isHidden = isInfoHidden
        hashView.isHidden = isInfoHidden
        expandedStackView.isHidden = isInfoHidden
*/
        
        // Actions
        let actions = availableActions(image: image)
        actionsStackView.isHidden = actions.count == 0
        for (i, actionView) in actionsStackView.arrangedSubviews.enumerated() {
            let actionButton = actionView as! UIButton
            
            let isVisible = i < actions.count
            actionButton.isHidden = !isVisible
            if isVisible {
                let action = actions[i]
                actionButton.setTitle(action.description, for: .normal)
            }
        }

        // Info
        for (i, infoView) in infoStackView.arrangedSubviews.enumerated() {
            var isEnabled: Bool
            switch i {
            case 0: isEnabled = image.isBootable
            case 1: isEnabled = image.isActive
            case 2: isEnabled = image.isPending
            case 3: isEnabled = image.isConfirmed
            default: isEnabled = false
            }
            
            let imageView = infoView.viewWithTag(10) as! UIImageView
            imageView.image = UIImage(named: isEnabled ? "ic_check_18pt":"ic_close_18pt")
        }
        
        // Hash
        hashValueLabel.text = hexDescription(data: image.hash)
    }
    
    
    private func status(image: NewtHandler.Image) -> Status {
        
        guard image.isBootable else { return .notBootable }
        
        if image.isConfirmed {
            return image.isActive ? .active : .activeOnReset
        }
        else if image.isActive {
            return .testing
        }
        else if image.isPending {
            return .testOnReset
        }
        else {
            return .bootable
        }
    }
    
    private func availableActions(image: NewtHandler.Image) -> [ImageAction] {
        var result = [ImageAction]()
        
        if image.isActive && !image.isConfirmed {
            result.append(.confirm)
        }
        else if !image.isConfirmed && !image.isPending {
            result.append(.test)
        }
        
        let currentStatus = status(image: image)
        if  currentStatus == .activeOnReset || currentStatus == .testOnReset {
            result.append(.reset)
        }
        
        return result
    }
    
    
    @IBAction func onClickInfo(_ sender: Any) {
        setInfoVisiblity(isHidden: !isInfoHidden)
    }
    
    private func setInfoVisiblity(isHidden: Bool) {
        isInfoHidden = isHidden
        UIView.animate(withDuration: 0.3, animations: { [unowned self] in
            self.expandInfoButton.transform = isHidden ? .identity:CGAffineTransform(rotationAngle: .pi)
        })
        
/*
        infoStackView.isHidden = isInfoHidden
        hashView.isHidden = isInfoHidden
        expandedStackView.isHidden = isInfoHidden
        expandedStackView.layoutIfNeeded()
  */
        let kBottomMargin: CGFloat = 15
        let height: CGFloat = isInfoHidden ? ImageSlotTableViewCell.kDefaultImageCellHeiht : expandedStackView.frame.origin.y + expandedStackView.frame.size.height + kBottomMargin
        delegate?.onImageSlotCellHeightChanged(index: cellIndex, isInfoHidden: isInfoHidden, height: height)
    }
    
    @IBAction func onClickAction(_ sender: UIButton) {
        guard let newtImage = newtImage, cellIndex >= 0 else { return }
        
        let actions = availableActions(image: newtImage)
        let action = actions[sender.tag]

        switch action {
        case .test: delegate?.onClickImageTest(index: cellIndex)
        case .confirm: delegate?.onClickImageConfirm(index: cellIndex)
        case .reset: delegate?.onClickImageReset(index: cellIndex)
        }
    }
}
