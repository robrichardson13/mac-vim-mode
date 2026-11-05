import Foundation

/// Lengths, ranges and command keys only: typed message text must never reach this file.
enum Log {
  static let path = "/tmp/vim-mode.log"

  private static let file: FileHandle? = {
    FileManager.default.createFile(atPath: path, contents: nil)
    return FileHandle(forWritingAtPath: path)
  }()

  static func write(_ line: String) {
    print(line)
    file?.write(Data((line + "\n").utf8))
  }
}
