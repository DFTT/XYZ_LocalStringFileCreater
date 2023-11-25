//
//  LSFileParser.swift
//  LocalStringFileCteater
//
//  Created by 大大东 on 2023/11/25.
//

import Cocoa
import CoreXLSX

class LSFileParser {
    private let xFile: XLSXFile
    private let sheetNamePathMap: [(name: String?, path: String)]
    private let allStrings: SharedStrings

    init?(xmlPath: String) {
        // 读文件
        guard let file = XLSXFile(filepath: xmlPath) else {
            print("Error: file not found~~~~")
            return nil
        }

        // 解析sheet索引
        guard let workBook = try? file.parseWorkbooks().first,
              let sheetNamePathMap = try? file.parseWorksheetPathsAndNames(workbook: workBook),
              let allStrings = try? file.parseSharedStrings()
        else {
            print("Error: workBook not found~~~~")
            return nil
        }

        self.xFile = file
        self.sheetNamePathMap = sheetNamePathMap
        self.allStrings = allStrings
    }

    // 解析
    func fire(headRowIdx: Int = 0,
              sheetName: String = "Sheet1",
              valueBeginColumnIdx: Int = 0,
              keyColumnIdx: Int = 0)
    {
        // 获取sheet
        guard sheetName.isEmpty == false else {
            print("Error: sheet name param error ~~~~")
            return
        }
        var workSheet: Worksheet?
        for (name, path) in sheetNamePathMap {
            guard name == sheetName else {
                continue
            }
            workSheet = try? xFile.parseWorksheet(at: path)
            break
        }
        guard let workSheet = workSheet else {
            print("Error: sheet parse fali ~~~~")
            return
        }

        // 获取所有行 (表头以下所有行)
        guard let rowsArr = workSheet.data?.rows, rowsArr.count > headRowIdx + 1 else {
            print("Error: rows count is error ~~~~")
            return
        }

        // 检测表头列数
        let columnsCount = rowsArr[headRowIdx].cells.count
        guard columnsCount > valueBeginColumnIdx + 1, columnsCount > keyColumnIdx else {
            print("Error: columens count is error ~~~~")
            return
        }

        var repeatKeyCout = 0

        // 第headRowIdx行做当做表头 第valueBeginColumnIdx列会当做国际化的key
        var resMap = [String: LanguageKVs]()
        // 取特殊cell
        let headRowKeyCell = rowsArr[headRowIdx].cells[keyColumnIdx]
        let headRowValueBeginCell = rowsArr[headRowIdx].cells[valueBeginColumnIdx]
        // 遍历列
        for columnIdx in valueBeginColumnIdx ..< columnsCount {
            // 列名
            let oneLineCell = rowsArr[headRowIdx].cells[columnIdx]
            let languageName = oneLineCell.stringValue(allStrings)!
            // 遍历行
            for row in rowsArr[headRowIdx + 1 ..< rowsArr.count] {
                // key
                /// 优先 取特殊key列
                var keyCell = ___cell(fromRow: row, seamColumnCell: headRowKeyCell)
                var key = ___textFor(cell: keyCell)
                if key.isEmpty {
                    /// 为空的话再取值的起始列
                    keyCell = ___cell(fromRow: row, seamColumnCell: headRowValueBeginCell)
                    key = ___textFor(cell: keyCell)
                }
                if key.isEmpty {
                    print("key 不能为空串, 见: \(keyCell!.reference.description)")
                }

                // value cell
                let valueCell = ___cell(fromRow: row, seamColumnCell: oneLineCell)
                let cellText = ___textFor(cell: valueCell!)
                if cellText.isEmpty {
                    print("value 不能为空串, 见: \(valueCell!.reference.description)")
                }

                // 存储
                let language = resMap[languageName] ?? LanguageKVs(title: languageName)
                /// 如果首列 判断下key重复
                if columnIdx == valueBeginColumnIdx, language.kvs[key] != nil {
                    print("发现重复的中文key: \(key)")
                    repeatKeyCout += 1
                }
                language.kvs[key] = KeyValueItem(key: key, value: cellText)
                resMap[languageName] = language
            }
        }
        // 解析完成
        print("""
            👏🏻👏🏻👏🏻解析完成!
                共\(1 + resMap.values.first!.kvs.count + repeatKeyCout)行 (1行表头),
                解析出\(resMap.count)种语言,
                每种语言\(resMap.values.first!.kvs.count)个key-Value,
                \(repeatKeyCout)个重复key \n\n
            """
        )

        // 打印出译文为empty的
        var eCount = 0
        resMap.forEach { _, language in
            language.kvs.forEach { _, value in
                if value.value.isEmpty {
                    print("\(language.title) 发现译文为空的key: \(value.key) \n      \(value.value)")
                    eCount += 1
                }
            }
        }
        if eCount > 0 {
            print("⚠️⚠️⚠️发现\(eCount)个key存在空译文 \n\n")
        }

        // 检查数量是否一致
        let cont = resMap.first!.value.kvs.count
        resMap.forEach { (key: String, value: LanguageKVs) in
            if value.kvs.count != cont {
                print("\n⚠️⚠️⚠️\(key) 的kv数量不等于 \(cont)\n")
            }
        }

        resMap.forEach { _, language in
            writeFile(language)
        }
    }

