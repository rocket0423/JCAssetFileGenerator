//
//  ImagesList.swift
//  ImagesList
//
//  Created by Justin Carstens on 10/11/17.
//  Copyright © 2017 BitSuties. All rights reserved.
//

import Foundation

class ImagesList: ListGeneratorHelper {
    
    var allImages: [String] = []
    var usedImageString = ""
    
    override class func fileExtensions() -> [String] {
        return ["xcassets"]
    }
    
    override class func newHelper() -> ListGeneratorHelper {
        return ImagesList()
    }
    
    override func startGeneratingInfo() {
        // Get the file name with prefix and any additional info.
        var fileName = ""
        if !singleFile {
            fileName = ((parseFilePath as NSString).lastPathComponent as NSString).deletingPathExtension
        }
        fileWriter.outputFileName = classPrefix + "\(fileName)Images"
        
        // Generate the helper string to find used images.
        findUsedImages()
        
        // Image Files
        if let enumerator = FileManager.default.enumerator(atPath: parseFilePath) {
            for url in enumerator {
                if (url as! String).hasSuffix(".imageset") {
                    writeImageToFile(((url as! NSString).lastPathComponent as NSString).deletingPathExtension)
                }
            }
        }
    }
    
    override func finishedGeneratingInfo() {
        // Check to see if we have any missing images
        findMissingImages()
    }
    
    private func writeImageToFile(_ imageName: String) {
        let methodName = ListGeneratorHelper.methodName(imageName)
        allImages.append(imageName)
        
        // Generate Method for file
        if swift {
            var implementation = ""
            implementation.append("    /// \(imageName) Image\n")
            implementation.append("    static var \(methodName): UIImage? {\n")
            if !isUsedImage(imageName, method: methodName) {
                implementation.append("        ImageNotUsed()\n")
            }
            implementation.append("        return UIImage(named: \"\(imageName)\")\n")
            implementation.append("    }\n\n")
            fileWriter.outputMethods.append(implementation)
        } else {
            // Setup Method
            var method = "/// \(imageName) Image\n"
            method.append("+ (UIImage *)\(methodName)")
            
            // Add Method to both m and h files with appropriate endings.
            var implementation = method;
            method.append(";\n")
            implementation.append(" {\n")
            
            // Add additional info for method
            if !isUsedImage(imageName, method: methodName) {
                implementation.append("    #warning Image Not Used\n")
            }
            implementation.append("    return [UIImage imageNamed:@\"\(imageName)\"];\n")
            implementation.append("}\n\n")
            
            // Add Header and Method to file writer
            fileWriter.outputHeaders.append(method)
            fileWriter.outputMethods.append(implementation)
        }
    }
    
    private func findUsedImages() {
        if !verify || !usedImageString.isEmpty {
            // We are not verifying used images or we have already done the searching.
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
        for nextExtension in ["swift", "m", "storyboard", "xib", "html", "css"] {
            includeExtensionsString.append(" --include=*.\(nextExtension)")
        }
        
        // Patterns
        var commandPatterns = ""
        commandPatterns.append(" -e \"image=\\\"*\\\"\"")
        commandPatterns.append(" -e \"Images\\.*\"")
        commandPatterns.append(" -e \"Images *\"")
        
        // Command to get results
        let command = "grep -i -r\(includeExtensionsString)\(commandPatterns) \"\(rootPath!)\""
        if let result = ListGeneratorHelper.runStringAsCommand(command) {
            usedImageString = result
        }
    }
    
    private func isUsedImage(_ image: String, method: String) -> Bool {
        if !verify {
            // We are not verifying so just return true
            return true
        } else if usedImageString.contains("image=\"\(image)\"") {
            return true
        } else if usedImageString.contains("Images.\(method)") {
            return true
        }
        
        if swift {
            // Add Warning Message to output file only needed for swift
            var notUsedMessage = ""
            notUsedMessage.append("    /// Warning message so console is notified.\n")
            notUsedMessage.append("    @available(iOS, deprecated: 1.0, message: \"Image Not Used\")\n")
            notUsedMessage.append("    private class func ImageNotUsed(){}\n\n")
            
            if fileWriter.warningMessage == nil {
                fileWriter.warningMessage = notUsedMessage
            } else  if !fileWriter.warningMessage!.contains("ImageNotUsed") {
                fileWriter.warningMessage!.append(notUsedMessage)
            }
        }
        
        // Not found return false and add the image not used function to file
        return false
    }
    
    private func findMissingImages() {
        if !verify || !singleFile {
            // If we are not verifying no need to continue
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
        let command = "grep -i -r\(includeExtensionsString) \"image=\\\"*\\\"\" \"\(rootPath!)\""
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
                let regex = try NSRegularExpression(pattern: "image=\".*?\"", options: NSRegularExpression.Options())
                let regexMatches = regex.matches(in: result, options: NSRegularExpression.MatchingOptions(), range: NSMakeRange(0, result.count))
                for nextMatch in regexMatches {
                    let fullString = (result as NSString).substring(with: nextMatch.range(at: 0))
                    let imageName = (fullString as NSString).substring(with: NSMakeRange(7, (fullString.count - 8)))
                    
                    // Generate Method for file if we don't have the image in our list
                    if !allImages.contains(imageName) {
                        let methodName = ListGeneratorHelper.methodName(imageName)
                        var implementation = ""
                        if swift {
                            implementation.append("    /// \(imageName) is in a Storyboard or Nib but not in assets files\n")
                            implementation.append("    private var \(methodName): UIImage? {\n")
                            implementation.append("        MissingImage()\n")
                            implementation.append("        return nil\n")
                            implementation.append("    }\n\n")
                        } else {
                            implementation.append("/// \(imageName) is in a Storyboard or Nib but not in assets files\n")
                            implementation.append("+ (UIImage *)\(methodName) {\n")
                            implementation.append("    #warning Missing Image\n")
                            implementation.append("    return nil;\n")
                            implementation.append("}\n\n")
                        }
                        fileWriter.outputMethods.append(implementation)
                        
                        hasMissingImage = true
                    }
                }
            } catch {}
            
            // Add Warning Message to output file only needed for swift
            if hasMissingImage && swift {
                var missingImageMessage = ""
                missingImageMessage.append("    /// Warning message so console is notified.\n")
                missingImageMessage.append("    @available(iOS, deprecated: 1.0, message: \"Missing Storyboard or Nib Image\")\n")
                missingImageMessage.append("    private func MissingImage(){}\n\n")
                
                if fileWriter.warningMessage == nil {
                    fileWriter.warningMessage = missingImageMessage
                } else  if !fileWriter.warningMessage!.contains("MissingImage") {
                    fileWriter.warningMessage!.append(missingImageMessage)
                }
            }
        }
    }
}
