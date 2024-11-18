import Cocoa
import CoreImage
import AVFoundation

// Constants for command line arguments
struct CommandLineArguments {
    let path: String
    let compressionRatio: CGFloat
    let width: CGFloat?
}

// Parses the command line arguments and returns a struct
func parseCommandLineArguments() -> CommandLineArguments {
    let arguments = CommandLine.arguments
    let path = arguments.count > 1 ? arguments[1] : "."
    let compressionRatio = arguments.count > 2 ? CGFloat(Double(arguments[2]) ?? 0.7) : 0.7
    let width = arguments.count > 3 ? CGFloat(Double(arguments[3]) ?? 0.0) : nil
    
    return CommandLineArguments(
        path: path,
        compressionRatio: compressionRatio,
        width: width
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

func processFile(_ filePath: String, compressionRatio: CGFloat, width: CGFloat? = nil) {
    guard let colorSpace = CGColorSpace(name: CGColorSpace.sRGB) else {
        print("Couldn't create a color space.")
        exit(1)
    }
    let context = CIContext(options: [.workingColorSpace: colorSpace])

    let fileManager = FileManager.default
    let inputURL = URL(fileURLWithPath: filePath)

    // 检查是否是文件夹
    var isDirectory: ObjCBool = false
    if fileManager.fileExists(atPath: inputURL.path, isDirectory: &isDirectory), isDirectory.boolValue {
        // 批量处理文件夹中的图片文件
        do {
            let files = try fileManager.contentsOfDirectory(at: inputURL, includingPropertiesForKeys: nil, options: [])
            for file in files {
                let ext = file.pathExtension.lowercased()
                if ["jpg", "jpeg", "png", "raw", "tiff", "bmp", "heic", "dng", "arw"].contains(ext) {
                    processSingleFile(file, context: context, colorSpace: colorSpace, compressionRatio: compressionRatio, width: width)
                }
            }
        } catch {
            print("Failed to read contents of directory: \(error)")
            exit(1)
        }
    } else {
        // 处理单个文件
        processSingleFile(inputURL, context: context, colorSpace: colorSpace, compressionRatio: compressionRatio, width: width)
    }
}

private func processSingleFile(_ inputURL: URL, context: CIContext, colorSpace: CGColorSpace, compressionRatio: CGFloat, width: CGFloat?) {
    let outputURL = inputURL.deletingPathExtension().appendingPathExtension("jpg")
    print("\(inputURL.path) -> \(outputURL.path)")

    let fileExtension = inputURL.pathExtension.lowercased()
    var image: CIImage?

    if fileExtension == "raw" {
        // 读取 RAW 文件的适配逻辑
        guard let data = try? Data(contentsOf: inputURL),
              let rawImage = CIImage(data: data, options: [CIImageOption.applyOrientationProperty: true]) else {
            print("Couldn't create an image from RAW file \(inputURL.path).")
            return
        }
        image = rawImage
    } else {
        // 处理非 RAW 文件
        image = CIImage(contentsOf: inputURL, options: [.expandToHDR: true])
    }

    guard var finalImage = image else {
        print("Couldn't create an image from \(inputURL.path).")
        return
    }

    // 图片缩放逻辑（仅当指定 width 时进行缩放）
    if let targetWidth = width {
        let scale = targetWidth / finalImage.extent.width
        finalImage = finalImage.transformed(by: CGAffineTransform(scaleX: scale, y: scale))
    }

    // 保存压缩后的 JPEG 文件
    let options = [kCGImageDestinationLossyCompressionQuality as CIImageRepresentationOption: compressionRatio]
    do {
        try context.writeJPEGRepresentation(of: finalImage, to: outputURL, colorSpace: finalImage.colorSpace ?? colorSpace, options: options)
    } catch {
        print("Failed to write the image with error: \(error)")
    }
}

// Main function to execute the conversion process
func main() {
    let args = parseCommandLineArguments()
    
    guard !args.path.isEmpty else {
        print("Usage: <path> [compressionRatio]")
        return
    }
    
    processFile(args.path, compressionRatio: args.compressionRatio, width:args.width)
}

// Run the main function
main()
