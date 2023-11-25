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

        let filePath = "/Users/dadadongl/Desktop/simpleFile.xlsx"
        guard let fp = LSFileParser(xmlPath: filePath) else {
            return
        }
        fp.fire(
            //             ,sheetName: "iOS"
            //             ,headRowIdx: 0
            valueBeginColumnIdx: 2,
            keyColumnIdx: 1
        )
    }
}
