import Cocoa
import CoreImage

// Constants for command line arguments
struct CommandLineArguments {
    let path: String
    let compressionRatio: CGFloat
}

// Parses the command line arguments and returns a struct
func parseCommandLineArguments() -> CommandLineArguments {
    let arguments = CommandLine.arguments
    let path = arguments.count > 1 ? arguments[1] : "."
    let compressionRatio = arguments.count > 2 ? CGFloat(Double(arguments[2]) ?? 0.7) : 0.7
    
    return CommandLineArguments(
        path: path,
        compressionRatio: compressionRatio
    )
}

// Function to check if the path is a directory and process accordingly
func processPath(_ path: String, compressionRatio: CGFloat) {
    let fileManager = FileManager.default
    var isDirectory: ObjCBool = false

    let imageExtensions = [".avif"]

    if fileManager.fileExists(atPath: path, isDirectory: &isDirectory) {
        if isDirectory.boolValue {
            // It's a directory, process all non-heic files
            do {
                let files = try fileManager.contentsOfDirectory(atPath: path)
                for file in files {
                    let filePath = (path as NSString).appendingPathComponent(file)
                    if imageExtensions.contains(where: file.hasSuffix) {
                        processFile(filePath, compressionRatio: compressionRatio)
                    }
                }
            } catch {
                print("Error reading contents of directory: \(error)")
            }
        } else {
            // It's a file, process the single file
            processFile(path, compressionRatio: compressionRatio)
        }
    } else {
        print("The provided path does not exist.")
    }
}

// Function to process a single file
func processFile(_ filePath: String, compressionRatio: CGFloat) {
    guard let colorSpace = CGColorSpace(name: CGColorSpace.itur_2100_HLG) else {
        print("Couldn't create a color space.")
        exit(1)
    }
    let context = CIContext(options: [.workingColorSpace: colorSpace])

    let inputURL = URL(fileURLWithPath: filePath)
    let outputURL = inputURL.deletingPathExtension().appendingPathExtension("jpg")

    print(inputURL.path, " -> ", outputURL.path)

    guard let image = CIImage(contentsOf: inputURL, options: [.expandToHDR: true]) else {
        print("Couldn't create an image from \(inputURL.path).")
        exit(1)
    }

    let options = [kCGImageDestinationLossyCompressionQuality as CIImageRepresentationOption: compressionRatio]
    do {
        try context.writeJPEGRepresentation(of: image, to: outputURL, colorSpace: image.colorSpace!, options: options)
    } catch {
        print("Failed to write the image with error: \(error)")
        exit(1)
    }
}

// Main function to execute the conversion process
func main() {
    let args = parseCommandLineArguments()
    
    guard !args.path.isEmpty else {
        print("Usage: <path> [compressionRatio]")
        return
    }
    
    processPath(args.path, compressionRatio: args.compressionRatio)
}

// Run the main function
main()
