//
//  FileWriter.swift
//  BPAssetFileGenerator
//
//  Created by Justin Carstens on 10/10/17.
//  Copyright © 2017 BitSuties. All rights reserved.
//

import Foundation

class FileWriter: NSObject {

  var scriptName: String!
  var fileTypes: String!
  var fileName: String!
  var outputBasePath: String!
  var outputFileName: String!
  var outputHeaders: [String] = []
  var outputMethods: [String] = []
  var warningMessage: String?
  var singleFile: Bool = true
  var swift: Bool = true

  func writeOutputFile() {
    if outputMethods.count == 0 {
      // Nothing to write
      return
    }
    outputFileName = outputFileName.replacingOccurrences(of: " ", with: "")

    // Output the correct file type
    if swift {
      writeSwiftFile()
    } else {
      writeObjCFile()
    }
  }

  private func writeSwiftFile() {
    // Setup the header of the file
    var outputFileContent = ""
    outputFileContent.append("//\n")
    if singleFile {
      outputFileContent.append("// This file is generated from all " + fileTypes + " files by " + scriptName + ".\n")
    } else {
      outputFileContent.append("// This file is generated from " + fileName + " by " + scriptName + ".\n")
    }
    outputFileContent.append("// Please do not edit.\n")
    outputFileContent.append("//\n\n")
    outputFileContent.append("import UIKit\n\n")
    outputFileContent.append("class " + outputFileName + ": NSObject {\n\n")

    // If there is a warning message add it
    if warningMessage != nil {
      outputFileContent.append(warningMessage!)
    }

    // Sort all methods alphabetically
    outputMethods.sort()
    for nextMethod in outputMethods {
      outputFileContent.append(nextMethod)
    }

    outputFileContent.append("}\n")

    // Write the output to a file.
    do {
      let outputPath = (outputBasePath as NSString).appendingPathComponent(outputFileName + ".swift")
      try outputFileContent.write(to: URL(fileURLWithPath: outputPath), atomically: true, encoding: .utf8)
    } catch {}
  }

  private func writeObjCFile() {
    // Setup the header of the file
    var outputHeaderFileContent = ""
    outputHeaderFileContent.append("//\n")
    if singleFile {
      outputHeaderFileContent.append("// This file is generated from all " + fileTypes + " files by " + scriptName + ".\n")
    } else {
      outputHeaderFileContent.append("// This file is generated from " + fileName + " by " + scriptName + ".\n")
    }
    outputHeaderFileContent.append("// Please do not edit.\n")
    outputHeaderFileContent.append("//\n\n")
    // Both Header and main have the same documentation content so copy.
    var outputMainFileContent = outputHeaderFileContent

    // Setup the Header Specific info
    outputHeaderFileContent.append("#import <UIKit/UIKit.h>\n\n")
    outputHeaderFileContent.append("@interface " + outputFileName + ": NSObject\n\n")

    // Sort all methods alphabetically
    outputHeaders.sort()
    for nextHeader in outputHeaders {
      outputHeaderFileContent.append(nextHeader)
    }

    outputHeaderFileContent.append("\n@end\n")

    // Write the output to a file.
    do {
      let outputHeaderPath = (outputBasePath as NSString).appendingPathComponent(outputFileName + ".h")
      try outputHeaderFileContent.write(to: URL(fileURLWithPath: outputHeaderPath), atomically: true, encoding: .utf8)
    } catch {}

    // Setup the Main Specific info
    outputMainFileContent.append("#import \"" + outputFileName + ".h\"\n\n")
    outputMainFileContent.append("@implementation " + outputFileName + "\n\n")

    // If there is a warning message add it
    if warningMessage != nil {
      outputMainFileContent.append(warningMessage!)
    }

    // Sort all methods alphabetically
    outputMethods.sort()
    for nextMethod in outputMethods {
      outputMainFileContent.append(nextMethod)
    }

    outputMainFileContent.append("@end\n")

    // Write the output to a file.
    do {
      let outputMainPath = (outputBasePath as NSString).appendingPathComponent(outputFileName + ".m")
      try outputMainFileContent.write(to: URL(fileURLWithPath: outputMainPath), atomically: true, encoding: .utf8)
    } catch {}
  }

}
