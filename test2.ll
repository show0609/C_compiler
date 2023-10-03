; === prologue ====
@str0 = private unnamed_addr constant [7 x i8] c"%d %d\0A\00"
declare dso_local i32 @printf(i8*, ...)

define dso_local i32 @main()
{
%t0 = alloca i32, align 4
store i32 0, i32* %t0
%t1 = alloca i32, align 4
store i32 0, i32* %t1
br label %L1
L1:
%t2=load i32, i32* %t0
%t3 = icmp slt i32 %t2, 5
br i1 %t3, label %L2, label %L3
L2:
store i32 0, i32* %t1
br label %L4
L4:
%t4=load i32, i32* %t1
%t5 = icmp slt i32 %t4, 5
br i1 %t5, label %L5, label %L7
L6:
%t6=load i32, i32* %t1
%t7 = add nsw i32 %t6, 1
store i32 %t7, i32* %t1
br label %L4
L5:
%t8=load i32, i32* %t0
%t9=load i32, i32* %t1
%t10= call i32 (i8*, ...) @printf(i8* getelementptr inbounds ([7 x i8], [7 x i8]* @str0, i64 0, i64 0), i32 %t8, i32 %t9)
br label %L6
L7:
%t11=load i32, i32* %t0
%t12 = add nsw i32 %t11, 1
store i32 %t12, i32* %t0
br label %L1
L3:

; === epilogue ===
ret i32 0
}
