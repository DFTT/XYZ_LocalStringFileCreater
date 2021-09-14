# XYZ_LocalStringFileCreater

根据配置生成需要的国际化配置文件

代码比较少 部分配置修改可以直接修改代码

建议的工作流:
1. 开发时只需在指定的单一配置文件(比如中文配置)中增加配置字符串
2. 开发结束后, copy新增的配置字符串给到产运进行翻译, 然后添加到全量的excel配置表
3. 见下 [使用步骤]


使用步骤:
1.  按列复制excel中的配置 转成json http://www.ab173.com/json/col2json.php
2.  复制转换结果 粘贴到文件 JsonFile->jsonFile.json
3.  运行本程序
4.  查看生成的文件(~/Desktop/outStringFiles/)  拖动生成的文件夹到原项目中覆盖全部即可
