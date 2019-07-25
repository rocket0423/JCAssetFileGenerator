Assets File Generator for iOS
================================

A series of executables to help manage the names of Images, Fonts, Colors, Strings, and Identifiers.  No longer do you have to worry about typing the name of a file incorectly or worry about removing a file and have there still be remnant useges in the code.  These executables help with this the same way Android manages it with the R.string R.image format.  We crate files for each asset type and instead of typing in the name of the asset you use the file to refrence it directly.  If the asset is removed it is removed from the files and any where it is used throws an error since it no longer exists preventing any mistakes.

## Project Installation ##

##### Installation #####

Installation can be done 2 ways

- Installation through adding the executables to your project.

This method is simple and works by simply copying the latest executables in the /Executables folder to your project 

- Installation through Cocoapods.

Installation is handled using Cocoapods. While the executables are added through cocopods they are not added to the app just made available.

`pod 'JCAssetFileGenerator', :git => "https://github.com/rocket0423/JCAssetFileGenerator.git"`


This will point to the head of the Asset File Generator repository and will grab any changes as necessary when a `pod update` command is issued.

##### Run Script #####

1. Add Run Script in Build Phases to each Target of your project that needs these files.
2. Move the Run Script above Compile Sources so that all changes will be in each build.
3. Add the Script for generating the files here is a simple example with the installation point Cocoapods.
4. On first instance of creating the files add them to the project.

```Shell
GENERATED_FOLDER="$SRCROOT/Classes/Generated"
EXECUTABLE_FOLDER="$SRCROOT/Pods/BJCssetFileGenerator/Executables"

rm -rf "$GENERATED_FOLDER"
mkdir -p "$GENERATED_FOLDER"

"$EXECUTABLE_FOLDER/AssetFiles" -o "$GENERATED_FOLDER"
```

## Executable Command Line Options
```Shell
Usage: AssetFiles [-s <path>] [-o <path>] [-i <path>] [-v <version>] [-p <prefix>] [-m] [-dnverify] [-dnhelp] [-objc] [-colors] [-fonts] [-images] [-identifiers] [-strings]
    ExecutableName -h
Options:
    -s <path>    Search for folders starting from <path> (Default is Project Source Directory)
    -o <path>    Output files at <path> (Default is Project Source Directory)
    -i <path>    Info Plist file at <path> (Default Attempts to retrieve from Project)
    -v <version> Minimum app version supported <version> (Default Attempts to retrieve from Project)
    -p <prefix>  Use <prefix> as the class prefix in the generated code
    -m           Generates each source in their own file (Default is to generate one file with content from all sources)
    -dnverify    Do not verify any of the code (Default is to always verify)
    -dnhelp      Do not execute any of the helper code (Default is to always execute the helper code)
    -objc        Write the file in Objective C (Default is to write in swift)
    -colors      Write the colors file (Default is to do all files selecting this disables all others not in arguments)
    -fonts       Write the fonts file (Default is to do all files selecting this disables all others not in arguments)
    -images      Write the images file (Default is to do all files selecting this disables all others not in arguments)
    -identifiers Write the identifiers file (Default is to do all files selecting this disables all others not in arguments)
    -strings     Write the strings file (Default is to do all files selecting this disables all others not in arguments)
    -h           Print this help and exit
```

## ImagesList ##
##### Usage #####
This executable goes through all your 'xcassets' folders and finds all the images and creates a variable to reference them.

For example an image name `MyGoodImage` will be created into a variable that can be accessed by `Images.myGoodImage`.

If this image is removed from the 'xcassets' folder it is removed from the source and any attempt to access it will through an error.

##### Verify #####
This executable does 2 types of verifyication ImageUsed and ImageMissing.

For ImageUsed it checks all the files in the Source Directory to see if the images are used anywhere. If they are not it adds a compiler warning to the image so you will no that it isn't being used. This helps in having dead images in your app taking up memory.

For ImageMissing this only checks in single file mode (Default Mode). This goes through the 'storyboard' and 'xib' files looking for images that are there but not in the 'xcassets' folders. If it finds an image that is missing it creates a private function that can't be accessed by anyone and throws a compiler warning to let you know that you are missing an image and its name. This is helpful in large storyboards to know if there is an image that was accidentaly deleted but is still needed.


## StoryboardIdentifiersList ##
##### Usage #####
This executable goes through all you 'storyboard' and 'xib' files and finds all the Identifiers in them and creates references to them.

