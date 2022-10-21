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
        guard let filePath = Bundle.main.path(forResource: "RowStringFile", ofType: "xlsx"),
              let file = XLSXFile(filepath: filePath)
        else {
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
        
        // TODO: 这里默认只读取第一个sheet 请根据实际情况修改
        let targetSheetName = workBook.sheets.items.first?.name
        
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
        
        // 获取列数
        guard let columnsCount = workSheet.columns?.items.count, columnsCount > 0 else {
            print("Error: sheet number of columen is 0 ~~~~")
            return
        }
        
        guard let rowsArr = workSheet.data?.rows, !rowsArr.isEmpty else {
            print("Error: sheet number of row is 0 ~~~~")
            return
        }
        
        var repeatKeyCout = 0
        
        // 第一行做当做表头 第一列会当做国际化的key
        var resMap = [String: [String: String]]()
        for columnIdx in 0 ..< min(columnsCount, rowsArr.first?.cells.count ?? columnsCount) {
            let oneLinecCell = rowsArr.first!.cells[columnIdx]
            // 表头
            let title = oneLinecCell.stringValue(allStrings)!
            
            rowsArr[1 ..< rowsArr.count].forEach { row in
                // key
                let keyCell = row.cells.first!
                var key = keyCell.stringValue(allStrings) ?? ""
                key = key.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines)
                key = key.replacingOccurrences(of: "\n", with: "\\n")
                if key.isEmpty { print("key 不能为空串, 见: \(keyCell.reference.description)") }
                
                // 当前cell (这种找法更精准, 防止每行的cells数量不相等)
                var targetCell: Cell?
                for cell in row.cells {
                    if cell.reference.column == oneLinecCell.reference.column {
                        targetCell = cell
                        continue
                    }
                }
                
                var cellText = targetCell?.stringValue(allStrings) ?? ""
                cellText = cellText.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines)
                cellText = cellText.replacingOccurrences(of: "\n", with: "\\n")
            
                // 存储
                var map = resMap[title] ?? [String: String]()
                if columnIdx == 0, map[key] != nil {
                    print("发现重复的中文key: \(key)")
                    repeatKeyCout += 1
                }
                map[key] = cellText
                resMap[title] = map
            }
        }
        // 解析完成
        print("👏🏻👏🏻👏🏻解析完成! 共\(resMap.count)种语言, 共\(1 + resMap.values.first!.count + repeatKeyCout)行, \(resMap.values.first!.count)个k-v, \(repeatKeyCout)个重复key \n\n")
        
        // 打印出译文为empty的
        var valueEmptyDatas = [String: [String]]()
        resMap.forEach { (okey: String, value: [String: String]) in
            value.forEach { (ikey: String, value: String) in
                if value.isEmpty {
                    var arr = valueEmptyDatas[ikey] ?? []
                    arr.append(okey)
                    valueEmptyDatas[ikey] = arr
                }
            }
        }
        valueEmptyDatas.forEach { (key: String, value: [String]) in
            print("发现译文为空的key: \(key) \n      \(value)")
        }
        print("⚠️⚠️⚠️发现\(valueEmptyDatas.count)个key存在空译文 \n\n")
        
        // 排序 & 转换
        let finalResArr = resMap.map { (key: String, value: [String: String]) -> (String, [(String, String)]) in
            let values = value.compactMap { ($0.key, $0.value) }
            return (key, values.sorted { $0.0 < $1.0 })
        }
     
        // 写文件
        let fileManager = FileManager.default
        finalResArr.forEach { language, kvTupleArr in
            let fileName = ios_stringFileName(withKey: language)!
            let defultMap = ios_defultConfig(key: language)!
            
            var string = defultMap.map { "\"\($0)\" = \"\($1)\";" }.joined(separator: "\n")
            string.append("\n")
            string.append(kvTupleArr.map { "\"\($0)\" = \"\($1)\";" }.joined(separator: "\n"))
            
            let pathURL = fileManager.homeDirectoryForCurrentUser.appendingPathComponent("Downloads/outStringFiles/\(fileName)")
            
            guard (try? fileManager.createDirectory(at: pathURL.deletingLastPathComponent(), withIntermediateDirectories: true, attributes: nil)) != nil else {
                print("ERROR: 创建文件夹失败 ...")
                return
            }
            if (try? string.write(to: pathURL, atomically: true, encoding: .utf8)) != nil {
                print("创建 \(language) 文件成功 : \(pathURL)")
            }
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
        let map = ["中文": "zh-Hans.lproj/TKLocalizable.strings",
                   "英文": "en.lproj/TKLocalizable.strings",
                   "马来语": "ms-MY.lproj/TKLocalizable.strings",
                   "印尼语": "id.lproj/TKLocalizable.strings",
                   "菲律宾语": "fil.lproj/TKLocalizable.strings"]
        return map[key]
    }
}
