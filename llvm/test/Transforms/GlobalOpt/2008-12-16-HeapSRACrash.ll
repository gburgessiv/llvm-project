; RUN: opt < %s -passes=globalopt | llvm-dis
target datalayout = "e-p:32:32:32-i1:8:8-i8:8:8-i16:16:16-i32:32:32-i64:32:64-f32:32:32-f64:32:64-v64:64:64-v128:128:128-a0:0:64-f80:128:128"
target triple = "i386-apple-darwin7"
	%struct.foo = type { i32, i32 }
@X = internal global ptr null		; <ptr> [#uses=2]

define void @bar(i32 %Size) nounwind noinline {
entry:
  %mul = mul i64 ptrtoint (ptr getelementptr (i32, ptr null, i32 1) to i64), 2000000
  %trunc = trunc i64 %mul to i32
  %malloccall = tail call ptr @malloc(i32 %trunc)
	%.sub = getelementptr [1000000 x %struct.foo], ptr %malloccall, i32 0, i32 0		; <ptr> [#uses=1]
	store ptr %.sub, ptr @X, align 4
	ret void
}

declare noalias ptr @malloc(i32)

define i32 @baz() nounwind readonly noinline {
bb1.thread:
	%tmpLD1 = load ptr, ptr @X, align 4		; <ptr> [#uses=3]
	store ptr %tmpLD1, ptr null
	br label %bb1

bb1:		; preds = %bb1, %bb1.thread
	%tmp = phi ptr [ %tmpLD1, %bb1.thread ], [ %tmpLD1, %bb1 ]		; <ptr> [#uses=0]
	br i1 false, label %bb2, label %bb1

bb2:		; preds = %bb1
	ret i32 0
}
