; === prologue ====
@str0 = private unnamed_addr constant [8 x i8] c"a is 0\0A\00"
@str1 = private unnamed_addr constant [9 x i8] c"a is %d\0A\00"
@str2 = private unnamed_addr constant [5 x i8] c"hi!\0A\00"
declare dso_local i32 @printf(i8*, ...)

define dso_local i32 @main()
{
%t0 = alloca i32, align 4
store i32 11, i32* %t0
%t1=load i32, i32* %t0
%t2 = icmp slt i32 %t1, 10
br i1 %t2, label %L1, label %L2
L1:
%t3=load i32, i32* %t0
%t4 = icmp eq i32 %t3, 0
br i1 %t4, label %L3, label %L4
L3:
%t5= call i32 (i8*, ...) @printf(i8* getelementptr inbounds ([8 x i8], [8 x i8]* @str0, i64 0, i64 0))
br label %L4
L4:
br label %L5
L2:
%t6=load i32, i32* %t0
%t7= call i32 (i8*, ...) @printf(i8* getelementptr inbounds ([9 x i8], [9 x i8]* @str1, i64 0, i64 0), i32 %t6)
br label %L5
L5:
%t8 = icmp sgt i32 1, 0
br i1 %t8, label %L6, label %L7
L6:
%t9= call i32 (i8*, ...) @printf(i8* getelementptr inbounds ([5 x i8], [5 x i8]* @str2, i64 0, i64 0))
br label %L7
L7:

; === epilogue ===
ret i32 0
}
