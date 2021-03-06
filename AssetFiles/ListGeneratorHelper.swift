//
//  ListGeneratorHelper.swift
//  BPAssetFileGenerator
//
//  Created by Justin Carstens on 10/10/17.
//  Copyright © 2017 BitSuties. All rights reserved.
//

import Foundation

class ListGeneratorHelper: NSObject {

  // Info for Generators
  var parseFilePath: String!
  var searchPath: String!
  var classPrefix: String!
  var infoPlist: String?
  var allFilePaths: [String]!
  var minimumSupportVersion: Float = 0.0
  var singleFile: Bool = true
  var verify: Bool = true
  var helper: Bool = true
  var swift: Bool = true
  var swiftObjC: Bool = false
  var fileWriter: FileWriter = FileWriter()

  class func startWithArguments(_ args: [String]) {
    // Default Values
    let startTime = Date()
    let scriptName: String = (args[0] as NSString).lastPathComponent
    var outputhPath: String = (args[0] as NSString).deletingLastPathComponent
    var searchPath: String = outputhPath
    var classPrefix: String = ""
    var infoPlist: String?
    var minimumSupportVersion: Float = 0.0
    var singleFile: Bool = true
    var verify: Bool = true
    var helper: Bool = true
    var swift: Bool = true
    var swiftObjC: Bool = false
    var writeFile: Bool = true
    var writeColors: Bool = false
    var writeFonts: Bool = false
    var writeImages: Bool = false
    var writeIdentifiers: Bool = false
    var writeStrings: Bool = false

    // If running in project run script we can get some information about the projects so it doesn't have to be entered in the command line.
    // Get the apps minimum version number
    if let versionString = ListGeneratorHelper.runStringAsCommand("echo \"$IPHONEOS_DEPLOYMENT_TARGET\"") {
      if let versionFloat = Float(versionString) {
        minimumSupportVersion = versionFloat
      }
    }
    // Get the path to the info plist
    if let newInfoPath = ListGeneratorHelper.runStringAsCommand("echo \"$SRCROOT/$INFOPLIST_FILE\"") {
      infoPlist = newInfoPath
    } else if let newInfoPath = ListGeneratorHelper.runStringAsCommand("echo \"$INFOPLIST_FILE\"") {
      infoPlist = newInfoPath
    }
    // Get the path to the project for searching and writing
    if let newMainPath = ListGeneratorHelper.runStringAsCommand("echo \"$SRCROOT\"") {
      outputhPath = newMainPath
      searchPath = newMainPath
    }

    // Set for user values
    for i in 0..<args.count {
      let nextArg = args[i]
      if nextArg == "-h" {
        // Make sure this help is only printed once.
        if className() == ColorList.className() {
          print("Usage: \(scriptName) [-s <path>] [-o <path>] [-i <path>] [-v <version>] [-p <prefix>] [-m] [-dnverify] [-dnhelp] [-objc] [-sobjc] [-colors] [-fonts] [-images] [-identifiers] [-strings]")
          print("     \(scriptName) -h")
          print("Options:\n")
          print("  -s <path>  Search for folders starting from <path> (Default is Project Source Directory)")
          print("  -o <path>  Output files at <path> (Default is Project Source Directory)");
          print("  -i <path>  Info Plist file at <path> (Default Attempts to retrieve from Project)")
          print("  -v <version> Minimum app version supported <version> (Default Attempts to retrieve from Project)")
          print("  -p <prefix>  Use <prefix> as the class prefix in the generated code")
          print("  -m       Generates each source in their own file (Default is to generate one file with content from all sources)")
          print("  -dnverify  Do not verify any of the code (Default is to always verify)")
          print("  -dnhelp    Do not execute any of the helper code (Default is to always execute the helper code)")
          print("  -objc    Write the file in Objective C (Default is to write in swift)")
          print("  -sobjc   Write the file in Objective C Members (Default is to write in swift)")
          print("  -colors    Write the colors file (Default is to do all files selecting this disables all others not in arguments)")
          print("  -fonts     Write the fonts file (Default is to do all files selecting this disables all others not in arguments)")
          print("  -images    Write the images file (Default is to do all files selecting this disables all others not in arguments)")
          print("  -identifiers Write the identifiers file (Default is to do all files selecting this disables all others not in arguments)")
          print("  -strings   Write the strings file (Default is to do all files selecting this disables all others not in arguments)")
          print("  -h       Print this help and exit")
        }
        return
      } else if nextArg == "-s" {
        searchPath = args[i + 1]
      } else if nextArg == "-o" {
        outputhPath = args[i + 1]
      } else if nextArg == "-i" {
        infoPlist = args[i + 1]
      } else if nextArg == "-v" {
        if let setVersion = Float(args[i + 1]) {
          minimumSupportVersion = setVersion
        }
      } else if nextArg == "-p" {
        classPrefix = args[i + 1]
      } else if nextArg == "-m" {
        singleFile = false
      } else if nextArg == "-dnverify" {
        verify = false
      } else if nextArg == "-dnhelp" {
        helper = false
      } else if nextArg == "-objc" {
        swift = false
      } else if nextArg == "-sobjc" {
        swiftObjC = true
      } else if nextArg == "-colors" {
        writeFile = false
        writeColors = true
      } else if nextArg == "-fonts" {
        writeFile = false
        writeFonts = true
      } else if nextArg == "-images" {
        writeFile = false
        writeImages = true
      } else if nextArg == "-identifiers" {
        writeFile = false
        writeIdentifiers = true
      } else if nextArg == "-strings" {
        writeFile = false
        writeStrings = true
      }
    }

