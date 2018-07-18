//
//  CustomFontList.swift
//  CustomFontList
//
//  Created by Justin Carstens on 10/11/17.
//  Copyright © 2017 BitSuties. All rights reserved.
//

import Foundation

class CustomFontList: ListGeneratorHelper {

    var keys: [String] = []
    
    override class func fileExtensions() -> [String] {
        return ["ttf"]
    }
    
    override class func newHelper() -> ListGeneratorHelper {
        return CustomFontList()
    }
    
    override func startGeneratingInfo() {
        // Get the file name with prefix and any additional info.
        var fileName = ""
        if !singleFile {
            fileName = ListGeneratorHelper.capitalizedString(((parseFilePath as NSString).lastPathComponent as NSString).deletingPathExtension)
        }
        fileWriter.outputFileName = classPrefix + "\(fileName)Fonts"
    
        if let fontName = fontName() {
            let methodName = ListGeneratorHelper.methodName(fontName)
            // Add if we haven't added already or if we are in verify mode always add so it will show the error.
            if verify || !keys.contains(methodName) {
                keys.append(methodName)
                
                // Generate Method For File
                if swift {
                    var implementation = ""
                    implementation.append("    /// \(fontName) Font\n")
                    implementation.append("    class func \(methodName)FontOfSize(_ fontSize : CGFloat) -> UIFont? {\n")
                    implementation.append("        return UIFont(name: \"\(fontName)\", size: fontSize)\n")
                    implementation.append("    }\n\n")
                    fileWriter.outputMethods.append(implementation)
                } else {
                    // Setup Method
                    var method = "/// \(fontName) Font\n"
                    method.append("+ (UIFont *)\(methodName)FontOfSize:(CGFloat)fontSize")
                    
                    // Add Method to both m and h files with appropriate endings.
                    var implementation = method;
                    method.append(";\n")
                    implementation.append(" {\n")
                    
                    // Add additional info for method
                    implementation.append("    return [UIFont fontWithName:@\"\(fontName)\" size:fontSize];\n")
                    implementation.append("}\n\n")
                    
                    // Add Header and Method to file writer
                    fileWriter.outputHeaders.append(method)
                    fileWriter.outputMethods.append(implementation)
                }
                
                // Add the Font to the Info Plist if missing and helper is turned on
                if helper && infoPlist != nil {
                    if var infoPlistDictionary = NSDictionary(contentsOfFile: infoPlist!) as? [String : Any] {
                        // Find Current Fonts
                        let fontKey = "UIAppFonts"
                        var fontList: [String] = []
                        if let currentList = infoPlistDictionary[fontKey] as? [String] {
                            fontList = currentList
                        }
                        
                        // Add the new font and save to the plist
                        let fontFile = (parseFilePath as NSString).lastPathComponent
                        if !fontList.contains(fontFile) {
                            fontList.append(fontFile)
                            infoPlistDictionary[fontKey] = fontList
                            (infoPlistDictionary as NSDictionary).write(toFile: infoPlist!, atomically: true)
                        }
                    }
                }
            }
        }
    }
    
    private func fontName() -> String? {
        if let dataProvider = CGDataProvider(url: URL(fileURLWithPath: parseFilePath) as CFURL) {
            if let fontRef = CGFont(dataProvider) {
                let fontCore = CTFontCreateWithGraphicsFont(fontRef, 30, nil, nil)
                return CTFontCopyPostScriptName(fontCore) as String
            }
        }
        return nil
    }
}
