//
//  ColorList.swift
//  ColorList
//
//  Created by Justin Carstens on 10/10/17.
//  Copyright © 2017 BitSuties. All rights reserved.
//

import Foundation

class ColorList: ListGeneratorHelper {

  var allColors: [String] = []

  override class func fileExtensions() -> [String] {
    return ["colors", "xcassets"]
  }

  override class func fileSuffix() -> String {
    return "Colors"
  }

  override class func newHelper() -> ListGeneratorHelper {
    return ColorList()
  }

  override func outputFileName() -> String {
    // Get the file name with prefix and any additional info.
    var fileName = ""
    if !singleFile {
      fileName = ((parseFilePath as NSString).lastPathComponent as NSString).deletingPathExtension
    }
    return classPrefix + fileName + ColorList.fileSuffix()
  }

  override func startGeneratingInfo() -> Bool {
    // Get the colors
    if parseFilePath.hasSuffix("colors") {
      parseColorsFile()
    } else {
      parseAssetsFile()
    }

    // Make sure the storyboard is not using 'xcassets' files on apps supporting older versions of the iOS.
    verifyStoryboardCompatibility()

    return true
  }

  override func finishedGeneratingInfo() {
    // Check to see if we have any missing images
    findMissingColors()
  }

  private func parseColorsFile() {
    if let colorDictionary = NSDictionary(contentsOfFile: parseFilePath) as? [String : String] {
      for (nextKey, nextValue) in colorDictionary {
        var rgbaComponents: [String]? = convertHexColorString(nextValue)
        if rgbaComponents == nil {
          rgbaComponents = convertRGBAColorString(nextValue)
        }
        writeColor(name: nextKey, rgba: rgbaComponents, colorString: nextValue, assets: false)
      }
    }
  }

  private func parseAssetsFile() {
    var jsonFiles: [String] = []
    if let enumerator = FileManager.default.enumerator(atPath: parseFilePath) {
      for url in enumerator {
        if (url as! String).hasSuffix(".colorset/Contents.json") {
          jsonFiles.append((parseFilePath as NSString).appendingPathComponent(url as! String))
        }
      }
    }
    for nextJsonFile in jsonFiles {
      // Get the name of the color
      let colorName = (((nextJsonFile as NSString).deletingLastPathComponent as NSString).lastPathComponent as NSString).deletingPathExtension
      do {
        // Parse the json file to get to the colors
        let jsonData = try Data(contentsOf:  URL(fileURLWithPath: nextJsonFile))
        if let jsonDictionary = try JSONSerialization.jsonObject(with: jsonData, options: JSONSerialization.ReadingOptions.mutableContainers) as? [String : Any] {
          if let colorsArray = jsonDictionary["colors"] as? [[String : Any]] {
            if let colorDictionary = colorsArray[0]["color"] as? [String : Any] {
              if let colorComponents = colorDictionary["components"] as? [String : String] {
                // Parse the color components
                if let redColor = colorComponents["red"] {
                  if let greenColor = colorComponents["green"] {
                    if let blueColor = colorComponents["blue"] {
                      // Get the alpha color
                      var alphaColor = "1"
                      if let alphaColorFloat = colorFloatFromString(colorComponents["alpha"], max: 1.0) {
                        alphaColor = String(format: "%g", alphaColorFloat)
                      }
                      var colorString = hexStringFromColors(red: redColor, green: greenColor, blue: blueColor)
                      var rgbaComponents: [String]? = convertHexColorString(colorString, alpha: alphaColor)
                      if rgbaComponents == nil {
                        colorString = redColor + "," + greenColor + "," + blueColor + "," + alphaColor
                        rgbaComponents = convertRGBAColorString(colorString)
                      }
                      allColors.append(colorName)
                      writeColor(name: colorName, rgba: rgbaComponents, colorString: colorString, assets: true)
                    }
                  }
                }
              }
            }
          }
        }
      } catch {}
    }
  }

