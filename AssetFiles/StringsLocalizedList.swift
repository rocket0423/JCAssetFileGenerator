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
  let noMessageText = "/* No comment provided by engineer. */"
  var usedStringString = ""

  override class func fileExtensions() -> [String] {
    return ["strings"]
  }

  override class func fileSuffix() -> String {
    return "Strings"
  }

  override class func newHelper() -> ListGeneratorHelper {
    return StringsLocalizedList()
  }

  override func outputFileName() -> String {
    // Get the file name with prefix and any additional info.
    var fileName = ""
    if !singleFile {
      fileName = ((parseFilePath as NSString).lastPathComponent as NSString).deletingPathExtension
    }
    return classPrefix + fileName + StringsLocalizedList.fileSuffix()
  }

  override func getChecksum() -> String? {
    if verify {
      // Since the warnings to the file that won't go away if we do the quick check don't add the checksum
      return nil
    }

    if !singleFile {
      let lprojPath = (parseFilePath as NSString).deletingLastPathComponent
      if lprojPath.hasSuffix(".lproj") {
        if !lprojPath.hasSuffix("en.lproj") {
          // This is a translation file and not the main one so skip.
          return nil
        }
      }

      if parseFilePath.hasPrefix(fileWriter.outputBasePath) {
        // This is our own file we created
        return nil
      }
      if parseFilePath.hasSuffix("InfoPlist.strings") {
        // InfoPlist is only for the info plist not us
        return nil
      }

      // Hashed key for only this file
      return stringContentsOfFile(parseFilePath)?.hashed(.md5)
    }

    // This is a single file go thorugh all of the file paths to generate the hash
    var combinedFilesString = ""
    for nextFile in allFilePaths {
      let lprojPath = (nextFile as NSString).deletingLastPathComponent
      if lprojPath.hasSuffix(".lproj") {
        if !lprojPath.hasSuffix("en.lproj") {
          // This is a translation file and not the main one so skip.
          continue
        }
      }

      if nextFile.hasPrefix(fileWriter.outputBasePath) {
        // This is our own file we created
        continue
      }
      if nextFile.hasSuffix("InfoPlist.strings") {
        // InfoPlist is only for the info plist not us
        continue
      }

      if let nextFileContents = stringContentsOfFile(nextFile) {
        combinedFilesString.append(nextFileContents)
      }
    }

    return combinedFilesString.hashed(.md5)
  }

  override func startGeneratingInfo() -> Bool {
    // Get the file name
    let fileName = ((parseFilePath as NSString).lastPathComponent as NSString).deletingPathExtension

    if parseFilePath.hasPrefix(fileWriter.outputBasePath) {
      // This is our own file we created
      return false
    }
    if parseFilePath.hasSuffix("InfoPlist.strings") {
      // InfoPlist is only for the info plist not us
      return false
    }

    // Determine if this is the main file or a translation file
    var hasTranslations = false
    let lprojPath = (parseFilePath as NSString).deletingLastPathComponent
    if lprojPath.hasSuffix(".lproj") {
      if !lprojPath.hasSuffix("en.lproj") {
        // This is a translation file and not the main one so skip.
        return false
      }
      // Update all translation files
      hasTranslations = synchronizeFiles()
    }

    // Generate the helper string to find used strings.
    findUsedStrings()

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
        var devComment = devMessageForKey(nextKey)
        if devComment != nil {
          devComment = formattedValue(devComment!)
        }
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
            if !isUsedString(nextKeyString, method: methodName) {
              implementation.append("    StringNotUsed()\n")
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
            if !isUsedString(nextKeyString, method: methodName) {
              implementation.append("  #warning String Not Used\n")
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
    } else {
      print("Could not parse file path \(parseFilePath!)")
    }

    return true
  }

  private func findUsedStrings() {
    if !verify || !usedStringString.isEmpty {
      // We are not verifying used images or we have already done the searching.
      return
    }

    // Get the root path to the project so we can search
    var rootPath = searchPath
    if rootPath == nil {
      if let newRootPath = ListGeneratorHelper.runStringAsCommand("echo \"$SRCROOT\"") {
        rootPath = newRootPath
      }
    }
    if rootPath == nil {
      return
    }

    // Extensions
    var includeExtensionsString = ""
    for nextExtension in ["swift", "m", "storyboard", "xib", "html", "css"] {
      includeExtensionsString.append(" --include=*.\(nextExtension)")
    }
    var excludeFilesString = ""
    for nextExtension in ["swift", "m"] {
      excludeFilesString.append(" --exclude=\(StringsLocalizedList.fileSuffix()).\(nextExtension)")
    }


    // Patterns
    var commandPatterns = ""
    commandPatterns.append(" -e \"\(StringsLocalizedList.fileSuffix())\\.*\"")
    commandPatterns.append(" -e \"\(StringsLocalizedList.fileSuffix()) *\"")

    // Command to get results
    let command = "grep -i -r\(excludeFilesString)\(includeExtensionsString)\(commandPatterns) \"\(rootPath!)\""
    if let result = ListGeneratorHelper.runStringAsCommand(command) {
      usedStringString = result
    }
  }

  private func isUsedString(_ stringKey: String, method: String) -> Bool {
    if !verify {
      // We are not verifying so just return true
      return true
    } else if usedStringString.contains("\(StringsLocalizedList.fileSuffix()).\(method)") {
      return true
    }

    if swift {
      // Add Warning Message to output file only needed for swift
      var notUsedMessage = ""
      notUsedMessage.append("  /// Warning message so console is notified.\n")
      notUsedMessage.append("  @available(iOS, deprecated: 1.0, message: \"String Not Used\")\n")
      notUsedMessage.append("  private class func StringNotUsed(){}\n\n")

      if fileWriter.warningMessage == nil {
        fileWriter.warningMessage = notUsedMessage
      } else if !fileWriter.warningMessage!.contains("StringNotUsed") {
        fileWriter.warningMessage!.append(notUsedMessage)
      }
    }

    // Not found return false and add the image not used function to file
    return false
  }

  private func synchronizeFiles() -> Bool {
    var hasTranslations = false

    let currentFileFolder = ((parseFilePath as NSString).deletingLastPathComponent as NSString).deletingLastPathComponent
    var mainComponents: [String]?
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
      if nextFile.hasPrefix(fileWriter.outputBasePath) {
        // This is our own file we created
        continue
      }
      if nextFile.hasSuffix("InfoPlist.strings") {
        // We don't process InfoPlist
        continue
      }

      // Get the components of the main file if we haven't already
      if mainComponents == nil {
        if let contents = contentsOfFile(parseFilePath) {
          mainComponents = contents.components
        } else {
          // Could not parse the file should continue
          continue
        }
      } else if !verify && !helper {
        // We just needed to get the dev messages on the first pass so now we know if we have translations or not and we got the dev messages.
        return hasTranslations
      }

      // Get the components of the next file. This is only used if we are doing the helper methods or verify methods
      var nextFileComponents: [String]? = nil
      var nextFileEncoding: String.Encoding?
      if helper || verify {
        if let contents = contentsOfFile(nextFile) {
          nextFileComponents = contents.components
          nextFileEncoding = contents.encoding
        } else {
          // Could not parse the file should continue
          continue
        }
      }

      // Translation file should only be written to if we are doing the helper methods
      var translationFile: String? = nil
      var missingTranslationFile: String? = nil
      if helper {
        translationFile = ""
        missingTranslationFile = ""
      }

      // Start Adding all the appropriate tranlations to the files
      var devMessage: String? = nil
      var devMessageHas: Bool = false
      var lastComment: String? = nil
      for nextMainComponent in mainComponents! {
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
          if lastComment != nil {
            if translationFile == "\n" {
              // This is the first line
              translationFile = ""
            }
            translationFile?.append(lastComment!)
          }

          // Store the comment so we can determine later if we need to write it for the missing translation file
          lastComment = nextMainComponent
        } else {
          let key = keyForComponent(nextMainComponent)
          if helper || verify {
            if let translation = stringForKey(keyForComponent(nextMainComponent), components: nextFileComponents!) {
              if lastComment != nil && helper {
                translationFile = "\(translationFile!.dropLast())"
                translationFile?.append(lastComment!)
                translationFile?.append("\n")
              }
              translationFile?.append(translation)
            } else {
              // Write that we are missing a translation to a sepearate file.
              // For missing translation see if we have a comment
              if lastComment != nil {
                missingTranslationFile?.append(lastComment!)
                missingTranslationFile?.append("\n")
              }
              missingTranslationFile?.append(nextMainComponent)
            }
          }

          // Clear the last comment
          lastComment = nil

          // Dev Comments end of string
          if devMessage == nil {
            if let range = nextMainComponent.range(of: "//") {
              let endMessage: String = String(nextMainComponent[range.upperBound..<nextMainComponent.endIndex])
              devMessage = endMessage.trimmingCharacters(in: .whitespacesAndNewlines)
            }
          }
          // If we have a key and a message add it to the devMessages dict for future use.
          if devMessage != nil && key != nil {
            devMessages[key!] = devMessage!
            devMessage = nil
          }
        }

        translationFile?.append("\n")
        missingTranslationFile?.append("\n")

        // If we passed the line then this is not a dev message so erase it.
        if !devMessageHas {
          devMessage = nil
        }
      }

      if helper {
        translationFile = "\(translationFile!.dropLast())"
        missingTranslationFile = "\(missingTranslationFile!.dropLast())"
      }

      // Only create the file if the user wants the helper code enabled.
      // We still go through the creation of the file because of seeing which items need translation.
      if helper {
        do {
          // ReOrganized Translation File
          let nextFileURL = URL(fileURLWithPath: nextFile)
          try translationFile?.write(to: nextFileURL, atomically: true, encoding: nextFileEncoding!)

          if !missingTranslationFile!.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            var fullFileURL = URL(fileURLWithPath: fileWriter.outputBasePath!)
            fullFileURL.appendPathComponent("Needs Translations")
            try FileManager.default.createDirectory(at: fullFileURL, withIntermediateDirectories: true, attributes: nil)



            let fileName = nextFileURL.deletingPathExtension().lastPathComponent
            let languageFolder = nextFileURL.deletingLastPathComponent().deletingPathExtension().lastPathComponent
            fullFileURL.appendPathComponent("\(fileName)-\(languageFolder)")
            fullFileURL.appendPathExtension(nextFileURL.pathExtension)

            // Remove all the extra lines in the translation file
            while missingTranslationFile!.contains("\n\n\n") {
              missingTranslationFile = missingTranslationFile?.replacingOccurrences(of: "\n\n\n", with: "\n\n")
            }
            try missingTranslationFile?.write(to: fullFileURL, atomically: true, encoding: nextFileEncoding!)
          }
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

  private func stringContentsOfFile(_ filePath: String) -> String? {
    let encodingTypes: [String.Encoding] = [.utf8, .utf16, .utf32]
    for nextEncodingType in encodingTypes {
      do {
        return try String(contentsOf: URL(fileURLWithPath: filePath), encoding: nextEncodingType)
      } catch {
        // Possible the file is of a different string ecoding we should just try the next encoding
        continue
      }
    }

    // Couldn't parse the file return nil
    return nil
  }

  private func contentsOfFile(_ filePath: String) -> (components: [String], encoding: String.Encoding)? {
    let encodingTypes: [String.Encoding] = [.utf8, .utf16, .utf32]
    for nextEncodingType in encodingTypes {
      do {
        let parsedString = try String(contentsOf: URL(fileURLWithPath: filePath), encoding: nextEncodingType)
        let parsedComponents = parsedString.components(separatedBy: CharacterSet.newlines)
        return (components: parsedComponents, encoding: nextEncodingType)
      } catch {
        // Possible the file is of a different string ecoding we should just try the next encoding
        continue
      }
    }

    // Couldn't parse the file return nil
    return nil
  }

}
