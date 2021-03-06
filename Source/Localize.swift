//
//  LocalizableSwift.swift
//  Localize
//
//  Copyright © 2017 Kekkiwaa Inc. All rights reserved.
//

import UIKit

public let LanguageChangeNotification = "LanguageChangeNotification"

public enum LocalizableInterface {
    case keyValue
    case classes
    case boot
}

public class Localize: NSObject {
    
    // MARK: Properties
    
    /// Name of UserDefault key where store user prefered language
    private let storageKey = "localizable.swift.language"
    
    /// Json data storaged in a file
    private var json: NSDictionary?
    
    /// Use this for testing mode, search resources in different bundles.
    private var testing: Bool = false
    
    /// Shated instance
    public static let shared: Localize = Localize()
    
    /// Name for storaged Json Files
    /// The rule for name is fileName-LanguageKey.json
    public var fileName = "lang"
    
    /// Default language, if this can't find a key in your current language
    /// Try read key in default language
    public var defaultLanguage: Languages = .english
    
    /// Decide if your interface localization is based on LocalizableInterface
    public var localizableInterface: LocalizableInterface = .boot
    
    /// This override prevent user access to different instances for this class.
    /// Always use shared instance.
    private override init() {
        super.init()
    }
    
    // MARK: Read JSON methods

    /// This metod contains a logic to read return JSON data
    /// If JSON not is defined, this try use a default
    /// As long as the default language is the same as the current one.
    private func readJSON() -> NSDictionary? {
        if self.json != nil {
            return self.json
        }
        
        let lang = self.language()
        
        self.json = self.readJSON(named: "\(self.fileName)-\(lang)")
        
        if self.json == nil && lang != self.defaultLanguage.rawValue {
            self.json = self.readDefaultJSON()
        }
        
        return self.json
    }
    
    /// Read a JSON with default language value.
    ///
    /// - returns: json or nil value.
    private func readDefaultJSON() -> NSDictionary? {
        return self.readJSON(named: "\(self.fileName)-\(self.defaultLanguage.rawValue)")
    }
    
    /// This method has path where file is
    /// If can't find a path return a nil value
    /// If can't serialize data return a nil value
    private func readJSON(named name:String) -> NSDictionary? {
        guard let path = self.path(name: name) else {
            return nil
        }
        guard let data = try? Data(contentsOf: URL(fileURLWithPath: path)) else {
            print("Localize can't read your file")
            return nil
        }
        do {
            return try JSONSerialization.jsonObject(with: data, options: JSONSerialization.ReadingOptions.mutableContainers) as? NSDictionary
        }
        catch {
            print("Localize can't parse your file")
            return nil
        }
    }
    
    /// Try search key in your dictionary using single level
    /// If it doesn't find the key it will use the multilevel
    /// If the key not exis in your JSON return nil value
    private func localizeFile(key:String, json:NSDictionary) -> String? {
        if let string = json[key] {
            return string as? String
        }
        
        if let string = self.localizeLevel(key: key, json: json) {
            return string
        }
        
        return nil
    }
    
    /// Try search key in your dictionary using multiples levels
    /// It is necessary that the result be a string
    /// Otherwise it returns nil value
    private func localizeLevel(key: String, json:AnyObject?) -> String? {
        let values = key.components(separatedBy: ".")
        var jsonCopy = json
        for key in values {
            if let result = jsonCopy?[key] {
                jsonCopy = result as AnyObject?
            } else {
                return nil
            }
        }
        return jsonCopy as? String
    }
    
    // Interator for String Enumerators
    private func iterateEnum<T: Hashable>(_: T.Type) -> AnyIterator<T> {
        var i = 0
        return AnyIterator {
            let next = withUnsafePointer(to: &i) {
                $0.withMemoryRebound(to: T.self, capacity: 1) { $0.pointee }
            }
            if next.hashValue != i { return nil }
            i += 1
            return next
        }
    }
    
    /// Path for your env
    /// if testing mode is enable we change the bundle
    /// in other case use a main bundle.
    /// 
    /// - returns: a string url where is your file
    private func path(name:String) -> String? {
        if self.testing {
            return Bundle(for: type(of: self)).path(forResource: name, ofType: "json")
        }
        return Bundle.main.path(forResource: name, ofType: "json")
    }
    
    // MARK: Public methods
    
