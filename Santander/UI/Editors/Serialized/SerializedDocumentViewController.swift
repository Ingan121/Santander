//
//  SerializedDocumentViewController.swift
//  Santander
//
//  Created by Serena on 16/08/2022.
//

import UIKit

/// A ViewController which displays the contents of a PropertyList or JSON file
class SerializedDocumentViewController: UITableViewController, SerializedItemViewControllerDelegate {
    typealias SerializedDictionaryType = [String: SerializedDocumentType]
    
    var serializedDict: SerializedDictionaryType {
        willSet {
            keys = Array(newValue.keys)
        }
    }
    
    lazy var keys = Array(serializedDict.keys)
    var fileURL: URL?
    var canEdit: Bool
    let type: SerializedDocumentViewerType
    
    init(dictionary: SerializedDictionaryType, type: SerializedDocumentViewerType, title: String, fileURL: URL? = nil, canEdit: Bool) {
        self.serializedDict = dictionary
        self.type = type
        self.fileURL = fileURL
        self.canEdit = canEdit
        
        super.init(style: .userPreferred)
        self.title = title
    }
    
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        self.navigationItem.rightBarButtonItem = UIBarButtonItem(systemItem: .done, primaryAction: UIAction(withClosure: dismissVC))
    }
    
    convenience init?(type: SerializedDocumentViewerType, fileURL: URL, canEdit: Bool) {
        
        switch type {
        case .json:
            guard let data = try? Data(contentsOf: fileURL),
                  let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
                return nil
            }
            
            var newDict: SerializedDocumentViewController.SerializedDictionaryType = [:]
            
            for (key, value) in json {
                newDict[key] = SerializedDocumentType(item: value)
            }
            
            self.init(dictionary: newDict, type: .json, title: fileURL.lastPathComponent, fileURL: fileURL, canEdit: canEdit)
        case .plist(_):
            let fmt: UnsafeMutablePointer<PropertyListSerialization.PropertyListFormat>? = .allocate(capacity: 4)
            defer {
                fmt?.deallocate()
            }
            
            guard let data = try? Data(contentsOf: fileURL),
                  let plist = try? PropertyListSerialization.propertyList(from: data, format: fmt) as? [String: Any] else {
                return nil
            }
            
            var newDict: SerializedDocumentViewController.SerializedDictionaryType = [:]
            
            for (key, value) in plist {
                newDict[key] = SerializedDocumentType(item: value)
            }
            
            self.init(dictionary: newDict, type: .plist(format: fmt?.pointee), title: fileURL.lastPathComponent, fileURL: fileURL, canEdit: canEdit)
        }
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func numberOfSections(in tableView: UITableView) -> Int {
        return 1
    }
    
    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return serializedDict.keys.count
    }
    
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = UITableViewCell(style: .value2, reuseIdentifier: nil)
        var conf = cell.defaultContentConfiguration()
        let text = keys[indexPath.row]
        
        conf.text = text
        let elem = serializedDict[text]
        
        switch elem {
        case .dictionary(_), .array(_):
            cell.accessoryType = .disclosureIndicator
            conf.secondaryText = elem?.typeDescription
        default:
            conf.secondaryText = elem?.description
            cell.accessoryType = .detailButton
        }
        
        cell.contentConfiguration = conf
        return cell
    }
    
    func dismissVC() {
        self.dismiss(animated: true)
    }
    
    /// Present the SerializedDocumentViewController for a specified indexPath
    func presentViewController(forIndexPath indexPath: IndexPath) {
        let text = keys[indexPath.row]
        let elem = serializedDict[text]!
        
        if case .array(let arr) = elem {
            let vc = SerializedArrayViewController(style: .insetGrouped, array: arr, title: text)
            self.navigationController?.pushViewController(vc, animated: true)
        } else if case .dictionary(let dict) = elem {
            var newDict: SerializedDictionaryType = [:]
            for (key, value) in dict {
                newDict[key] = .init(item: value)
            }
            
            let vc = SerializedDocumentViewController(dictionary: newDict, type: type, title: text, fileURL: fileURL, canEdit: false)
            self.navigationController?.pushViewController(vc, animated: true)
        } else {
            let vc = SerializedItemViewController(item: elem, itemKey: text)
            vc.delegate = self
            let navVC = UINavigationController(rootViewController: vc)
            if #available(iOS 15.0, *) {
                navVC.sheetPresentationController?.detents = [.medium()]
            }
            self.present(navVC, animated: true)
        }
    }
    
    override func tableView(_ tableView: UITableView, accessoryButtonTappedForRowWith indexPath: IndexPath) {
        presentViewController(forIndexPath: indexPath)
    }
    
    func didChangeName(ofItem item: String, to newName: String) {
        guard let value = serializedDict[item] else {
            return
        }
        
        serializedDict[item] = nil
        serializedDict[newName] = value
        
        writeToFile()
        tableView.reloadData()
    }
    
    func didChangeValue(ofItem item: String, to newValue: SerializedDocumentType) {
        serializedDict[item] = newValue
        writeToFile()
        tableView.reloadData()
    }
    
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        presentViewController(forIndexPath: indexPath)
    }
    
    func writeToFile() {
        // TODO: - Support for editing nested dicts!
        guard let fileURL = fileURL, canEdit else {
            return
        }
        
        switch type {
        case .json:
            do {
                try JSONSerialization.data(withJSONObject: serializedDict.asAnyDictionary()).write(to: fileURL, options: .atomic)
            } catch {
                self.errorAlert(error, title: "Unable to write to file \(fileURL.lastPathComponent)")
            }
        case .plist(let format):
            guard let format = format else {
                self.errorAlert("Unable to get plist format", title: "Can't write to Property List file")
                return
            }
            
            do {
                try PropertyListSerialization.data(fromPropertyList: serializedDict.asAnyDictionary(), format: format, options: 0).write(to: fileURL, options: .atomic)
            } catch {
                self.errorAlert(error, title: "Unable to write to file \(fileURL.lastPathComponent)")
            }
        }
    }
    
    override func tableView(_ tableView: UITableView, trailingSwipeActionsConfigurationForRowAt indexPath: IndexPath) -> UISwipeActionsConfiguration? {
        
        guard canEdit else {
            return nil
        }
        
        let deleteAction = UIContextualAction(style: .destructive, title: nil) { _, _, completion in
            
            self.serializedDict[self.keys[indexPath.row]] = nil
            self.writeToFile()
            self.tableView.deleteRows(at: [indexPath], with: .fade)
            completion(true)
        }
        deleteAction.image = .remove
        
        return UISwipeActionsConfiguration(actions: [deleteAction])
    }
}

/// The types openable in SerializedDocumentViewController
enum SerializedDocumentViewerType {
    case json
    case plist(format: PropertyListSerialization.PropertyListFormat?)
}