  private func writeColor(name: String, rgba: [String]?, colorString: String?, assets: Bool) {
    if rgba != nil {
      if swift {
        var implementation = ""
        if colorString != nil {
          implementation.append("  // \(ColorList.capitalizedString(name)) Color \(colorString!)\n")
        } else {
          implementation.append("  // \(ColorList.capitalizedString(name)) Color\n")
        }
        implementation.append("  static var \(ColorList.methodName(name)): UIColor {\n")
        if assets {
          if minimumSupportVersion < 11 {
            // For Assets The Color can only be read on iOS 11 and up.
            implementation.append("    if #available(iOS 11.0, *) {\n")
            implementation.append("      if let foundColor = UIColor(named: \"\(name)\") {\n")
            implementation.append("        return foundColor\n")
            implementation.append("      }\n")
            implementation.append("    }\n")
          } else {
            implementation.append("    if let foundColor = UIColor(named: \"\(name)\") {\n")
            implementation.append("      return foundColor\n")
            implementation.append("    }\n")
          }
        }
        implementation.append("    return UIColor(red:\(rgba![0]), green:\(rgba![1]), blue:\(rgba![2]), alpha:\(rgba![3]))\n")
        implementation.append("  }\n\n")
        fileWriter.outputMethods.append(implementation)
      } else {
        // Setup Method
        var method = ""
        if colorString != nil {
          method.append("// \(ColorList.capitalizedString(name)) Color \(colorString!)\n")
        } else {
          method.append("// \(ColorList.capitalizedString(name)) Color\n")
        }
        method.append("+ (UIColor *)\(ColorList.methodName(name))")

        // Add Method to both m and h files with appropriate endings.
        var implementation = method;
        method.append(";\n")
        implementation.append(" {\n")

        // Add additional info for method
        if assets {
          if minimumSupportVersion < 11 {
            // For Assets The Color can only be read on iOS 11 and up.
            implementation.append("  if (@available(iOS 11.0, *)) {\n")
            implementation.append("    UIColor *foundColor = [UIColor colorNamed:@\"\(name)\"];\n")
            implementation.append("    if (foundColor != nil) {\n")
            implementation.append("      return foundColor;\n")
            implementation.append("    }\n")
            implementation.append("  }\n")
          } else {
            implementation.append("  UIColor *foundColor = [UIColor colorNamed:@\"\(name)\"];\n")
            implementation.append("  if (foundColor != nil) {\n")
            implementation.append("    return foundColor;\n")
            implementation.append("  }\n")
          }
        }
        implementation.append("  return [UIColor colorWithRed:\(rgba![0]) green:\(rgba![1]) blue:\(rgba![2]) alpha:\(rgba![3])];\n")
        implementation.append("}\n\n")

        // Add Header and Method to file writer
        fileWriter.outputHeaders.append(method)
        fileWriter.outputMethods.append(implementation)
      }
    } else if verify {
      // Add the warning message.
      if swift {
        var warningMessage = ""
        warningMessage.append("  /// Warning message so console is notified.\n")
        warningMessage.append("  @available(iOS, deprecated: 1.0, message: \"Invalid Color\")\n")
        warningMessage.append("  private func InvalidColor(){}\n\n")
        fileWriter.warningMessage = warningMessage

        // Add the invalid color for user to fix.
        var implementation = ""
        implementation.append("  // Invalid Hex Color \(name) '\(colorString!)' please make sure it is in the proper format 'AAAAAA'\n")
        implementation.append("  // Invalid RGB or RGBA Color \(name) '\(colorString!)' please make sure it is in the proper format 'r,g,b,a' or 'r,g,b'\n")
        implementation.append("  private var \(name): UIColor? {\n")
        implementation.append("    InvalidColor()\n")
        implementation.append("    return nil\n")
        implementation.append("  }\n\n")
        fileWriter.outputMethods.append(implementation)
      } else {
        // Add the invalid color for user to fix.
        var implementation = ""
        implementation.append("// Invalid Hex Color \(name) '\(colorString!)' please make sure it is in the proper format 'AAAAAA'\n")
        implementation.append("// Invalid RGB or RGBA Color \(name) '\(colorString!)' please make sure it is in the proper format 'r,g,b,a' or 'r,g,b'\n")
        implementation.append("+ (UIColor *)\(name) {\n")
        implementation.append("  #warning Invalid Color\n")
        implementation.append("  return nil;\n")
        implementation.append("}\n\n")
        fileWriter.outputMethods.append(implementation)
      }
    }
  }

