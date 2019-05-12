//
//  StringsLocalizedList.swift
//  StringsLocalizedList
//
//  Created by Justin Carstens on 10/11/17.
//  Copyright © 2017 BitSuties. All rights reserved.
//

import Foundation

class StringsLocalizedList: ListGeneratorHelper {

  var needTranslationKeys: [String] = []
  var devMessages: [String : String] = [:]
  var keys: [String] = []
  let needTranslationText = " // Needs Translation"
  let noMessageText = "/* No comment provided by engineer. */"

  override class func fileExtensions() -> [String] {
    return ["strings"]
  }

  override class func newHelper() -> ListGeneratorHelper {
    return StringsLocalizedList()
  }

  override func startGeneratingInfo() {
    // Get the file name with prefix and any additional info.
    let fileName = ((parseFilePath as NSString).lastPathComponent as NSString).deletingPathExtension
    if singleFile {
      fileWriter.outputFileName = classPrefix + "Strings"
    } else {
      fileWriter.outputFileName = classPrefix + "\(fileName)Strings"
    }

    // Determine if this is the main file or a translation file
    var hasTranslations = false
    let lprojPath = (parseFilePath as NSString).deletingLastPathComponent
    if lprojPath.hasSuffix(".lproj") {
      if !lprojPath.hasSuffix("Base.lproj") {
        // This is a translation file and not the main one so skip.
        return
      }
      // Update all translation files
      hasTranslations = synchronizeFiles()
    }

    // If we are verify and we need to add translations add warning messge for swift classes
    if verify && needTranslationKeys.count > 0 && swift {
      // Add Warning Message to output file
      var missingTranslationMessage = ""
      missingTranslationMessage.append("  /// Warning message so console is notified.\n")
      missingTranslationMessage.append("  @available(iOS, deprecated: 1.0, message: \"Missing Translation\")\n")
      missingTranslationMessage.append("  private static func NeedsTranslation(){}\n\n")

      if fileWriter.warningMessage == nil {
        fileWriter.warningMessage = missingTranslationMessage
      } else  if !fileWriter.warningMessage!.contains("NeedsTranslation") {
        fileWriter.warningMessage!.append(missingTranslationMessage)
      }
    }

    if let stringsDictionary = NSDictionary(contentsOfFile: parseFilePath) as? [String : String] {
      for (nextKey, nextValue) in stringsDictionary {
        let localizedString = formattedValue(nextValue)
        let nextKeyString = formattedValue(nextKey)
        let methodName = ListGeneratorHelper.methodName(nextKeyString)
        let devComment = devMessageForKey(nextKey)
        if ListGeneratorHelper.isStringEmptyNoWhite(methodName) {
          // If the string is empty lets skip it and just continue.
          continue
        }
        if !verify && keys.contains(methodName) {
          // We are not verifying and this key already exists.
          continue
        }
        keys.append(methodName)

        // Add String to the file
        if swift {
          var implementation = ""
          implementation.append("  /// \(localizedString)\n")
          implementation.append("  static var \(methodName): String {\n")
          if hasTranslations {
            if verify && needTranslationKeys.contains(nextKeyString) {
              implementation.append("    NeedsTranslation()\n")
            }
            if devComment != nil {
              implementation.append("    return NSLocalizedString(\"\(nextKeyString)\", tableName: \"\(fileName)\", bundle: Bundle.main, value: \"\(localizedString)\", comment: \"\(devComment!)\")\n")
            } else {
              implementation.append("    return NSLocalizedString(\"\(nextKeyString)\", tableName: \"\(fileName)\", bundle: Bundle.main, value: \"\(localizedString)\", comment: \"\(localizedString)\")\n")
            }
          } else {
            implementation.append("    return \"\(localizedString)\"\n")
          }
          implementation.append("  }\n\n")
          fileWriter.outputMethods.append(implementation)
        } else {
          // Setup Method
          var method = "/// \(localizedString)\n"
          method.append("+ (NSString *)\(methodName)")

          // Add Method to both m and h files with appropriate endings.
          var implementation = method;
          method.append(";\n")
          implementation.append(" {\n")

          // Add additional info for method
          if hasTranslations {
            if verify && needTranslationKeys.contains(nextKeyString) {
              implementation.append("  #warning Needs Translation\n")
            }
            if devComment != nil {
              implementation.append("  return NSLocalizedStringWithDefaultValue(@\"\(nextKeyString)\", @\"\(fileName)\", [NSBundle mainBundle], @\"\(localizedString)\", @\"\(devComment!)\");\n")
            } else {
              implementation.append("  return NSLocalizedStringWithDefaultValue(@\"\(nextKeyString)\", @\"\(fileName)\", [NSBundle mainBundle], @\"\(localizedString)\", nil);\n")
            }
          } else {
            implementation.append("  return @\"\(localizedString)\";\n")
          }
          implementation.append("}\n\n")

          // Add Header and Method to file writer
          fileWriter.outputHeaders.append(method)
          fileWriter.outputMethods.append(implementation)
        }
      }
    }
  }

