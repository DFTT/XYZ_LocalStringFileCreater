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
        
        // 1. 按列复制excel中的配置 转成json http://www.ab173.com/json/col2json.php
        
        // 2. 复制转换结果 粘贴到文件 JsonFile->jsonFile.json
        
        // 3. 运行本程序
        
        // 4. 查看生成的文件(~/Desktop/outStringFiles/)  拖动生成的文件夹到原项目中覆盖全部即可
        
        // 读数据
        let jsonPath = Bundle.main.path(forResource: "jsonFile", ofType: "json")
        guard let jsonString = try? String(contentsOfFile: jsonPath!), let jsonData = jsonString.data(using: .utf8) else {
            print("Error: json 配置为空-")
            return
        }
         
        guard let arr = try? JSONSerialization.jsonObject(with: jsonData, options: JSONSerialization.ReadingOptions(rawValue: 0)),
              var jsonArr = arr as? [[String: String]],
              !jsonArr.isEmpty
        else {
            print("Error: json 配置为空")
            exit(0)
            return
        }

        // 检测数据
        var jsonArrVaild = true
        let columnCout = jsonArr.first?.count
        jsonArr = jsonArr.filter { item in
            if item.isEmpty {
                // 丢弃空列
                return false
            }
            guard item.count == columnCout else {
                print("Error: 配置缺失列: \(item)")
                jsonArrVaild = false
                return false
            }

            var vaild = true
            item.forEach { (_: String, value: String) in
                if value.isEmpty {
                    vaild = false
                }
            }
            if !vaild {
                print("Error: 配置列不能为空字符串: \(item)")
                jsonArrVaild = false
            }
            return vaild
        }
        
        if !jsonArrVaild {
            print("Error: 请先修改控制台打印错误")
            exit(0)
            return
        }
        
        // 生成文件内容
        let key = "中文"
        let keys = (jsonArr.first ?? [:]).keys
        var filesMap = [String: [String: String]]()
        for name in keys {
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