    func ___textFor(cell: Cell?) -> String {
        guard let cell = cell else { return "" }
        var text = cell.stringValue(allStrings) ?? ""
        text = text.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines)
        text = text.replacingOccurrences(of: "\n", with: "\\n")
        // 可能是富文本
        if text.isEmpty {
            let richArr: [RichText] = cell.richStringValue(allStrings)
            if richArr.isEmpty == false {
                text = (richArr.compactMap { $0.text } as [String]).joined()
                text = text.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines)
                text = text.replacingOccurrences(of: "\n", with: "\\n")
            }
        }
        return text
    }

    func ___cell(fromRow: Row, seamColumnCell: Cell) -> Cell? {
        // (这种找法更精准, 防止每行的cells数量不相等)
        var tCell: Cell?
        for cell in fromRow.cells {
            if cell.reference.column == seamColumnCell.reference.column {
                tCell = cell
                break
            }
        }
        return tCell
    }

    // 写文件
    private func writeFile(_ language: LanguageKVs) {
        let fileManager = FileManager.default
        guard let fileName = ios_stringFileName(withKey: language.title) else {
            print("⚠️⚠️⚠️ 文件名配置缺失 :\(language.title) \n\n")
            return
        }

        // 排序 拼接
        var contentString = language.kvs.sorted { $0.0 < $1.0 }.map { "\"\($0)\" = \"\($1.value)\";" }.joined(separator: "\n")
        contentString.append("\n")

        // 写到下载目录
        let pathURL = fileManager.homeDirectoryForCurrentUser.appendingPathComponent("Downloads/outStringFiles/\(fileName)")
        guard (try? fileManager.createDirectory(at: pathURL.deletingLastPathComponent(), withIntermediateDirectories: true, attributes: nil)) != nil else {
            print("ERROR: 创建文件夹失败 ...")
            return
        }
        if (try? contentString.write(to: pathURL, atomically: true, encoding: .utf8)) != nil {
            print("创建 \(language) 文件成功 : \(pathURL)")
        }
    }

    private func ios_stringFileName(withKey key: String) -> String? {
        let map = ["简体中文": "zh-Hans.lproj/UNLocalizable.strings",
                   "英语": "en.lproj/UNLocalizable.strings",
                   "泰语": "th.lproj/UNLocalizable.strings",
                   "越南语": "vi.lproj/UNLocalizable.strings"]
        return map[key]
    }
}

private struct KeyValueItem {
    let key: String
    let value: String
}

private class LanguageKVs {
    let title: String
    var kvs = [String: KeyValueItem]()
    init(title: String) {
        self.title = title
    }
}