  private func synchronizeFiles() -> Bool {
    var hasTranslations = false

    let currentFileFolder = ((parseFilePath as NSString).deletingLastPathComponent as NSString).deletingLastPathComponent
    var mainString = ""
    var mainComponents: [String]!
    for nextFile in allFilePaths {
      if nextFile == parseFilePath || (parseFilePath as NSString).lastPathComponent != (nextFile as NSString).lastPathComponent {
        // Not the same strings file
        continue
      }
      let nextFileFolder = ((nextFile as NSString).deletingLastPathComponent as NSString).deletingLastPathComponent
      if currentFileFolder != nextFileFolder {
        // Not the same strings file
        continue
      }
      // Get the components of the main file if we haven't already
      if mainString.isEmpty {
        do {
          mainString = try String(contentsOf: URL(fileURLWithPath: parseFilePath), encoding: .utf8)
          mainComponents = mainString.components(separatedBy: CharacterSet.newlines)
        } catch {
          continue
        }
      }

      // Get the components of the next file
      var nextFileString: String!
      do {
        nextFileString = try String(contentsOf: URL(fileURLWithPath: nextFile), encoding: .utf8)
      } catch {
        continue
      }

      let nextFileComponents = nextFileString.components(separatedBy: CharacterSet.newlines)

      // Start Adding all the appropriate tranlations to the files
      var devMessage: String? = nil
      var devMessageHas: Bool = false
      var translationFile = ""
      for nextMainComponent in mainComponents {
        // Figure out dev comments
        devMessageHas = false
        if nextMainComponent.hasPrefix("/*") && nextMainComponent.hasSuffix("*/") && nextMainComponent != noMessageText {
          devMessage = nextMainComponent
          let startIndex = devMessage!.index(devMessage!.startIndex, offsetBy: 2)
          devMessage = "\(devMessage!.suffix(from: startIndex))"
          let stopIndex = devMessage!.index(devMessage!.endIndex, offsetBy: -2)
          devMessage = "\(devMessage!.prefix(upTo: stopIndex))"
          devMessage = devMessage!.trimmingCharacters(in: .whitespacesAndNewlines)
          devMessageHas = true
        }

        // Get Translation info
        if !nextMainComponent.hasPrefix("\"") {
          translationFile.append(nextMainComponent)
        } else {
          let key = keyForComponent(nextMainComponent)
          if let translation = stringForKey(keyForComponent(nextMainComponent), components: nextFileComponents) {
            translationFile.append(translation)
          } else {
            translationFile.append(nextMainComponent + needTranslationText)
          }

          // Dev Comments end of string
          if devMessage == nil {
            if let range = nextMainComponent.range(of: "//") {
              var endMessage: String = String(nextMainComponent[range.upperBound..<nextMainComponent.endIndex])
              endMessage = endMessage.trimmingCharacters(in: .whitespacesAndNewlines)
              if needTranslationText != " // \(endMessage)" {
                devMessage = endMessage
              }
            }
          }
          // If we have a key and a message add it to the devMessages dict for future use.
          if devMessage != nil && key != nil {
            devMessages[key!] = devMessage!
            devMessage = nil
          }
        }

        translationFile.append("\n")

        // If we passed the line then this is not a dev message so erase it.
        if !devMessageHas {
          devMessage = nil
        }
      }
      translationFile = "\(translationFile.dropLast())"

      // Only create the file if the user wants the helper code enabled.
      // We still go through the creation of the file because of seeing which items need translation.
      if helper {
        do {
          try translationFile.write(to: URL(fileURLWithPath: nextFile), atomically: true, encoding: .utf8)
        } catch {}
      }

      hasTranslations = true
    }
    return hasTranslations
  }

  private func stringForKey(_ key: String?, components: [String]) -> String? {
    if key == nil {
      return nil
    }

    for nextComponent in components {
      if nextComponent.hasPrefix("\"") {
        if key == keyForComponent(nextComponent) {
          if nextComponent.hasSuffix(needTranslationText) {
            needTranslationKeys.append(key!)
          }
          return nextComponent
        }
      }
    }
    needTranslationKeys.append(key!)

    return nil
  }

  private func devMessageForKey(_ key: String) -> String? {
    if devMessages.keys.contains(key) {
      return devMessages[key]!
    }
    return nil
  }

  private func formattedValue(_ string : String) -> String {
    var formattedString = string.replacingOccurrences(of: "\n", with: "\\n")
    formattedString = formattedString.replacingOccurrences(of: "\"", with: "\\\"")
    return formattedString
  }

  private func keyForComponent(_ component: String) -> String? {
    let keys = component.components(separatedBy: "\"")
    if keys.count > 1 {
      return keys[1]
    }
    return nil
  }
}
