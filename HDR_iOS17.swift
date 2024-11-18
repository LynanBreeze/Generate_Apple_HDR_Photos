import Cocoa
import CoreImage
import AVFoundation

// Constants for command line arguments
struct CommandLineArguments {
    let path: String
    let compressionRatio: CGFloat
    let width: Any?
    let outputDir: String?
}

// Parses the command line arguments and returns a struct
func parseCommandLineArguments() -> CommandLineArguments {
    let arguments = CommandLine.arguments
    let path = arguments.count > 1 ? arguments[1] : "."
    let compressionRatio = arguments.count > 2 ? CGFloat(Double(arguments[2]) ?? 0.7) : 0.7
    let width = arguments.count > 3 ? arguments[3] : "original" 
    let outputDir = arguments.count > 4 ? arguments[4] : nil
    
    return CommandLineArguments(
        path: path,
        compressionRatio: compressionRatio,
        width: width,
        outputDir: outputDir
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

func processFile(_ filePath: String, compressionRatio: CGFloat, width: Any? = "original", outputDir: String? = nil) {
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
                    processSingleFile(file, context: context, colorSpace: colorSpace, compressionRatio: compressionRatio, width: width, outputDir: outputDir ?? inputURL.appendingPathComponent("converted").path)
                }
            }
        } catch {
            print("Failed to read contents of directory: \(error)")
            exit(1)
        }
    } else {
        // 处理单个文件
        processSingleFile(inputURL, context: context, colorSpace: colorSpace, compressionRatio: compressionRatio, width: width, outputDir: outputDir ?? inputURL.deletingLastPathComponent().appendingPathComponent("converted").path)
    }
}

private func processSingleFile(_ inputURL: URL, context: CIContext, colorSpace: CGColorSpace, compressionRatio: CGFloat, width: Any?, outputDir: String) {
    let fileManager = FileManager.default

    // 创建输出目录（如果不存在）
    let outputDirURL = URL(fileURLWithPath: outputDir)
    if !fileManager.fileExists(atPath: outputDirURL.path) {
        do {
            try fileManager.createDirectory(at: outputDirURL, withIntermediateDirectories: true, attributes: nil)
        } catch {
            print("Failed to create output directory: \(error)")
            return
        }
    }

    let outputURL = outputDirURL.appendingPathComponent(inputURL.deletingPathExtension().lastPathComponent).appendingPathExtension("jpg")
    print("\(inputURL.path) -> \(outputURL.path)")

    let fileExtension = inputURL.pathExtension.lowercased()
    var image: CIImage?

    if fileExtension == "raw" {
        guard let data = try? Data(contentsOf: inputURL),
              let rawImage = CIImage(data: data, options: [CIImageOption.applyOrientationProperty: true]) else {
            print("Couldn't create an image from RAW file \(inputURL.path).")
            return
        }
        image = rawImage
    } else {
        image = CIImage(contentsOf: inputURL, options: [.expandToHDR: true])
    }

    guard var finalImage = image else {
        print("Couldn't create an image from \(inputURL.path).")
        return
    }

    // 尝试将 width 转换为 CGFloat 数字，如果是字符串类型
    if let widthString = width as? String {
        if widthString.lowercased() == "original" {
            print("Using original dimensions for \(inputURL.lastPathComponent).")
        } else {
            // 尝试将字符串转换为 Double 类型，再转换为 CGFloat
            if let targetWidth = Double(widthString) {
                let finalWidth = CGFloat(targetWidth)
                print("Resizing image to width: \(finalWidth)")
                let scale = finalWidth / finalImage.extent.width
                finalImage = finalImage.transformed(by: CGAffineTransform(scaleX: scale, y: scale))
            } else {
                print("Invalid width parameter: \(widthString). Please use a valid number or 'original'.")
                return
            }
        }
    } else if let targetWidth = width as? CGFloat {
        print("Resizing image to width: \(targetWidth)")
        let scale = targetWidth / finalImage.extent.width
        finalImage = finalImage.transformed(by: CGAffineTransform(scaleX: scale, y: scale))
    } else {
        print("Invalid width parameter: \(String(describing: width)). Please use a number (CGFloat) or 'original'.")
        return
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
    
    processFile(args.path, compressionRatio: args.compressionRatio, width: args.width, outputDir: args.outputDir)
}

// Run the main function
main()