For example a storyboard table cell resuse identifier with name `MyTableCell` will be created into a variable that can be accessed by `Identifiers.MyTableCell`.

If this identifier is removed from the 'storyboard' file it is removed from the source and any attempt to access it will throw an error.

##### Verify #####
This executable does 1 type of verification Duplicate Identifier Check.

For the Duplicate Identifier check it makes sure each identifier is only used once and if it is used more than once it adds all that use it creating an error since we can't have multiple variables with the same name. This can be turned of by adding the `-dnverify` to the shell script but this is not recommended. In order for the best error catching there should be only one identifer for each name this prevensts issues that if you remove an identifer but there is another with the same name you don't forget to remove the identifier, because with only one it would throw an error if not removed.

## StringsLocalizedList ##
##### Usage #####
This executable goes through all your 'strings' files and finds all the strings and creates a variable to reference them. The executable intelengatly creates variables that refrence the localization file or just create a string based on wether the string is localized in other languages or not.

For example a string with format `"login_signin" = "Sign In";` will be created into a variable that can be accessed by `Strings.login_signin`.

If a string is removed from the 'strings' file it is removed from the souce and any attempt to access it will throw an error.

##### Verify #####

This executable does 2 type of verifications for NeedsTranslation Check and TranslationUsed.

For the NeedsTranslation check it checks through all the translation files to see if the translation is missing or is labeled with the the text '// Needs Translation'. Any string that meets these criteria will display a compiler warning letting you know translations need to be added for it.

For the TranslationUsed check it checks through all the .m and .swift files to see if the string is used in the "Strings." format. Any string that meets these criteria will display a compiler warning letting you know the string isn't being used and can be removed.

##### Helpers #####
A helper this executable does is for localized strings in other languages it updates all the other languages to the base language.
If the string is removed it is removed from all other language files as well.
If a string is added and there is no translation it creates a new file in the output directory for the file and language for all missing translations and what their english counterparts are.


## ColorList ##
##### Usage #####
This executable goes through all you 'colors' and 'xcassets' files and finds all the Colors in them and creates references to them.

For example in 'colors' files with format `"main" = "2a2a2a";` will be created into a variable that can be accessed by `Colors.main`.

For example in 'xcassets' files with name `MyColor` will be created into a variable that can be accessed by `Colors.myColor`.

If a color is removed from the 'colors' or 'xcassets' file it is removed from the souce and any attempt to access it will throw an error.

##### Verify #####
This executable does 3 types of verification for InvalidColor Check, MissingColor Check, PreiOS11 Check.

For the InvalidColor it checks 'colors' files for the correct format and if it isn't correct it creates a private function that can't be accessed with a compiler warning letting everyone know it is invalid. If the verify is off it will not add this to the file since we can't create it.

For the MissingColor check this only checks in single file mode (Default Mode). This goes through the 'storyboard' and 'xib' files looking for colors that are there but not in the 'xcassets' folders. If it finds a color that is missing it creates a private function that can't be accessed by anyone and throws a compiler warning to let you know that you are missing a color and its name. This is helpful in large storyboards to know if there is a color that was accidentaly deleted but is still needed.

For the PreiOS11 check it searches through the 'storyboard' and 'xib' files to see if the colors are being used. If so and this is Pre iOS 11 supported ap we thow an error because apps that are running on devices older than iOS 11 will crash since this isn't supported.

## CustomFontList ##
##### Usage #####
This executable goes through all you 'ttf' font files and finds the name of the font and creates references to them.

For Example for 'ttf' file name `tracfk.ttf` it will extract the name from the file and create a function from the font name that can be accessed by `traceFontforKidsFontOfSize(_ fontSize : CGFloat)`.

If a font is removed from the project folder it is removed from the souce and any attempt to access it will throw an error.

##### Verify #####
This executable does 1 type of verification for Duplicate Font Check.

For the Duplicate Font Check it will write all fonts to the file even if there are multiple with the same smae therfore throwing an error. If you turn this off it will check to make sure there is only one of each font. Had some issues of the same font being in the app twice once in project and in pods.

##### Helpers #####
A helper this class executes is adding the font name to the info plist file. In order for a font to work in an app it needs to be in the info plist so if we have a valid plist we will add the font if it doesn't already exist preventing the issue of forgetting to add it to the plist.

## License

[JCAssetFileGenerator](https://github.com/Rocket0423/JCAssetFileGenerator) was created by Justin Carstens and released under a [MIT License](License).

