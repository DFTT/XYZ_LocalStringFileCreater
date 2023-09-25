//
//  ViewController.swift
//  LocalStringFileCteater
//
//  Created by 大大东 on 2021/9/14.
//

import Cocoa
import CoreXLSX

class ViewController: NSViewController {
    override func viewDidLoad() {
        super.viewDidLoad()

        // 1. 将需要解析的excel文件替换工程中的文件RowStringFile.xlsx(第一行需要是表头, 第一列是key)

        // 2. 运行本程序

        // 3. 查看生成的文件(~/Downloads/outStringFiles/)  拖动生成的文件夹到原项目中覆盖全部即可

        // 读文件
//        guard let filePath = Bundle.main.path(forResource: "RowStringFile", ofType: "xlsx") else {
//            print("Error: file not found~~~~")
//            return
//        }
//
        let filePath = "/Users/dadadongl/Desktop/11111.xlsx"

        fire(xmlPath: filePath,
//             sheetName: "iOS",
             headRowIdx: 0, keyColumnIdx: 0)
    }

    struct KeyValueItem {
        let key: String
        let value: String
    }

    class LanguageKVs {
        let title: String
        var kvs = [String: KeyValueItem]()
        init(title: String) {
            self.title = title
        }
    }

    func fire(xmlPath: String, sheetName: String = "Sheet1", headRowIdx: Int = 0, keyColumnIdx: Int = 0) {
        // 读文件
        guard let file = XLSXFile(filepath: xmlPath) else {
            print("Error: file not found~~~~")
            return
        }

        // 解析sheet索引
        guard let workBook = try? file.parseWorkbooks().first,
              let namePathMapArr = try? file.parseWorksheetPathsAndNames(workbook: workBook),
              let allStrings = try? file.parseSharedStrings()
        else {
            print("Error: workBook not found~~~~")
            return
        }

        let targetSheetName = sheetName.isEmpty == false ? sheetName : workBook.sheets.items.first!.name

        // 解析sheet数据
        var workSheet: Worksheet?
        for (name, path) in namePathMapArr {
            guard name == targetSheetName else {
                continue
            }
            workSheet = try? file.parseWorksheet(at: path)
            break
        }
        guard let workSheet = workSheet else {
            print("Error: sheet parse fali~~~~")
            return
        }

        // 获取行实例
        guard let rowsArr = workSheet.data?.rows, !rowsArr.isEmpty, rowsArr.count > headRowIdx + 1 else {
            print("Error: sheet number of row is 0 ~~~~")
            return
        }

        // 获取列数
        let columnsCount = rowsArr[headRowIdx].cells.count
        guard columnsCount > keyColumnIdx + 1 else {
            print("Error: sheet number of columen is 0 ~~~~")
            return
        }

        var repeatKeyCout = 0

        // 第headRowIdx行做当做表头 第keyColumnIdx列会当做国际化的key
        var resMap = [String: LanguageKVs]()
        // 遍历列
        for columnIdx in keyColumnIdx ..< columnsCount {
            // 列名
            let oneLinecCell = rowsArr[headRowIdx].cells[columnIdx]
            let title = oneLinecCell.stringValue(allStrings)!
            // 遍历行
            for row in rowsArr[headRowIdx + 1 ..< rowsArr.count] {
                // key
                let keyCell = row.cells[keyColumnIdx]
                var key = keyCell.stringValue(allStrings) ?? ""
                key = key.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines)
                key = key.replacingOccurrences(of: "\n", with: "\\n")
                if key.isEmpty { print("key 不能为空串, 见: \(keyCell.reference.description)") }

                // value cell (这种找法更精准, 防止每行的cells数量不相等)
                var targetCell: Cell?
                for cell in row.cells {
                    if cell.reference.column == oneLinecCell.reference.column {
                        targetCell = cell
                        continue
                    }
                }

                var cellText = targetCell?.stringValue(allStrings) ?? ""
                if cellText.isEmpty {
                    // 可能是富文本
                    if let arr = targetCell?.richStringValue(allStrings), arr.isEmpty == false {
                        cellText = (arr.compactMap { $0.text } as [String]).joined()
                    }
                }
                if cellText.isEmpty {
                    // 异常
                }

                cellText = cellText.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines)
                cellText = cellText.replacingOccurrences(of: "\n", with: "\\n")

                // 存储
                let language = resMap[title] ?? LanguageKVs(title: title)
                if columnIdx == keyColumnIdx, language.kvs[key] != nil {
                    print("发现重复的中文key: \(key)")
                    repeatKeyCout += 1
                }
                language.kvs[key] = KeyValueItem(key: key, value: cellText)
                resMap[title] = language
            }
        }
        // 解析完成
        print("👏🏻👏🏻👏🏻解析完成! 共\(resMap.count)种语言, 共\(1 + resMap.values.first!.kvs.count + repeatKeyCout)行, \(resMap.values.first!.kvs.count)个k-v, \(repeatKeyCout)个重复key \n\n")

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
                print("⚠️⚠️⚠️\(key) 的kv数量不等于 \(cont) \n\n")
            }
        }

        resMap.forEach { _, language in
            writeFile(language)
        }
    }

    private func writeFile(_ language: LanguageKVs) {
        // 写文件
        let fileManager = FileManager.default

//        let defultMap = ios_defultConfig(key: language)!
        // 排序 拼接
        var string = language.kvs.sorted { $0.0 < $1.0 }.map { "\"\($0)\" = \"\($1.value)\";" }.joined(separator: "\n")
        string.append("\n")
//        string.append(kvTupleArr.map { "\"\($0)\" = \"\($1)\";" }.joined(separator: "\n"))

        let fileName = ios_stringFileName(withKey: language.title)!
        let pathURL = fileManager.homeDirectoryForCurrentUser.appendingPathComponent("Downloads/outStringFiles/\(fileName)")

        guard (try? fileManager.createDirectory(at: pathURL.deletingLastPathComponent(), withIntermediateDirectories: true, attributes: nil)) != nil else {
            print("ERROR: 创建文件夹失败 ...")
            return
        }
        if (try? string.write(to: pathURL, atomically: true, encoding: .utf8)) != nil {
            print("创建 \(language) 文件成功 : \(pathURL)")
        }
    }

    private func ios_defultConfig(key: String) -> [String: String]? {
        let map = ["中文": ["LanguageShortName": "简体中文", "LanguageDisplayFlag": "🇨🇳"],
                   "英文": ["LanguageShortName": "English", "LanguageDisplayFlag": "🇬🇧"],
                   "马来语": ["LanguageShortName": "Bahasa Melayu", "LanguageDisplayFlag": "🇲🇾"],
                   "印尼语": ["LanguageShortName": "Bahasa Indonesia", "LanguageDisplayFlag": "🇮🇩"],
                   "菲律宾语": ["LanguageShortName": "Filipino", "LanguageDisplayFlag": "🇵🇭"]]
        return map[key]
    }

    private func ios_stringFileName(withKey key: String) -> String? {
        let map = ["简体中文": "zh-Hans.lproj/UNLocalizable.strings",
                   "英语": "en.lproj/UNLocalizable.strings",
                   "泰语": "th.lproj/UNLocalizable.strings",
                   "越南语": "vi.lproj/UNLocalizable.strings"]
        return map[key]
    }
}
