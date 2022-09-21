//
//  BinaryExecutionViewController.swift
//  Santander
//
//  Created by Serena on 06/09/2022
//
	

import UIKit
import NSTaskiOS


class BinaryExecutionViewController: UIViewController {
    let executableURL: URL
    var task: NSTask = NSTask()
    var textView: UITextView!
    
    init(executableURL: URL) {
        self.executableURL = executableURL
        
        super.init(nibName: nil, bundle: nil)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        view.backgroundColor = .secondarySystemBackground
        
        title = "Execution"
        let doneAction = UIAction {
            if self.task.isRunning {
                self.task.interrupt()
            }
            self.dismiss(animated: true)
        }
        
        navigationItem.rightBarButtonItem = UIBarButtonItem(systemItem: .done, primaryAction: doneAction)
        configureNavigationBarToNormal()
        
        let executableTextField = UITextField()
        
        let action = UIAction {
            if self.task.isRunning {
                self.task.interrupt()
            }
            self.spawnExecutable(pathAndArgs: executableTextField.text!)
        }
        
        executableTextField.returnKeyType = .go
        executableTextField.addAction(action, for: .primaryActionTriggered)
        executableTextField.text = executableURL.path
        executableTextField.font = UIFont(name: "Menlo", size: UIFont.systemFontSize)
        executableTextField.translatesAutoresizingMaskIntoConstraints = false
        executableTextField.backgroundColor = .systemBackground
        executableTextField.inputAccessoryView = makeKeyboardToolbar(forTextField: executableTextField)
        view.addSubview(executableTextField)
        
        let guide = view.safeAreaLayoutGuide
        NSLayoutConstraint.activate([
            executableTextField.trailingAnchor.constraint(equalTo: guide.trailingAnchor),
            executableTextField.leadingAnchor.constraint(equalTo: guide.leadingAnchor),
            executableTextField.topAnchor.constraint(equalTo: guide.topAnchor),
            executableTextField.heightAnchor.constraint(equalToConstant: 50),
        ])
        
        self.textView = UITextView()
        textView.text = ""
        textView.font = .systemFont(ofSize: 20)
        textView.isEditable = false
        textView.translatesAutoresizingMaskIntoConstraints = false
        textView.backgroundColor = view.backgroundColor
        view.addSubview(textView)
        
        NSLayoutConstraint.activate([
            textView.leadingAnchor.constraint(equalTo: guide.leadingAnchor),
            textView.trailingAnchor.constraint(equalTo: guide.trailingAnchor),
            textView.topAnchor.constraint(equalTo: executableTextField.bottomAnchor),
            textView.heightAnchor.constraint(equalTo: view.heightAnchor)
        ])
    }
    
    func makeKeyboardToolbar(forTextField textField: UITextField) -> UIToolbar {
        let toolbar = UIToolbar()
        
        let dismissKeyboardAction = UIAction {
            textField.resignFirstResponder()
        }
        
        let dismissButton = UIBarButtonItem(title: "Dismiss", primaryAction: dismissKeyboardAction)
        toolbar.setItems([.flexibleSpace(), dismissButton], animated: true)
        toolbar.sizeToFit()
        return toolbar
    }
    
    func spawnExecutable(pathAndArgs: String) {
        if pathAndArgs.starts(with: "sudo ") {
            rootexec(cmd: pathAndArgs.substring(from: 5))
        }
        var components = pathAndArgs.components(separatedBy: " ")
        guard let executable = components.first, !executable.isEmpty else {
            self.errorAlert("Enter a valid executable and arguments.", title: "Input is empty")
            return
        }
        
        // make it just args
        components.removeFirst()
        self.task = NSTask()
        task.executableURL = URL(fileURLWithPath: executable)
        task.arguments = components
        
        let pipe = Pipe()
        pipe.fileHandleForReading.readabilityHandler = { outPipe in
            guard let output = String(data: outPipe.availableData, encoding: .utf8),
            !output.isEmpty else {
                return
            }
            
            DispatchQueue.main.async {
                self.textView.text.append(output)
            }
        }
        
        task.standardError = pipe
        task.standardOutput = pipe
        do {
            textView.text = ""
            try task.launchAndReturnError()
            task.waitUntilExit()
        } catch {
            self.errorAlert(error, title: "Unable to launch process")
        }
    }

    func rootexec(cmd: String) {
        var attr: posix_spawnattr_t?
        posix_spawnattr_init(&attr)
        posix_spawnattr_set_persona_np(&attr, 99, 1)
        posix_spawnattr_set_persona_uid_np(&attr, 0)
        posix_spawnattr_set_persona_gid_np(&attr, 0)

        let pipe = Pipe()
        pipe.fileHandleForReading.readabilityHandler = { outPipe in
            guard let output = String(data: outPipe.availableData, encoding: .utf8),
            !output.isEmpty else {
                return
            }
            
            DispatchQueue.main.async {
                self.textView.text.append(output)
            }
        }

        var fileActions: posix_spawn_file_actions_t?
        posix_spawn_file_actions_init(&fileActions)
        posix_spawn_file_actions_adddup2(&fileActions, pipe, 1)
        posix_spawn_file_actions_adddup2(&fileActions, pipe, 2)

        var pid: pid_t = 0
        let cmdSplit = cmd.components(separatedBy: " ")
        var argv: [UnsafeMutablePointer<CChar>?] = cmdSplit.map { strdup($0) }
        argv.append(nil)
        
        textView.text = ""
        let result = posix_spawn(&pid, cmdSplit[0], &fileActions, &attr, &argv, environ)
        let err = errno
        if result != 0 {
            print("Failed")
            print("Error: \(result) Errno: \(err)")
        }
    }
}
