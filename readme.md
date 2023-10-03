# 編譯器設計：Small C compiler for LLVM IR

### 程式執行
- `$ make` : 編譯及測試 資料夾裡所有的.c檔   
- `$ make file=fileName` : 編譯及測試 指定的檔案(fileName)

### 支援功能
1. data types: int
2. arithmetic computation: +, -, *, /, %, |, &, ()
3. Comparison expression: ==, !=, <, >, <=, >=
4. if-then-else, for loop, while loop
5. printf()
6. 註解
