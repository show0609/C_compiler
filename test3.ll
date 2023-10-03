; === prologue ====
@str0 = private unnamed_addr constant [5 x i8] c"%d!\0A\00"
declare dso_local i32 @printf(i8*, ...)

define dso_local i32 @main()
{
%t0 = alloca i32, align 4
store i32 1, i32* %t0
%t1 = alloca i32, align 4
%t2=load i32, i32* %t0
%t3 = add nsw i32 %t2, 198
store i32 %t3, i32* %t1
%t4=load i32, i32* %t1
%t5= call i32 (i8*, ...) @printf(i8* getelementptr inbounds ([5 x i8], [5 x i8]* @str0, i64 0, i64 0), i32 %t4)

; === epilogue ===
ret i32 0
}