  private func convertHexColorString(_ string: String?, alpha: String = "1") -> [String]? {
    if string == nil {
      return nil
    }

    // Remove Pound Sign If exists
    var hexString = string!
    if hexString.hasPrefix("#") {
      hexString = "\(hexString.dropFirst())"
    }

    // Make sure string is of correct length
    if hexString.count != 6 {
      return nil
    }

    // Make sure all the characters are valid
    let hexChars = NSCharacterSet(charactersIn: "0123456789ABCDEF").inverted
    if hexString.uppercased().rangeOfCharacter(from: hexChars) != nil {
      return nil
    }
    let cStr = hexString.cString(using: String.Encoding.ascii)
    let color = strtol(cStr, nil, 16)

    let b = color & 0xFF
    let g = (color >> 8) & 0xFF
    let r = (color >> 16) & 0xFF

    // Generate the
    var colorComponents: [String] = ["1", "1", "1", alpha]
    colorComponents[0] = String(format: "%g", CGFloat(r)/255.0)
    colorComponents[1] = String(format: "%g", CGFloat(g)/255.0)
    colorComponents[2] = String(format: "%g", CGFloat(b)/255.0)
    return colorComponents
  }

  private func convertRGBAColorString(_ string: String?) -> [String]? {
    if string == nil {
      return nil
    }
    let colorComponentStrings = string!.components(separatedBy: ",")
    if colorComponentStrings.count == 3 || colorComponentStrings.count == 4 {
      // Make sure we have valid colors
      guard let redColor = colorFloatFromString(colorComponentStrings[0]) else {
        return nil
      }
      guard let greenColor = colorFloatFromString(colorComponentStrings[1]) else {
        return nil
      }
      guard let blueColor = colorFloatFromString(colorComponentStrings[2]) else {
        return nil
      }

      // Set the RGB Colors
      var colorComponents: [String] = ["1", "1", "1", "1"]
      if redColor > 1 || greenColor > 1 || blueColor > 1 {
        colorComponents[0] = String(format: "%g", redColor/255.0)
        colorComponents[1] = String(format: "%g", greenColor/255.0)
        colorComponents[2] = String(format: "%g", blueColor/255.0)
      } else {
        colorComponents[0] = String(format: "%g", redColor)
        colorComponents[1] = String(format: "%g", greenColor)
        colorComponents[2] = String(format: "%g", blueColor)
      }

      // Get the Alpha Color
      if colorComponentStrings.count == 4 {
        if let alphaColor = colorFloatFromString(colorComponentStrings[3], max: 1.0) {
          colorComponents[3] = String(format: "%g", alphaColor)
        }
      }
      return colorComponents
    }
    return nil
  }

  private func colorFloatFromString(_ string: String?, max: Float = 255.0) -> Float? {
    if string == nil {
      return nil
    }
    guard let color = Float(string!) else {
      return nil
    }
    if color > max {
      return max
    } else if color < 0 {
      return 0
    }
    return color
  }

  private func hexStringFromColors(red: String, green: String, blue: String) -> String? {
    if !red.starts(with: "0x") || !green.starts(with: "0x") || !blue.starts(with: "0x") {
      return nil
    }
    let hexRed = red.replacingOccurrences(of: "0x", with: "")
    let hexGreen = green.replacingOccurrences(of: "0x", with: "")
    let hexBlue = blue.replacingOccurrences(of: "0x", with: "")
    return hexRed + hexGreen + hexBlue
  }

  private func verifyStoryboardCompatibility() {
    if !verify || minimumSupportVersion >= 11.0 {
      // If we are not verifying no need to continue.
      // Storyboards are fine they can support the 'xcassets' color files.
      return
    }

    // Get the root path to the project so we can search
    var rootPath = searchPath
    if let newRootPath = ListGeneratorHelper.runStringAsCommand("echo \"$SRCROOT\"") {
      rootPath = newRootPath
    }
    if rootPath == nil {
      return
    }

    // Extensions
    var includeExtensionsString = ""
    for nextExtension in ["storyboard", "xib"] {
      includeExtensionsString.append(" --include=*.\(nextExtension)")
    }

    // Command to find results
    let command = "grep -i -r\(includeExtensionsString) \"<namedColor name=\\\"*\\\"\" \"\(rootPath!)\""
    if ListGeneratorHelper.runStringAsCommand(command) != nil {
      var errorMessage = ""
      if swift {
        errorMessage.append("  /// xcassets colors are not supported in storboard or nib files for devices running pre iOS11 remove them or the app will crash for those users.\n")
        errorMessage.append("  /// Recommend setting the colors in the source code to keep the global color scheme if changing.\n")
        errorMessage.append("  private var storyboardOrNibPreiOS11: UIColor? {\n")
        errorMessage.append("    PreiOS11()\n")
        errorMessage.append("    return nil\n")
        errorMessage.append("  }\n\n")
      } else {
        errorMessage.append("/// xcassets colors are not supported in storboard or nib files for devices running pre iOS11 remove them or the app will crash for those users.\n")
        errorMessage.append("/// Recommend setting the colors in the source code to keep the global color scheme if changing.\n")
        errorMessage.append("+ (UIColor *)storyboardOrNibPreiOS11 {\n")
        errorMessage.append("  PreiOS11();\n")
        errorMessage.append("  return nil;\n")
        errorMessage.append("}\n\n")
      }

      if fileWriter.warningMessage == nil {
        fileWriter.warningMessage = errorMessage
      } else  if !fileWriter.warningMessage!.contains("storyboardOrNibPreiOS11") {
        fileWriter.warningMessage!.append(errorMessage)
      }
    }

  }