    // Writing specific only check to see if this is the one we are supposed to be writing.
    if !writeFile {
      if writeColors && className() == ColorList.className() {
        writeFile = true
      }
      if writeFonts && className() == CustomFontList.className() {
        writeFile = true
      }
      if writeImages && className() == ImagesList.className() {
        writeFile = true
      }
      if writeIdentifiers && className() == StoryboardIdentifiersList.className() {
        writeFile = true
      }
      if writeStrings && className() == StringsLocalizedList.className() {
        writeFile = true
      }
    }

    if !writeFile {
      // User has specified not to do anything with this class.
      return
    }

    // Find all the files we need to parse
    var filePaths: [String] = []
    for fileExtension in fileExtensions() {
      if let enumerator = FileManager.default.enumerator(atPath: searchPath) {
        for url in enumerator {
          if (url as! String).hasSuffix(".\(fileExtension)") {
            filePaths.append((searchPath as NSString).appendingPathComponent(url as! String))
          }
        }
      }
    }

    var ouputFiles: [String] = []
    // Make sure we have file paths otherwise it will crash the script
    if filePaths.count > 0 {
      // Create header string of file types
      var fileTypes = "."
      if fileExtensions().count > 1 {
        var firstTypes = fileExtensions()
        let lastExtension = firstTypes.removeLast()
        fileTypes.append(firstTypes.joined(separator: ", ."))
        fileTypes.append(" and .\(lastExtension)")
      } else {
        fileTypes.append(fileExtensions().first!)
      }

      // Start generating the necessary files.
      var fileGenerator = newHelper()
      var fileStartDate: Date?
      var firstPassThrough = true
      var singleFileChecksumSame = false
      for nextFile in filePaths {
        if !singleFile {
          fileStartDate = Date()
          fileGenerator = newHelper()
        }
        // Setup the Generatior Information
        fileGenerator.parseFilePath = nextFile
        fileGenerator.searchPath = searchPath
        fileGenerator.classPrefix = classPrefix
        fileGenerator.infoPlist = infoPlist
        fileGenerator.allFilePaths = filePaths
        fileGenerator.minimumSupportVersion = minimumSupportVersion
        fileGenerator.singleFile = singleFile
        fileGenerator.verify = verify
        fileGenerator.helper = helper
        fileGenerator.swift = swift
        fileGenerator.swiftObjC = swiftObjC
        // Setup The Writer information
        fileGenerator.fileWriter.scriptName = scriptName
        fileGenerator.fileWriter.outputBasePath = outputhPath
        fileGenerator.fileWriter.fileTypes = fileTypes
        fileGenerator.fileWriter.fileName = (nextFile as NSString).lastPathComponent
        fileGenerator.fileWriter.singleFile = singleFile
        fileGenerator.fileWriter.swift = swift
        fileGenerator.fileWriter.swiftObjC = swiftObjC
        fileGenerator.fileWriter.outputFileName = fileGenerator.outputFileName().replacingOccurrences(of: " ", with: "")
        ouputFiles.append(contentsOf: fileGenerator.fileWriter.getOutputFilePaths())

        // Compare the checksum to see if there were any changes and if we can skip generating and writing the file.
        if firstPassThrough || !singleFile {
          let newChecksum = fileGenerator.getChecksum()
          if newChecksum != nil && fileGenerator.shouldPerformChecksum() {
            if fileGenerator.fileWriter.getFileChecksum() == newChecksum {
              print("Contents have not changed")
              if !singleFile {
                // Move onto the next file
                print("Finished \(className()) - \((nextFile as NSString).lastPathComponent) - in \(Date().timeIntervalSince(fileStartDate!)) seconds")
                continue
              } else {
                // Finish the for loop since there were no changes to process.
                singleFileChecksumSame = true
                break
              }
            }
          }
          fileGenerator.fileWriter.checksum = newChecksum
        }

        // Generate the info returns true if this is a valid file
        if fileGenerator.startGeneratingInfo() {
          // Write the file
          if !singleFile {
            // Each File needs their own so write the output.
            if fileGenerator.fileWriter.writeOutputFile() {
              print("Finished \(className()) - \((nextFile as NSString).lastPathComponent) - in \(Date().timeIntervalSince(fileStartDate!)) seconds")
            }
          }
        }

        firstPassThrough = false
      }

      if singleFile && !singleFileChecksumSame {
        fileGenerator.finishedGeneratingInfo()
        // We are all finished with all the files so now we can write the output.
        _ = fileGenerator.fileWriter.writeOutputFile()
      }
    }

