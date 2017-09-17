//
//  ViewController.swift
//  MoodTextApp
//
//  Created by Douglas Barreto on 16/09/17.
//  Copyright © 2017 Douglas. All rights reserved.
//

import UIKit
import CoreML

final class StringTokenizer {
    private let string: String
    private let skipStringCount: UInt
    private let options: NSLinguisticTagger.Options
    private let tagger: NSLinguisticTagger
    
    init(string: String,
         options: NSLinguisticTagger.Options = [.omitWhitespace, .omitPunctuation, .omitOther],
         skipStringCount: UInt = 2) {
        self.options = options
        self.skipStringCount = skipStringCount
        let schemeLanguage = NSLinguisticTagger.availableTagSchemes(forLanguage: "en")
        tagger = NSLinguisticTagger ( tagSchemes: schemeLanguage,
                                      options: Int(self.options.rawValue) )
        self.string = string
    }
    
    func tokenize() -> [String: Double] {
        var wordsCountDic = [String: Double]()
        let nsString = string as NSString
        let range = NSRange(location: 0, length: string.utf16.count)
        tagger.string = string
        tagger.enumerateTags(in: range, scheme: .nameType, options: options) { (_, tokenRange, _, _) in
            let stringToken = nsString.substring(with: tokenRange).lowercased()
            //Here if the token string only will be processed if has the size
            //greater than skipStringCount
            guard stringToken.count > skipStringCount else {
                return
            }
            
            if let wordCount = wordsCountDic[stringToken] {
                wordsCountDic[stringToken] = wordCount + 1.0
            } else {
                wordsCountDic[stringToken] = 1.0
            }
        }
        return wordsCountDic
    }
}

enum UserMood: String {
    case sad = "Neg"
    case good = "Pos"
    case neutral = "Neu"
    
    func asEmoji() -> String {
        switch self {
        case .sad:
            return "😔"
        case .good:
            return "😁"
        case .neutral:
            return "😶"
        }
    }
    
    func asColor() -> UIColor {
        switch self {
        case .sad:
            return .red
        case .good:
            return .green
        case .neutral:
            return .gray
        }
    }
    
    
}

final class UserMoodService {
    private let model = SentimentPolarity()
    
    func predictMoodWith(string: String) -> UserMood {
        let wordsCounterDic = StringTokenizer(string: string).tokenize()
        var prediction: SentimentPolarityOutput!
        
        guard wordsCounterDic.count > 0 else {
            return .neutral
        }
        
        do {
            prediction = try model.prediction(input: wordsCounterDic)
        } catch let error {
            print("Problem to predict the input data: \(error.localizedDescription)")
        }
        
        return UserMood(rawValue: prediction.classLabel) ?? .neutral
    }
}


final class ViewController: UIViewController {
    
    @IBOutlet weak var inputTextField: UITextField!
    @IBOutlet weak var outputView: UIView!
    @IBOutlet weak var outputLabel: UILabel!
    @IBOutlet weak var bottomConstraint: NSLayoutConstraint!
    
    private let userMoodService = UserMoodService()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupTextFields()
        updateOutputViewsWith(userMood: .neutral)
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        self.addKeyboardObserver()
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        self.removeKyboardObserver()
    }

    private func setupTextFields() {
        inputTextField.delegate = self
    }
    
    private func updateOutputViewsWith(userMood: UserMood) {
        self.outputLabel.text = userMood.asEmoji()
        UIView.animate(withDuration: 0.2, animations: {
            self.outputView.backgroundColor = userMood.asColor()
        })
    }
}

extension ViewController: UITextFieldDelegate {
    func textField(_ textField: UITextField, shouldChangeCharactersIn range: NSRange, replacementString string: String) -> Bool {
        if let string = textField.text {
           self.updateOutputViewsWith(userMood: userMoodService.predictMoodWith(string: string))
        }
        return true
    }
}

private extension ViewController {
    func addKeyboardObserver() {
        NotificationCenter.default.addObserver(self, selector: #selector(keyboardWasShown(notification:)), name: NSNotification.Name.UIKeyboardWillShow, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(keyboardWillHide(notification:)), name: NSNotification.Name.UIKeyboardWillHide, object: nil)
    }

    func removeKyboardObserver() {
        NotificationCenter.default.removeObserver(self, name: NSNotification.Name.UIKeyboardWillShow, object: nil)
        NotificationCenter.default.removeObserver(self, name: NSNotification.Name.UIKeyboardWillHide, object: nil)
    }

    @objc func keyboardWasShown(notification: NSNotification) {
        var info = notification.userInfo!
        let keyboardFrame: CGRect = (info[UIKeyboardFrameEndUserInfoKey] as! NSValue).cgRectValue

        UIView.animate(withDuration: 0.3, animations: { () -> Void in
            self.bottomConstraint.constant = keyboardFrame.size.height
        })
    }

    @objc func keyboardWillHide(notification: NSNotification) {
        var info = notification.userInfo!
        let keyboardFrame: CGRect = (info[UIKeyboardFrameEndUserInfoKey] as! NSValue).cgRectValue

        UIView.animate(withDuration: 0.3, animations: { () -> Void in
            self.bottomConstraint.constant = -(keyboardFrame.size.height)
        })
    }
}