  private func findMissingColors() {
    if !verify || !singleFile {
      // If we are not verifying no need to continue.
      // If we are not a single file this will not work not all files contain all images will get bad results otherwise.
      return
    }

    // Get the root path to the project so we can search
    var rootPath = searchPath
    if let newRootPath = ListGeneratorHelper.runStringAsCommand("echo \"$SRCROOT\"") {
      rootPath = newRootPath
    }
    if rootPath == nil {
      return
    }

    // Extensions
    var includeExtensionsString = ""
    for nextExtension in ["storyboard", "xib"] {
      includeExtensionsString.append(" --include=*.\(nextExtension)")
    }

    // Command to find results
    let command = "grep -i -r\(includeExtensionsString) \"<namedColor name=\\\"*\\\"\" \"\(rootPath!)\""
    if var result = ListGeneratorHelper.runStringAsCommand(command) {
      // Filter the Results
      var filteredResults: [String] = []
      let results = result.components(separatedBy: "\n")
      for nextResult in results {
        // Remove any result that is in the pods directory we most likely won't have the images for it.
        if !nextResult.hasPrefix((rootPath! as NSString).appendingPathComponent("Pods")) {
          filteredResults.append(nextResult)
        }
      }
      result = filteredResults.joined(separator: "\n")

      // Find the missing images
      var hasMissingImage = false
      do {
        let regex = try NSRegularExpression(pattern: "<namedColor name=\".*?\"", options: NSRegularExpression.Options())
        let regexMatches = regex.matches(in: result, options: NSRegularExpression.MatchingOptions(), range: NSMakeRange(0, result.count))
        for nextMatch in regexMatches {
          let fullString = (result as NSString).substring(with: nextMatch.range(at: 0))
          let colorName = (fullString as NSString).substring(with: NSMakeRange(18, (fullString.count - 19)))

          // Generate Method for file if we don't have the image in our list
          if !allColors.contains(colorName) {
            let methodName = ListGeneratorHelper.methodName(colorName)
            var implementation = ""
            if swift {
              implementation.append("  /// \(colorName) is in a Storyboard or Nib but is not in assets files most likely removed.\n")
              implementation.append("  private var \(methodName): UIColor? {\n")
              implementation.append("    MissingColor()\n")
              implementation.append("    return nil\n")
              implementation.append("  }\n\n")
            } else {
              implementation.append("/// \(colorName) is in a Storyboard or Nib but is not in assets files most likely removed.\n")
              implementation.append("+ (UIColor *)\(methodName) {\n")
              implementation.append("  #warning Missing Color\n")
              implementation.append("  return nil\n")
              implementation.append("}\n\n");
            }
            fileWriter.outputMethods.append(implementation)

            hasMissingImage = true
          }
        }
      } catch {}

      // Add Warning Message to output file for swift files
      if hasMissingImage && swift {
        var missingImageMessage = ""
        missingImageMessage.append("  /// Warning message so console is notified.\n")
        missingImageMessage.append("  @available(iOS, deprecated: 1.0, message: \"Missing Storyboard or Nib Custom Color\")\n")
        missingImageMessage.append("  private func MissingColor(){}\n\n")

        if fileWriter.warningMessage == nil {
          fileWriter.warningMessage = missingImageMessage
        } else  if !fileWriter.warningMessage!.contains("MissingColor") {
          fileWriter.warningMessage!.append(missingImageMessage)
        }
      }
    }
  }

}