    /// Localize a string using your JSON File
    /// If the key is not found return the same key
    /// That prevent replace untagged values
    ///
    /// - returns: localized key or same text
    public func localize(key:String) -> String {
        guard let json = self.readJSON() else {
            return key
        }
        
        let string = self.localizeFile(key: key, json: json)
        if string != nil {
            return string!
        }
        
        guard let defaultJSON = self.readDefaultJSON() else {
            return key
        }
        
        let defaultString = self.localizeFile(key: key, json: defaultJSON)
        if defaultString != nil {
            return defaultString!
        }
        
        return key
    }
    
    /// Localize a string using your JSON File
    /// That replace all % character in your string with replace value.
    ///
    /// - parameter value: The replacement value
    ///
    /// - returns: localized key or same text
    public func localize(key:String, replace:String) -> String {
        let string = self.localize(key: key)
        if string == key {
            return key
        }
        return string.replacingOccurrences(of: "%", with: replace)
    }
    
    /// Localize a string using your JSON File
    /// That replace each % character in your string with each replace value.
    ///
    /// - parameter value: The replacement values
    ///
    /// - returns: localized key or same text
    public func localize(key:String, values replace:[Any]) -> String {
        var string = self.localize(key: key)
        if string == key {
            return key
        }
        var array = string.components(separatedBy: "%")
        string = ""
        _ = replace.count + 1
        for (index, element) in replace.enumerated() {
            if index < array.count {
                let new = array.remove(at: 0)
                string = index == 0 ? "\(new)\(element)" : "\(string)\(new)\(element) "
            }
        }
        string += array.joined(separator: "")
        string = string.replacingOccurrences(of: "  ", with: " ")
        return string
    }
    
    /// Localize string with dictionary values
    /// Get properties in your key with rule :property
    /// If property not exist in this string, not is used.
    ///
    /// - parameter value: The replacement dictionary
    ///
    /// - returns: localized key or same text
    public func localize(key:String, dictionary replace:[String:String]) -> String {
        var string = self.localize(key: key)
        for (key, value) in replace {
            string = string.replacingOccurrences(of: ":\(key)", with: value)
        }
        return string
    }

    // MARK: Config methods
    
    /// Return storaged language or default language in device
    ///
    /// - returns: current used language
    public func language() -> String {
        let defaults = UserDefaults.standard
        if let lang = defaults.string(forKey: self.storageKey) {
            return lang
        }
        return Locale.preferredLanguages[0].components(separatedBy: "-")[0]
    }
    
    /// Update default languaje, this store a language key and retrive the next time
    public func update(language:Languages) -> Void {
        let defaults = UserDefaults.standard
        defaults.setValue(language.rawValue, forKey: self.storageKey)
        defaults.synchronize()
        self.json = nil
        NotificationCenter.default.post(name: Notification.Name(rawValue: LanguageChangeNotification), object: nil)
    }
    
    /// Update default languaje, this store a language key and retrive the next time
    public func update(language string:String) -> Void {
        guard let language = Languages(rawValue: string) else {
            return
        }
        return self.update(language: language)
    }
    
    /// Update base file name, searched in path.
    public func update(fileName:String) {
        self.fileName = fileName
        self.json = nil
    }
    
    /// Update default language
    public func update(defaultLanguage: Languages) {
        self.defaultLanguage = defaultLanguage
    }
    
    /// This remove the language key storaged.
    public func resetLanguage() -> Void {
        let defaults = UserDefaults.standard
        defaults.removeObject(forKey: self.storageKey)
        defaults.synchronize()
    }
    
    /// Show all aviable languajes whit criteria name
    ///
    /// - returns: list with storaged languages code
    public func availableLanguages() -> [String] {
        var languages : [String] = []
        for language in iterateEnum(Languages.self) {
            let name = "\(self.fileName)-\(language.rawValue)"
            let path = self.path(name: name)
            if path != nil {
                languages.append(language.rawValue)
            }
        }
        return languages
    }
    
    /// Display name for current user language.
    ///
    /// - return: String form language code in current user language
    public func displayNameForLanguage(_ language: String) -> String {
        let locale : NSLocale = NSLocale(localeIdentifier: self.language())
        if let name = locale.displayName(forKey: NSLocale.Key.identifier, value: language) {
            return name.capitalized
        }
        return ""
    }
    
    /// Enable testing mode
    /// Please not use in your code, is only for test schema.
    public func testingMode() {
        self.testing = true
    }
    
}
