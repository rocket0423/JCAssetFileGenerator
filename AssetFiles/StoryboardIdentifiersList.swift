//
//  StoryboardIdentifiersList.swift
//  StoryboardIdentifiersList
//
//  Created by Justin Carstens on 10/11/17.
//  Copyright © 2017 BitSuties. All rights reserved.
//

import Foundation

class StoryboardIdentifiersList: ListGeneratorHelper {

  var keys: [String] = []

  override class func fileExtensions() -> [String] {
    return ["storyboard", "xib"]
  }

  override class func fileSuffix() -> String {
    return "Identifiers"
  }

  override class func newHelper() -> ListGeneratorHelper {
    return StoryboardIdentifiersList()
  }

  override func outputFileName() -> String {
    // Get the File Name
    let fileExtension = ListGeneratorHelper.capitalizedString((parseFilePath as NSString).pathExtension)
    let fileName = ((parseFilePath as NSString).lastPathComponent as NSString).deletingPathExtension
    let formattedFilename = fileName.replacingOccurrences(of: " ", with: "")
    let containsExtensionText = formattedFilename.lowercased().contains(fileExtension.lowercased())
    if singleFile {
      return classPrefix + StoryboardIdentifiersList.fileSuffix()
    } else if containsExtensionText {
      return classPrefix + formattedFilename + StoryboardIdentifiersList.fileSuffix()
    } else {
      return classPrefix + formattedFilename + fileExtension + StoryboardIdentifiersList.fileSuffix()
    }
  }

  override func startGeneratingInfo() -> Bool {
    // Get the File Name
    let fileExtension = ListGeneratorHelper.capitalizedString((parseFilePath as NSString).pathExtension)
    let fileName = ((parseFilePath as NSString).lastPathComponent as NSString).deletingPathExtension
    let formattedFilename = fileName.replacingOccurrences(of: " ", with: "")
    var methodName = "Name"
    if singleFile {
      methodName = formattedFilename + fileExtension + "Name"
    }
    methodName = ListGeneratorHelper.methodName(methodName)

    // Write the storyboard name to the file
    writeItemToFile(fileName, methodName: methodName)

    // Parse all the Identifiers
    do {
      let document: XMLDocument = try XMLDocument(contentsOf: URL(fileURLWithPath: parseFilePath), options: XMLNode.Options())
      var identifiers: [XMLNode] = []
      identifiers.append(contentsOf: try document.nodes(forXPath: "//@storyboardIdentifier"))
      identifiers.append(contentsOf: try document.nodes(forXPath: "//@reuseIdentifier"))
      identifiers.append(contentsOf: try document.nodes(forXPath: "//segue/@identifier"))

      // Write each identifier to the file
      for nextIdentifier in identifiers {
        writeItemToFile(nextIdentifier.stringValue!)
      }
    } catch {}

    return true
  }

  private func writeItemToFile(_ value: String, methodName: String? = nil) {
    if ListGeneratorHelper.isStringEmptyNoWhite(value) {
      // The string is empty so no reason to continue.
      return
    }
    var finalMethodName: String
    if methodName == nil {
      finalMethodName = ListGeneratorHelper.capitalizedString(ListGeneratorHelper.methodName(value))
    } else {
      finalMethodName = ListGeneratorHelper.capitalizedString(ListGeneratorHelper.methodName(methodName!))
    }
    if !verify && keys.contains(finalMethodName) {
      // We are not verifying and this key already exists.
      return
    }
    keys.append(finalMethodName)

    // Generate Method for file
    if swift {
      var implementation = ""
      implementation.append("  /// \(value) Identifier\n")
      implementation.append("  static var \(finalMethodName): String {\n")
      implementation.append("    return \"\(value)\"\n")
      implementation.append("  }\n\n")
      fileWriter.outputMethods.append(implementation)
    } else {
      // Setup Method
      var method = "/// \(value) Identifier\n"
      method.append("+ (NSString *)\(finalMethodName)")

      // Add Method to both m and h files with appropriate endings.
      var implementation = method;
      method.append(";\n")
      implementation.append(" {\n")

      // Add additional info for method
      implementation.append("  return @\"\(value)\";\n")
      implementation.append("}\n\n")

      // Add Header and Method to file writer
      fileWriter.outputHeaders.append(method)
      fileWriter.outputMethods.append(implementation)
    }
  }

}