    // Remove all files with this helper suffix that we didn't process
    do {
      let helperFileSuffix = fileSuffix()
      let files = try FileManager.default.contentsOfDirectory(atPath: outputhPath)
      for nextFile in files {
        if !ouputFiles.contains(nextFile) {
          if (nextFile as NSString).deletingPathExtension.hasSuffix(helperFileSuffix) {
            // Remove
            let removePath = (outputhPath as NSString).appendingPathComponent(nextFile)
            do { try FileManager.default.removeItem(atPath: removePath) } catch {}
          }
        }
      }
    } catch {}

    print("Finished \(className()) in \(Date().timeIntervalSince(startTime)) seconds")

    return
  }

  // MARK: Helpers

  class func runStringAsCommand(_ string: String) -> String? {
    let task = Process()
    task.launchPath = "/bin/sh"
    task.arguments = ["-c", string]

    let pipe = Pipe()
    task.standardOutput = pipe
    task.launch()

    let data = pipe.fileHandleForReading.readDataToEndOfFile()
    if let output = String(data: data, encoding: String.Encoding.utf8) {
      if output.count > 0 {
        return "\(output.dropLast())"
      }
    }
    return nil
  }

  class func methodName(_ string: String) -> String {
    var methodName = titleCaseString(string)
    // If the string is already all caps, it's an abbrevation. Lowercase the whole thing.
    // Otherwise, camelcase it by lowercasing the first character.
    if methodName == methodName.uppercased() {
      methodName = methodName.lowercased()
    } else {
      methodName = methodName.prefix(1).lowercased() + methodName.dropFirst()
    }

    // Remove bad characters
    methodName = methodName.replacingOccurrences(of: "-", with: "_")
    methodName = methodName.replacingOccurrences(of: "~", with: "_")
    var charactersWanted = CharacterSet.alphanumerics
    charactersWanted.insert(charactersIn: "_")
    methodName = methodName.components(separatedBy: charactersWanted.inverted).joined(separator: "")

    // Remove non letters at the beginning of a method since we cant have that
    let letters = CharacterSet.letters
    while methodName.first != nil && "\(methodName.first!)".rangeOfCharacter(from: letters) == nil {
      methodName = "\(methodName.dropFirst())"
    }

    return methodName
  }

  class func titleCaseString(_ string: String) -> String {
    var output = ""
    for word in string.components(separatedBy: CharacterSet.whitespacesAndNewlines) {
      output.append(word.prefix(1).uppercased() + word.dropFirst())
    }
    return output
  }

  class func capitalizedString(_ string: String) -> String {
    return string.prefix(1).uppercased() + string.dropFirst()
  }

  class func isStringEmptyNoWhite(_ string: String) -> Bool {
    return string.replacingOccurrences(of: " ", with: "").isEmpty
  }

  // MARK: Override Methods

  class func fileExtensions() -> [String] {
    NSException(name: NSExceptionName(rawValue: "ListGeneratorHelper"), reason: "Override 'File Extensions' In Subclass", userInfo: nil).raise()
    return []
  }

  class func fileSuffix() -> String {
    NSException(name: NSExceptionName(rawValue: "ListGeneratorHelper"), reason: "Override 'File Suffix' In Subclass", userInfo: nil).raise()
    return ""
  }

  class func newHelper() -> ListGeneratorHelper {
    NSException(name: NSExceptionName(rawValue: "ListGeneratorHelper"), reason: "Override 'New Helper' In Subclass", userInfo: nil).raise()
    return ListGeneratorHelper()
  }

  func outputFileName() -> String {
    NSException(name: NSExceptionName(rawValue: "ListGeneratorHelper"), reason: "Override 'Output File Name' In Subclass", userInfo: nil).raise()
    return ""
  }

  func shouldPerformChecksum() -> Bool {
    // Determine if we should perform the checksum based on wether we can or not.
    return !helper && !verify
  }

  func getChecksum() -> String? {
    // Create a checksum so we can see if there were any changes before creating the new file
    return nil
  }

  func startGeneratingInfo() -> Bool {
    NSException(name: NSExceptionName(rawValue: "ListGeneratorHelper"), reason: "Override 'Start Generating Info' In Subclass", userInfo: nil).raise()
    // Return wether the file we are parsing is valid or not.
    return false
  }

  func finishedGeneratingInfo() {
    // This is an optional override subclass item.
    // This is called in single file mode after all files have been processed.
  }

}
