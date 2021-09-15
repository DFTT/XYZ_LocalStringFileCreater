//
//  ViewController.swift
//  LocalStringFileCteater
//
//  Created by 大大东 on 2021/9/14.
//

import Cocoa

class ViewController: NSViewController {
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // 1. 按列复制excel中的配置(第一行需要是表头) 粘贴到文件 RowStringFile -> RowStringFile
        
        // 2. 运行本程序
        
        // 3. 查看生成的文件(~/Desktop/outStringFiles/)  拖动生成的文件夹到原项目中覆盖全部即可
        
        // 读数据
        let filePath = Bundle.main.path(forResource: "RowStringFile", ofType: "")!
        guard let rowString = try? String(contentsOfFile: filePath) else {
            print("Error: rowString 配置为空-")
            return
        }
        let linesSeparater = "\n" // 按行解析
        var rowArr = rowString.components(separatedBy: linesSeparater)
        guard !rowArr.isEmpty else {
            print("Error: rowString 配置无效")
            return
        }
        let rowSeparater = "   " // 默认是一个tab符号
        let firtHeadArr = rowArr.removeFirst().components(separatedBy: rowSeparater)
        guard !firtHeadArr.isEmpty else {
            print("Error: rowString 配置无效-")
            return
        }
        var jsonArrVaild = true
        let jsonArr = rowArr.compactMap { itemStr -> [String : String]? in
            
            guard !itemStr.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines).isEmpty else {
                return nil // 过滤空行 按列赋值可能有空行
            }
            
            let arr = itemStr.components(separatedBy: rowSeparater)
            guard arr.count == firtHeadArr.count else {
                jsonArrVaild = false
                print("Error: 配置缺失列: \(arr.joined(separator: "\n"))")
                return nil
            }
            let filtedArr = arr.filter { !$0.isEmpty }
            guard filtedArr.count == firtHeadArr.count else {
                jsonArrVaild = false
                print("Error: 配置列存在空字符串: \(filtedArr.joined(separator: "\n"))")
                return nil
            }
            return Dictionary(uniqueKeysWithValues: zip(firtHeadArr, arr))
        }
        if !jsonArrVaild {
            print("Error: 请先解决控制台打印错误")
            return
        }
        
        
        // 生成文件内容
        let key = "中文"
        var filesMap = [String: [String: String]]()
        for name in firtHeadArr {
            var kvMap = [String: String]()
            jsonArr.forEach { item in
                let keyVal = item[key]!
                let valVal = item[name]!
                if kvMap[keyVal] != nil {
                    print("ERROR: 发现重复key: \"\(keyVal)\"  已被覆盖")
                }
                kvMap[keyVal] = valVal
            }
            filesMap[name] = kvMap
        }
        print("Log: 解析出有效配置文件 \(filesMap.count) 个")
        
        let fileManager = FileManager.default
        filesMap.forEach { key, valueArr in
            let fileName = ios_stringFileName(withKey: key)!
            let defultMap = ios_defultConfig(key: key)!
            var kvDic = valueArr
            kvDic.merge(defultMap) { _, new in new }
            let kvArr = kvDic.sorted { $0.key < $1.key } // 按key排序 确保每个文件的key顺序相同
            
            let string = kvArr.map { "\"\($0)\" = \"\($1)\";" }.joined(separator: "\n")
            let pathURL = fileManager.homeDirectoryForCurrentUser.appendingPathComponent("Desktop/outStringFiles/\(fileName)")
            
            guard (try? fileManager.createDirectory(at: pathURL.deletingLastPathComponent(), withIntermediateDirectories: true, attributes: nil)) != nil else {
                print("ERROR: 创建文件夹失败 ...")
                return
            }
            if (try? string.write(to: pathURL, atomically: true, encoding: .utf8)) != nil {
                print("创建 \(key) 文件成功 : \(pathURL)")
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
