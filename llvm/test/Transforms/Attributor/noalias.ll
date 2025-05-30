; NOTE: Assertions have been autogenerated by utils/update_test_checks.py UTC_ARGS: --function-signature --check-attributes --check-globals
; RUN: opt -aa-pipeline=basic-aa -passes=attributor -attributor-manifest-internal  -attributor-annotate-decl-cs  -S < %s | FileCheck %s --check-prefixes=CHECK,TUNIT
; RUN: opt -aa-pipeline=basic-aa -passes=attributor-cgscc -attributor-manifest-internal  -attributor-annotate-decl-cs -S < %s | FileCheck %s --check-prefixes=CHECK,CGSCC

; TEST 1 - negative.

; void *G;
; void *foo(){
;   void *V = malloc(4);
;   G = V;
;   return V;
; }

@G = external global ptr

;.
; CHECK: @G = external global ptr
; CHECK: @alias_of_p = external global ptr
;.
define ptr @foo() {
; CHECK-LABEL: define {{[^@]+}}@foo() {
; CHECK-NEXT:    [[TMP1:%.*]] = tail call noalias ptr @malloc(i64 noundef 4)
; CHECK-NEXT:    store ptr [[TMP1]], ptr @G, align 8
; CHECK-NEXT:    ret ptr [[TMP1]]
;
  %1 = tail call noalias ptr @malloc(i64 4)
  store ptr %1, ptr @G, align 8
  ret ptr %1
}

declare noalias ptr @malloc(i64)

; TEST 2
; call noalias function in return instruction.

define ptr @return_noalias(){
; CHECK-LABEL: define {{[^@]+}}@return_noalias() {
; CHECK-NEXT:    [[TMP1:%.*]] = tail call noalias ptr @malloc(i64 noundef 4)
; CHECK-NEXT:    ret ptr [[TMP1]]
;
  %1 = tail call noalias ptr @malloc(i64 4)
  ret ptr %1
}

define void @nocapture(ptr %a){
; CHECK: Function Attrs: mustprogress nofree norecurse nosync nounwind willreturn memory(none)
; CHECK-LABEL: define {{[^@]+}}@nocapture
; CHECK-SAME: (ptr nofree readnone captures(none) [[A:%.*]]) #[[ATTR0:[0-9]+]] {
; CHECK-NEXT:    ret void
;
  ret void
}

define ptr @return_noalias_looks_like_capture(){
; CHECK-LABEL: define {{[^@]+}}@return_noalias_looks_like_capture() {
; CHECK-NEXT:    [[TMP1:%.*]] = tail call noalias ptr @malloc(i64 noundef 4)
; CHECK-NEXT:    ret ptr [[TMP1]]
;
  %1 = tail call noalias ptr @malloc(i64 4)
  call void @nocapture(ptr %1)
  ret ptr %1
}

define ptr @return_noalias_casted(){
; CHECK-LABEL: define {{[^@]+}}@return_noalias_casted() {
; CHECK-NEXT:    [[TMP1:%.*]] = tail call noalias ptr @malloc(i64 noundef 4)
; CHECK-NEXT:    ret ptr [[TMP1]]
;
  %1 = tail call noalias ptr @malloc(i64 4)
  ret ptr %1
}

declare ptr @alias()

; TEST 3
define ptr @call_alias(){
; CHECK-LABEL: define {{[^@]+}}@call_alias() {
; CHECK-NEXT:    [[TMP1:%.*]] = tail call ptr @alias()
; CHECK-NEXT:    ret ptr [[TMP1]]
;
  %1 = tail call ptr @alias()
  ret ptr %1
}

; TEST 4
; void *baz();
; void *foo(int a);
;
; void *bar()  {
;   foo(0);
;    return baz();
; }
;
; void *foo(int a)  {
;   if (a)
;   bar();
;   return malloc(4);
; }

define ptr @bar() nounwind uwtable {
; TUNIT: Function Attrs: nounwind uwtable
; TUNIT-LABEL: define {{[^@]+}}@bar
; TUNIT-SAME: () #[[ATTR1:[0-9]+]] {
; TUNIT-NEXT:    [[TMP1:%.*]] = tail call ptr (...) @baz() #[[ATTR2:[0-9]+]]
; TUNIT-NEXT:    ret ptr [[TMP1]]
;
; CGSCC: Function Attrs: nounwind uwtable
; CGSCC-LABEL: define {{[^@]+}}@bar
; CGSCC-SAME: () #[[ATTR1:[0-9]+]] {
; CGSCC-NEXT:    [[TMP1:%.*]] = tail call ptr (...) @baz() #[[ATTR3:[0-9]+]]
; CGSCC-NEXT:    ret ptr [[TMP1]]
;
  %1 = tail call ptr (...) @baz()
  ret ptr %1
}

define ptr @foo1(i32 %0) nounwind uwtable {
; TUNIT: Function Attrs: nounwind uwtable
; TUNIT-LABEL: define {{[^@]+}}@foo1
; TUNIT-SAME: (i32 [[TMP0:%.*]]) #[[ATTR1]] {
; TUNIT-NEXT:    [[TMP2:%.*]] = icmp eq i32 [[TMP0]], 0
; TUNIT-NEXT:    br i1 [[TMP2]], label [[TMP5:%.*]], label [[TMP3:%.*]]
; TUNIT:       3:
; TUNIT-NEXT:    [[TMP4:%.*]] = tail call ptr (...) @baz() #[[ATTR2]]
; TUNIT-NEXT:    br label [[TMP5]]
; TUNIT:       5:
; TUNIT-NEXT:    [[TMP6:%.*]] = tail call noalias ptr @malloc(i64 noundef 4)
; TUNIT-NEXT:    ret ptr [[TMP6]]
;
; CGSCC: Function Attrs: nounwind uwtable
; CGSCC-LABEL: define {{[^@]+}}@foo1
; CGSCC-SAME: (i32 [[TMP0:%.*]]) #[[ATTR1]] {
; CGSCC-NEXT:    [[TMP2:%.*]] = icmp eq i32 [[TMP0]], 0
; CGSCC-NEXT:    br i1 [[TMP2]], label [[TMP5:%.*]], label [[TMP3:%.*]]
; CGSCC:       3:
; CGSCC-NEXT:    [[TMP4:%.*]] = tail call ptr (...) @baz() #[[ATTR3]]
; CGSCC-NEXT:    br label [[TMP5]]
; CGSCC:       5:
; CGSCC-NEXT:    [[TMP6:%.*]] = tail call noalias ptr @malloc(i64 noundef 4)
; CGSCC-NEXT:    ret ptr [[TMP6]]
;
  %2 = icmp eq i32 %0, 0
  br i1 %2, label %5, label %3

3:                                                ; preds = %1
  %4 = tail call ptr (...) @baz()
  br label %5

5:                                                ; preds = %1, %3
  %6 = tail call noalias ptr @malloc(i64 4)
  ret ptr %6
}

declare ptr @baz(...) nounwind uwtable

; TEST 5

; Returning global pointer. Should not be noalias.
define ptr @getter() {
; CHECK: Function Attrs: mustprogress nofree norecurse nosync nounwind willreturn memory(none)
; CHECK-LABEL: define {{[^@]+}}@getter
; CHECK-SAME: () #[[ATTR0]] {
; CHECK-NEXT:    ret ptr @G
;
  ret ptr @G
}

; Returning global pointer. Should not be noalias.
define ptr @calle1(){
; TUNIT: Function Attrs: mustprogress nofree norecurse nosync nounwind willreturn memory(none)
; TUNIT-LABEL: define {{[^@]+}}@calle1
; TUNIT-SAME: () #[[ATTR0]] {
; TUNIT-NEXT:    ret ptr @G
;
; CGSCC: Function Attrs: mustprogress nofree nosync nounwind willreturn memory(none)
; CGSCC-LABEL: define {{[^@]+}}@calle1
; CGSCC-SAME: () #[[ATTR2:[0-9]+]] {
; CGSCC-NEXT:    [[TMP1:%.*]] = call noundef nonnull align 8 dereferenceable(8) ptr @getter() #[[ATTR12:[0-9]+]]
; CGSCC-NEXT:    ret ptr [[TMP1]]
;
  %1 = call ptr @getter()
  ret ptr %1
}

; TEST 6
declare noalias ptr @strdup(ptr nocapture) nounwind

define ptr @test6() nounwind uwtable ssp {
; TUNIT: Function Attrs: nounwind ssp uwtable
; TUNIT-LABEL: define {{[^@]+}}@test6
; TUNIT-SAME: () #[[ATTR3:[0-9]+]] {
; TUNIT-NEXT:    [[X:%.*]] = alloca [2 x i8], align 1
; TUNIT-NEXT:    store i8 97, ptr [[X]], align 1
; TUNIT-NEXT:    [[ARRAYIDX1:%.*]] = getelementptr inbounds [2 x i8], ptr [[X]], i64 0, i64 1
; TUNIT-NEXT:    store i8 0, ptr [[ARRAYIDX1]], align 1
; TUNIT-NEXT:    [[CALL:%.*]] = call noalias ptr @strdup(ptr noalias noundef nonnull captures(none) dereferenceable(2) [[X]]) #[[ATTR2]]
; TUNIT-NEXT:    ret ptr [[CALL]]
;
; CGSCC: Function Attrs: nounwind ssp uwtable
; CGSCC-LABEL: define {{[^@]+}}@test6
; CGSCC-SAME: () #[[ATTR4:[0-9]+]] {
; CGSCC-NEXT:    [[X:%.*]] = alloca [2 x i8], align 1
; CGSCC-NEXT:    store i8 97, ptr [[X]], align 1
; CGSCC-NEXT:    [[ARRAYIDX1:%.*]] = getelementptr inbounds [2 x i8], ptr [[X]], i64 0, i64 1
; CGSCC-NEXT:    store i8 0, ptr [[ARRAYIDX1]], align 1
; CGSCC-NEXT:    [[CALL:%.*]] = call noalias ptr @strdup(ptr noalias noundef nonnull captures(none) dereferenceable(2) [[X]]) #[[ATTR3]]
; CGSCC-NEXT:    ret ptr [[CALL]]
;
  %x = alloca [2 x i8], align 1
  store i8 97, ptr %x, align 1
  %arrayidx1 = getelementptr inbounds [2 x i8], ptr %x, i64 0, i64 1
  store i8 0, ptr %arrayidx1, align 1
  %call = call noalias ptr @strdup(ptr %x) nounwind
  ret ptr %call
}

; TEST 7

define ptr @test7() nounwind {
; TUNIT: Function Attrs: nounwind
; TUNIT-LABEL: define {{[^@]+}}@test7
; TUNIT-SAME: () #[[ATTR2]] {
; TUNIT-NEXT:  entry:
; TUNIT-NEXT:    [[A:%.*]] = call noalias ptr @malloc(i64 noundef 4) #[[ATTR2]]
; TUNIT-NEXT:    [[TOBOOL:%.*]] = icmp eq ptr [[A]], null
; TUNIT-NEXT:    br i1 [[TOBOOL]], label [[RETURN:%.*]], label [[IF_END:%.*]]
; TUNIT:       if.end:
; TUNIT-NEXT:    store i8 7, ptr [[A]], align 1
; TUNIT-NEXT:    br label [[RETURN]]
; TUNIT:       return:
; TUNIT-NEXT:    [[RETVAL_0:%.*]] = phi ptr [ [[A]], [[IF_END]] ], [ null, [[ENTRY:%.*]] ]
; TUNIT-NEXT:    ret ptr [[RETVAL_0]]
;
; CGSCC: Function Attrs: nounwind
; CGSCC-LABEL: define {{[^@]+}}@test7
; CGSCC-SAME: () #[[ATTR3]] {
; CGSCC-NEXT:  entry:
; CGSCC-NEXT:    [[A:%.*]] = call noalias ptr @malloc(i64 noundef 4) #[[ATTR3]]
; CGSCC-NEXT:    [[TOBOOL:%.*]] = icmp eq ptr [[A]], null
; CGSCC-NEXT:    br i1 [[TOBOOL]], label [[RETURN:%.*]], label [[IF_END:%.*]]
; CGSCC:       if.end:
; CGSCC-NEXT:    store i8 7, ptr [[A]], align 1
; CGSCC-NEXT:    br label [[RETURN]]
; CGSCC:       return:
; CGSCC-NEXT:    [[RETVAL_0:%.*]] = phi ptr [ [[A]], [[IF_END]] ], [ null, [[ENTRY:%.*]] ]
; CGSCC-NEXT:    ret ptr [[RETVAL_0]]
;
entry:
  %A = call noalias ptr @malloc(i64 4) nounwind
  %tobool = icmp eq ptr %A, null
  br i1 %tobool, label %return, label %if.end

if.end:
  store i8 7, ptr %A
  br label %return

return:
  %retval.0 = phi ptr [ %A, %if.end ], [ null, %entry ]
  ret ptr %retval.0
}

; TEST 8

define ptr @test8(ptr %0) nounwind uwtable {
; CHECK: Function Attrs: nounwind uwtable
; CHECK-LABEL: define {{[^@]+}}@test8
; CHECK-SAME: (ptr [[TMP0:%.*]]) #[[ATTR1:[0-9]+]] {
; CHECK-NEXT:    [[TMP2:%.*]] = tail call noalias ptr @malloc(i64 noundef 4)
; CHECK-NEXT:    [[TMP3:%.*]] = icmp ne ptr [[TMP0]], null
; CHECK-NEXT:    br i1 [[TMP3]], label [[TMP4:%.*]], label [[TMP5:%.*]]
; CHECK:       4:
; CHECK-NEXT:    store i8 10, ptr [[TMP2]], align 1
; CHECK-NEXT:    br label [[TMP5]]
; CHECK:       5:
; CHECK-NEXT:    ret ptr [[TMP2]]
;
  %2 = tail call noalias ptr @malloc(i64 4)
  %3 = icmp ne ptr %0, null
  br i1 %3, label %4, label %5

4:                                                ; preds = %1
  store i8 10, ptr %2
  br label %5

5:                                                ; preds = %1, %4
  ret ptr %2
}

; TEST 9
; Simple Argument Test
declare void @use_i8(ptr nocapture)
define internal void @test9a(ptr %a, ptr %b) {
; TUNIT: Function Attrs: memory(readwrite, argmem: none)
; TUNIT-LABEL: define {{[^@]+}}@test9a
; TUNIT-SAME: () #[[ATTR4:[0-9]+]] {
; TUNIT-NEXT:    call void @use_i8(ptr noundef null)
; TUNIT-NEXT:    ret void
;
; CGSCC: Function Attrs: memory(readwrite, argmem: none)
; CGSCC-LABEL: define {{[^@]+}}@test9a
; CGSCC-SAME: () #[[ATTR5:[0-9]+]] {
; CGSCC-NEXT:    call void @use_i8(ptr noundef null)
; CGSCC-NEXT:    ret void
;
  call void @use_i8(ptr null)
  ret void
}
define internal void @test9b(ptr %a, ptr %b) {
; FIXME: %b should be noalias
; CHECK-LABEL: define {{[^@]+}}@test9b
; CHECK-SAME: (ptr noalias captures(none) [[A:%.*]], ptr captures(none) [[B:%.*]]) {
; CHECK-NEXT:    call void @use_i8(ptr noalias captures(none) [[A]])
; CHECK-NEXT:    call void @use_i8(ptr captures(none) [[B]])
; CHECK-NEXT:    ret void
;
  call void @use_i8(ptr %a)
  call void @use_i8(ptr %b)
  ret void
}
define internal void @test9c(ptr %a, ptr %b, ptr %c) {
; CHECK-LABEL: define {{[^@]+}}@test9c
; CHECK-SAME: (ptr noalias captures(none) [[A:%.*]], ptr captures(none) [[B:%.*]], ptr captures(none) [[C:%.*]]) {
; CHECK-NEXT:    call void @use_i8(ptr noalias captures(none) [[A]])
; CHECK-NEXT:    call void @use_i8(ptr captures(none) [[B]])
; CHECK-NEXT:    call void @use_i8(ptr captures(none) [[C]])
; CHECK-NEXT:    ret void
;
  call void @use_i8(ptr %a)
  call void @use_i8(ptr %b)
  call void @use_i8(ptr %c)
  ret void
}
define void @test9_helper(ptr %a, ptr %b) {
; CHECK-LABEL: define {{[^@]+}}@test9_helper
; CHECK-SAME: (ptr captures(none) [[A:%.*]], ptr captures(none) [[B:%.*]]) {
; CHECK-NEXT:    tail call void @test9a()
; CHECK-NEXT:    tail call void @test9a()
; CHECK-NEXT:    tail call void @test9b(ptr noalias captures(none) [[A]], ptr captures(none) [[B]])
; CHECK-NEXT:    tail call void @test9b(ptr noalias captures(none) [[B]], ptr noalias captures(none) [[A]])
; CHECK-NEXT:    tail call void @test9c(ptr noalias captures(none) [[A]], ptr captures(none) [[B]], ptr captures(none) [[B]])
; CHECK-NEXT:    tail call void @test9c(ptr noalias captures(none) [[B]], ptr noalias captures(none) [[A]], ptr noalias captures(none) [[A]])
; CHECK-NEXT:    ret void
;
  tail call void @test9a(ptr noalias %a, ptr %b)
  tail call void @test9a(ptr noalias %b, ptr noalias %a)
  tail call void @test9b(ptr noalias %a, ptr %b)
  tail call void @test9b(ptr noalias %b, ptr noalias %a)
  tail call void @test9c(ptr noalias %a, ptr %b, ptr %b)
  tail call void @test9c(ptr noalias %b, ptr noalias %a, ptr noalias %a)
  ret void
}


; TEST 10
; Simple CallSite Test

declare void @test10_helper_1(ptr %a)
define void @test10_helper_2(ptr noalias %a) {
; CHECK-LABEL: define {{[^@]+}}@test10_helper_2
; CHECK-SAME: (ptr noalias [[A:%.*]]) {
; CHECK-NEXT:    tail call void @test10_helper_1(ptr [[A]])
; CHECK-NEXT:    ret void
;
  tail call void @test10_helper_1(ptr %a)
  ret void
}
define void @test10(ptr noalias %a) {
; CHECK-LABEL: define {{[^@]+}}@test10
; CHECK-SAME: (ptr noalias [[A:%.*]]) {
; CHECK-NEXT:    tail call void @test10_helper_1(ptr [[A]])
; CHECK-NEXT:    tail call void @test10_helper_2(ptr [[A]])
; CHECK-NEXT:    ret void
;
; FIXME: missing noalias
  tail call void @test10_helper_1(ptr %a)

  tail call void @test10_helper_2(ptr %a)
  ret void
}

; TEST 11
; CallSite Test

declare void @test11_helper(ptr %a, ptr %b)
define void @test11(ptr noalias %a) {
; CHECK-LABEL: define {{[^@]+}}@test11
; CHECK-SAME: (ptr noalias [[A:%.*]]) {
; CHECK-NEXT:    tail call void @test11_helper(ptr [[A]], ptr [[A]])
; CHECK-NEXT:    ret void
;
  tail call void @test11_helper(ptr %a, ptr %a)
  ret void
}


; TEST 12
; CallSite Argument
declare void @use_nocapture(ptr nocapture)
declare void @use(ptr)
define void @test12_1() {
; CHECK-LABEL: define {{[^@]+}}@test12_1() {
; CHECK-NEXT:    [[A:%.*]] = alloca i8, align 4
; CHECK-NEXT:    [[B:%.*]] = tail call noalias ptr @malloc(i64 noundef 4)
; CHECK-NEXT:    tail call void @use_nocapture(ptr noalias noundef nonnull align 4 captures(none) dereferenceable(1) [[A]])
; CHECK-NEXT:    tail call void @use_nocapture(ptr noalias noundef nonnull align 4 captures(none) dereferenceable(1) [[A]])
; CHECK-NEXT:    tail call void @use_nocapture(ptr noalias captures(none) [[B]])
; CHECK-NEXT:    tail call void @use_nocapture(ptr noalias captures(none) [[B]])
; CHECK-NEXT:    ret void
;
  %A = alloca i8, align 4
  %B = tail call noalias ptr @malloc(i64 4)
  tail call void @use_nocapture(ptr %A)
  tail call void @use_nocapture(ptr %A)
  tail call void @use_nocapture(ptr %B)
  tail call void @use_nocapture(ptr %B)
  ret void
}

define void @test12_2(){
; CHECK-LABEL: define {{[^@]+}}@test12_2() {
; CHECK-NEXT:    [[A:%.*]] = tail call noalias ptr @malloc(i64 noundef 4)
; CHECK-NEXT:    tail call void @use_nocapture(ptr captures(none) [[A]])
; CHECK-NEXT:    tail call void @use_nocapture(ptr captures(none) [[A]])
; CHECK-NEXT:    tail call void @use(ptr [[A]])
; CHECK-NEXT:    tail call void @use_nocapture(ptr captures(none) [[A]])
; CHECK-NEXT:    ret void
;
; FIXME: This should be @use_nocapture(ptr noalias [[A]])
; FIXME: This should be @use_nocapture(ptr noalias nocapture [[A]])
  %A = tail call noalias ptr @malloc(i64 4)
  tail call void @use_nocapture(ptr %A)
  tail call void @use_nocapture(ptr %A)
  tail call void @use(ptr %A)
  tail call void @use_nocapture(ptr %A)
  ret void
}

declare void @two_args(ptr nocapture , ptr nocapture)
define void @test12_3(){
; CHECK-LABEL: define {{[^@]+}}@test12_3() {
; CHECK-NEXT:    [[A:%.*]] = tail call noalias ptr @malloc(i64 noundef 4)
; CHECK-NEXT:    tail call void @two_args(ptr captures(none) [[A]], ptr captures(none) [[A]])
; CHECK-NEXT:    ret void
;
  %A = tail call noalias ptr @malloc(i64 4)
  tail call void @two_args(ptr %A, ptr %A)
  ret void
}

define void @test12_4(){
; CHECK-LABEL: define {{[^@]+}}@test12_4() {
; CHECK-NEXT:    [[A:%.*]] = tail call noalias ptr @malloc(i64 noundef 4)
; CHECK-NEXT:    [[B:%.*]] = tail call noalias ptr @malloc(i64 noundef 4)
; CHECK-NEXT:    [[A_1:%.*]] = getelementptr i8, ptr [[A]], i64 1
; CHECK-NEXT:    tail call void @two_args(ptr noalias captures(none) [[A]], ptr noalias captures(none) [[B]])
; CHECK-NEXT:    tail call void @two_args(ptr captures(none) [[A]], ptr captures(none) [[A]])
; CHECK-NEXT:    tail call void @two_args(ptr captures(none) [[A]], ptr captures(none) [[A_1]])
; CHECK-NEXT:    tail call void @two_args(ptr noalias captures(none) [[A]], ptr noalias captures(none) [[B]])
; CHECK-NEXT:    ret void
;
  %A = tail call noalias ptr @malloc(i64 4)
  %B = tail call noalias ptr @malloc(i64 4)
  %A_1 = getelementptr i8, ptr %A, i64 1

  tail call void @two_args(ptr %A, ptr %B)

  tail call void @two_args(ptr %A, ptr %A)

  tail call void @two_args(ptr %A, ptr %A_1)

; FIXME: This should be @two_args(ptr noalias nocapture %A, ptr noalias nocapture %B)
  tail call void @two_args(ptr %A, ptr %B)
  ret void
}

; TEST 13
define void @use_i8_internal(ptr %a) {
; CHECK-LABEL: define {{[^@]+}}@use_i8_internal
; CHECK-SAME: (ptr captures(none) [[A:%.*]]) {
; CHECK-NEXT:    call void @use_i8(ptr captures(none) [[A]])
; CHECK-NEXT:    ret void
;
  call void @use_i8(ptr %a)
  ret void
}

define void @test13_use_noalias(){
; CHECK-LABEL: define {{[^@]+}}@test13_use_noalias() {
; CHECK-NEXT:    [[M1:%.*]] = tail call noalias ptr @malloc(i64 noundef 4)
; CHECK-NEXT:    call void @use_i8_internal(ptr noalias captures(none) [[M1]])
; CHECK-NEXT:    ret void
;
; IS__CGSCC_OPM-LABEL: define {{[^@]+}}@test13_use_noalias()
; IS__CGSCC_OPM-NEXT:    [[M1:%.*]] = tail call noalias ptr @malloc(i64 4)
; IS__CGSCC_OPM-NEXT:    call void @use_i8_internal(ptr noalias [[M1]])
; IS__CGSCC_OPM-NEXT:    ret void
  %m1 = tail call noalias ptr @malloc(i64 4)
  call void @use_i8_internal(ptr %m1)
  ret void
}

define void @test13_use_alias(){
; CHECK-LABEL: define {{[^@]+}}@test13_use_alias() {
; CHECK-NEXT:    [[M1:%.*]] = tail call noalias ptr @malloc(i64 noundef 4)
; CHECK-NEXT:    call void @use_i8_internal(ptr noalias captures(none) [[M1]])
; CHECK-NEXT:    call void @use_i8_internal(ptr noalias captures(none) [[M1]])
; CHECK-NEXT:    ret void
;
  %m1 = tail call noalias ptr @malloc(i64 4)
  call void @use_i8_internal(ptr %m1)
  call void @use_i8_internal(ptr %m1)
  ret void
}

; TEST 14 i2p casts
define internal i32 @p2i(ptr %arg) {
; CHECK: Function Attrs: mustprogress nofree norecurse nosync nounwind willreturn memory(none)
; CHECK-LABEL: define {{[^@]+}}@p2i
; CHECK-SAME: (ptr noalias nofree readnone [[ARG:%.*]]) #[[ATTR0]] {
; CHECK-NEXT:    [[P2I:%.*]] = ptrtoint ptr [[ARG]] to i32
; CHECK-NEXT:    ret i32 [[P2I]]
;
  %p2i = ptrtoint ptr %arg to i32
  ret i32 %p2i
}

define i32 @i2p(ptr %arg) {
; TUNIT: Function Attrs: mustprogress nofree norecurse nosync nounwind willreturn memory(read)
; TUNIT-LABEL: define {{[^@]+}}@i2p
; TUNIT-SAME: (ptr nofree readonly [[ARG:%.*]]) #[[ATTR5:[0-9]+]] {
; TUNIT-NEXT:    [[C:%.*]] = call i32 @p2i(ptr noalias nofree readnone [[ARG]]) #[[ATTR11:[0-9]+]]
; TUNIT-NEXT:    [[I2P:%.*]] = inttoptr i32 [[C]] to ptr
; TUNIT-NEXT:    [[CALL:%.*]] = call i32 @ret(ptr nofree noundef readonly align 4 captures(none) [[I2P]]) #[[ATTR12:[0-9]+]]
; TUNIT-NEXT:    ret i32 [[CALL]]
;
; CGSCC: Function Attrs: mustprogress nofree nosync nounwind willreturn memory(read)
; CGSCC-LABEL: define {{[^@]+}}@i2p
; CGSCC-SAME: (ptr nofree readonly [[ARG:%.*]]) #[[ATTR6:[0-9]+]] {
; CGSCC-NEXT:    [[C:%.*]] = call i32 @p2i(ptr noalias nofree readnone [[ARG]]) #[[ATTR12]]
; CGSCC-NEXT:    [[I2P:%.*]] = inttoptr i32 [[C]] to ptr
; CGSCC-NEXT:    [[CALL:%.*]] = call i32 @ret(ptr nofree noundef nonnull readonly align 4 captures(none) dereferenceable(4) [[I2P]]) #[[ATTR13:[0-9]+]]
; CGSCC-NEXT:    ret i32 [[CALL]]
;
  %c = call i32 @p2i(ptr %arg)
  %i2p = inttoptr i32 %c to ptr
  %call = call i32 @ret(ptr %i2p)
  ret i32 %call
}
define internal i32 @ret(ptr %arg) {
; TUNIT: Function Attrs: mustprogress nofree norecurse nosync nounwind willreturn memory(argmem: read)
; TUNIT-LABEL: define {{[^@]+}}@ret
; TUNIT-SAME: (ptr nofree noundef nonnull readonly align 4 captures(none) dereferenceable(4) [[ARG:%.*]]) #[[ATTR6:[0-9]+]] {
; TUNIT-NEXT:    [[L:%.*]] = load i32, ptr [[ARG]], align 4
; TUNIT-NEXT:    ret i32 [[L]]
;
; CGSCC: Function Attrs: mustprogress nofree norecurse nosync nounwind willreturn memory(argmem: read)
; CGSCC-LABEL: define {{[^@]+}}@ret
; CGSCC-SAME: (ptr nofree noundef nonnull readonly align 4 captures(none) dereferenceable(4) [[ARG:%.*]]) #[[ATTR7:[0-9]+]] {
; CGSCC-NEXT:    [[L:%.*]] = load i32, ptr [[ARG]], align 4
; CGSCC-NEXT:    ret i32 [[L]]
;
  %l = load i32, ptr %arg
  ret i32 %l
}

; Test to propagate noalias where value is assumed to be no-capture in all the
; uses possibly executed before this callsite.
; IR referred from musl/src/strtod.c file

%struct._IO_FILE = type { i32, ptr, ptr, ptr, ptr, ptr, ptr, ptr, ptr, ptr, ptr, ptr, i32, ptr, ptr, i32, i32, i32, i16, i8, i8, i32, i32, ptr, i64, ptr, ptr, ptr, [4 x i8], i64, i64, ptr, ptr, ptr, [4 x i8] }
%struct.__locale_struct = type { [6 x ptr] }
%struct.__locale_map = type opaque

; Function Attrs: nounwind optsize
define internal fastcc double @strtox(ptr %s, ptr %p, i32 %prec) unnamed_addr {
; TUNIT-LABEL: define {{[^@]+}}@strtox
; TUNIT-SAME: (ptr [[S:%.*]]) unnamed_addr {
; TUNIT-NEXT:  entry:
; TUNIT-NEXT:    [[F:%.*]] = alloca [[STRUCT__IO_FILE:%.*]], align 8
; TUNIT-NEXT:    call void @llvm.lifetime.start.p0(i64 noundef 144, ptr nofree noundef nonnull align 8 captures(none) dereferenceable(240) [[F]]) #[[ATTR13:[0-9]+]]
; TUNIT-NEXT:    [[CALL:%.*]] = call i32 @sh_fromstring(ptr noundef nonnull align 8 dereferenceable(240) [[F]], ptr [[S]])
; TUNIT-NEXT:    call void @__shlim(ptr noundef nonnull align 8 dereferenceable(240) [[F]], i64 noundef 0)
; TUNIT-NEXT:    [[CALL1:%.*]] = call double @__floatscan(ptr noundef nonnull align 8 dereferenceable(240) [[F]], i32 noundef 1, i32 noundef 1)
; TUNIT-NEXT:    call void @llvm.lifetime.end.p0(i64 noundef 144, ptr nofree noundef nonnull align 8 captures(none) dereferenceable(240) [[F]])
; TUNIT-NEXT:    ret double [[CALL1]]
;
; CGSCC-LABEL: define {{[^@]+}}@strtox
; CGSCC-SAME: (ptr [[S:%.*]]) unnamed_addr {
; CGSCC-NEXT:  entry:
; CGSCC-NEXT:    [[F:%.*]] = alloca [[STRUCT__IO_FILE:%.*]], align 8
; CGSCC-NEXT:    call void @llvm.lifetime.start.p0(i64 noundef 144, ptr nofree noundef nonnull align 8 captures(none) dereferenceable(240) [[F]]) #[[ATTR14:[0-9]+]]
; CGSCC-NEXT:    [[CALL:%.*]] = call i32 @sh_fromstring(ptr noundef nonnull align 8 dereferenceable(240) [[F]], ptr [[S]])
; CGSCC-NEXT:    call void @__shlim(ptr noundef nonnull align 8 dereferenceable(240) [[F]], i64 noundef 0)
; CGSCC-NEXT:    [[CALL1:%.*]] = call double @__floatscan(ptr noundef nonnull align 8 dereferenceable(240) [[F]], i32 noundef 1, i32 noundef 1)
; CGSCC-NEXT:    call void @llvm.lifetime.end.p0(i64 noundef 144, ptr nofree noundef nonnull align 8 captures(none) dereferenceable(240) [[F]])
; CGSCC-NEXT:    ret double [[CALL1]]
;
entry:
  %f = alloca %struct._IO_FILE, align 8
  call void @llvm.lifetime.start.p0(i64 144, ptr nonnull %f)
  %call = call i32 @sh_fromstring(ptr nonnull %f, ptr %s)
  call void @__shlim(ptr nonnull %f, i64 0)
  %call1 = call double @__floatscan(ptr nonnull %f, i32 %prec, i32 1)
  call void @llvm.lifetime.end.p0(i64 144, ptr nonnull %f)

  ret double %call1
}

; Function Attrs: nounwind optsize
define dso_local double @strtod(ptr noalias %s, ptr noalias %p) {
; CHECK-LABEL: define {{[^@]+}}@strtod
; CHECK-SAME: (ptr noalias [[S:%.*]], ptr noalias nofree readnone captures(none) [[P:%.*]]) {
; CHECK-NEXT:  entry:
; CHECK-NEXT:    [[CALL:%.*]] = tail call fastcc double @strtox(ptr [[S]])
; CHECK-NEXT:    ret double [[CALL]]
;
entry:
  %call = tail call fastcc double @strtox(ptr %s, ptr %p, i32 1)
  ret double %call
}

; Function Attrs: argmemonly nounwind willreturn
declare void @llvm.lifetime.start.p0(i64 immarg, ptr nocapture)

; Function Attrs: optsize
declare dso_local i32 @sh_fromstring(...) local_unnamed_addr

; Function Attrs: optsize
declare dso_local void @__shlim(ptr, i64) local_unnamed_addr

; Function Attrs: optsize
declare dso_local double @__floatscan(ptr, i32, i32) local_unnamed_addr

; Function Attrs: argmemonly nounwind willreturn
declare void @llvm.lifetime.end.p0(i64 immarg, ptr nocapture)

; Test 15
; propagate noalias to some callsite arguments that there is no possibly reachable capture before it

@alias_of_p = external global ptr

define void @make_alias(ptr %p) {
; TUNIT: Function Attrs: mustprogress nofree norecurse nosync nounwind willreturn memory(write)
; TUNIT-LABEL: define {{[^@]+}}@make_alias
; TUNIT-SAME: (ptr nofree writeonly [[P:%.*]]) #[[ATTR8:[0-9]+]] {
; TUNIT-NEXT:    store ptr [[P]], ptr @alias_of_p, align 8
; TUNIT-NEXT:    ret void
;
; CGSCC: Function Attrs: mustprogress nofree norecurse nosync nounwind willreturn memory(write)
; CGSCC-LABEL: define {{[^@]+}}@make_alias
; CGSCC-SAME: (ptr nofree writeonly [[P:%.*]]) #[[ATTR9:[0-9]+]] {
; CGSCC-NEXT:    store ptr [[P]], ptr @alias_of_p, align 8
; CGSCC-NEXT:    ret void
;
  store ptr %p, ptr @alias_of_p
  ret void
}

define void @only_store(ptr %p) {
; TUNIT: Function Attrs: mustprogress nofree norecurse nosync nounwind willreturn memory(argmem: write)
; TUNIT-LABEL: define {{[^@]+}}@only_store
; TUNIT-SAME: (ptr nofree noundef nonnull writeonly align 4 captures(none) dereferenceable(4) [[P:%.*]]) #[[ATTR9:[0-9]+]] {
; TUNIT-NEXT:    store i32 0, ptr [[P]], align 4
; TUNIT-NEXT:    ret void
;
; CGSCC: Function Attrs: mustprogress nofree norecurse nosync nounwind willreturn memory(argmem: write)
; CGSCC-LABEL: define {{[^@]+}}@only_store
; CGSCC-SAME: (ptr nofree noundef nonnull writeonly align 4 captures(none) dereferenceable(4) [[P:%.*]]) #[[ATTR10:[0-9]+]] {
; CGSCC-NEXT:    store i32 0, ptr [[P]], align 4
; CGSCC-NEXT:    ret void
;
  store i32 0, ptr %p
  ret void
}

define void @test15_caller(ptr noalias %p, i32 %c) {
; TUNIT: Function Attrs: mustprogress nofree norecurse nosync nounwind willreturn memory(write)
; TUNIT-LABEL: define {{[^@]+}}@test15_caller
; TUNIT-SAME: (ptr noalias nofree writeonly [[P:%.*]], i32 [[C:%.*]]) #[[ATTR8]] {
; TUNIT-NEXT:    [[TOBOOL:%.*]] = icmp eq i32 [[C]], 0
; TUNIT-NEXT:    br i1 [[TOBOOL]], label [[IF_END:%.*]], label [[IF_THEN:%.*]]
; TUNIT:       if.then:
; TUNIT-NEXT:    tail call void @only_store(ptr noalias nofree noundef writeonly align 4 captures(none) [[P]]) #[[ATTR14:[0-9]+]]
; TUNIT-NEXT:    br label [[IF_END]]
; TUNIT:       if.end:
; TUNIT-NEXT:    tail call void @make_alias(ptr nofree writeonly [[P]]) #[[ATTR14]]
; TUNIT-NEXT:    ret void
;
; CGSCC: Function Attrs: mustprogress nofree nosync nounwind willreturn memory(write)
; CGSCC-LABEL: define {{[^@]+}}@test15_caller
; CGSCC-SAME: (ptr noalias nofree writeonly [[P:%.*]], i32 [[C:%.*]]) #[[ATTR11:[0-9]+]] {
; CGSCC-NEXT:    [[TOBOOL:%.*]] = icmp eq i32 [[C]], 0
; CGSCC-NEXT:    br i1 [[TOBOOL]], label [[IF_END:%.*]], label [[IF_THEN:%.*]]
; CGSCC:       if.then:
; CGSCC-NEXT:    tail call void @only_store(ptr nofree noundef nonnull writeonly align 4 captures(none) dereferenceable(4) [[P]]) #[[ATTR15:[0-9]+]]
; CGSCC-NEXT:    br label [[IF_END]]
; CGSCC:       if.end:
; CGSCC-NEXT:    tail call void @make_alias(ptr nofree writeonly [[P]]) #[[ATTR15]]
; CGSCC-NEXT:    ret void
;
  %tobool = icmp eq i32 %c, 0
  br i1 %tobool, label %if.end, label %if.then


if.then:
  tail call void @only_store(ptr %p)
  br label %if.end

if.end:
  tail call void @make_alias(ptr %p)
  ret void
}

; Test 16
;
; __attribute__((noinline)) static void test16_sub(int * restrict p, int c1, int c2) {
;   if (c1) {
;     only_store(p);
;     make_alias(p);
;   }
;   if (!c2) {
;     only_store(p);
;   }
; }
; void test16_caller(int * restrict p, int c) {
;   test16_sub(p, c, c);
; }
;
; FIXME: this should be tail @only_store(ptr noalias %p)
;        when test16_caller is called, c1 always equals to c2. (Note that linkage is internal)
;        Therefore, only one of the two conditions of if statementes will be fulfilled.

define internal void @test16_sub(ptr noalias %p, i32 %c1, i32 %c2) {
; TUNIT: Function Attrs: mustprogress nofree norecurse nosync nounwind willreturn memory(write)
; TUNIT-LABEL: define {{[^@]+}}@test16_sub
; TUNIT-SAME: (ptr noalias nofree writeonly [[P:%.*]], i32 [[C1:%.*]], i32 [[C2:%.*]]) #[[ATTR8]] {
; TUNIT-NEXT:    [[TOBOOL:%.*]] = icmp eq i32 [[C1]], 0
; TUNIT-NEXT:    br i1 [[TOBOOL]], label [[IF_END:%.*]], label [[IF_THEN:%.*]]
; TUNIT:       if.then:
; TUNIT-NEXT:    tail call void @only_store(ptr nofree noundef writeonly align 4 captures(none) [[P]]) #[[ATTR14]]
; TUNIT-NEXT:    tail call void @make_alias(ptr nofree writeonly align 4 [[P]]) #[[ATTR14]]
; TUNIT-NEXT:    br label [[IF_END]]
; TUNIT:       if.end:
; TUNIT-NEXT:    [[TOBOOL1:%.*]] = icmp eq i32 [[C2]], 0
; TUNIT-NEXT:    br i1 [[TOBOOL1]], label [[IF_THEN2:%.*]], label [[IF_END3:%.*]]
; TUNIT:       if.then2:
; TUNIT-NEXT:    tail call void @only_store(ptr nofree noundef writeonly align 4 captures(none) [[P]]) #[[ATTR14]]
; TUNIT-NEXT:    br label [[IF_END3]]
; TUNIT:       if.end3:
; TUNIT-NEXT:    ret void
;
; CGSCC: Function Attrs: mustprogress nofree nosync nounwind willreturn memory(write)
; CGSCC-LABEL: define {{[^@]+}}@test16_sub
; CGSCC-SAME: (ptr noalias nofree writeonly [[P:%.*]], i32 [[C1:%.*]], i32 [[C2:%.*]]) #[[ATTR11]] {
; CGSCC-NEXT:    [[TOBOOL:%.*]] = icmp eq i32 [[C1]], 0
; CGSCC-NEXT:    br i1 [[TOBOOL]], label [[IF_END:%.*]], label [[IF_THEN:%.*]]
; CGSCC:       if.then:
; CGSCC-NEXT:    tail call void @only_store(ptr nofree noundef nonnull writeonly align 4 captures(none) dereferenceable(4) [[P]]) #[[ATTR15]]
; CGSCC-NEXT:    tail call void @make_alias(ptr nofree nonnull writeonly align 4 dereferenceable(4) [[P]]) #[[ATTR15]]
; CGSCC-NEXT:    br label [[IF_END]]
; CGSCC:       if.end:
; CGSCC-NEXT:    [[TOBOOL1:%.*]] = icmp eq i32 [[C2]], 0
; CGSCC-NEXT:    br i1 [[TOBOOL1]], label [[IF_THEN2:%.*]], label [[IF_END3:%.*]]
; CGSCC:       if.then2:
; CGSCC-NEXT:    tail call void @only_store(ptr nofree noundef nonnull writeonly align 4 captures(none) dereferenceable(4) [[P]]) #[[ATTR15]]
; CGSCC-NEXT:    br label [[IF_END3]]
; CGSCC:       if.end3:
; CGSCC-NEXT:    ret void
;
  %tobool = icmp eq i32 %c1, 0
  br i1 %tobool, label %if.end, label %if.then

if.then:
  tail call void @only_store(ptr %p)
  tail call void @make_alias(ptr %p)
  br label %if.end
if.end:

  %tobool1 = icmp eq i32 %c2, 0
  br i1 %tobool1, label %if.then2, label %if.end3

if.then2:
  tail call void @only_store(ptr %p)
  br label %if.end3
if.end3:

  ret void
}

define void @test16_caller(ptr %p, i32 %c) {
; TUNIT: Function Attrs: mustprogress nofree norecurse nosync nounwind willreturn memory(write)
; TUNIT-LABEL: define {{[^@]+}}@test16_caller
; TUNIT-SAME: (ptr nofree writeonly [[P:%.*]], i32 [[C:%.*]]) #[[ATTR8]] {
; TUNIT-NEXT:    tail call void @test16_sub(ptr nofree writeonly [[P]], i32 [[C]], i32 [[C]]) #[[ATTR14]]
; TUNIT-NEXT:    ret void
;
; CGSCC: Function Attrs: mustprogress nofree nosync nounwind willreturn memory(write)
; CGSCC-LABEL: define {{[^@]+}}@test16_caller
; CGSCC-SAME: (ptr nofree writeonly [[P:%.*]], i32 [[C:%.*]]) #[[ATTR11]] {
; CGSCC-NEXT:    tail call void @test16_sub(ptr nofree writeonly [[P]], i32 [[C]], i32 [[C]]) #[[ATTR15]]
; CGSCC-NEXT:    ret void
;
  tail call void @test16_sub(ptr %p, i32 %c, i32 %c)
  ret void
}

; test 17
;
; only_store is not called after make_alias is called.
;
; void test17_caller(int* p, int c) {
;   if(c) {
;     make_alias(p);
;     if(0 == 0) {
;       goto l3;
;     } else {
;       goto l2;
;     }
;   }
;   l2:
;     only_store(p);
;   l3:
;   return;
; }

define void @test17_caller(ptr noalias %p, i32 %c) {
; TUNIT: Function Attrs: mustprogress nofree norecurse nosync nounwind willreturn memory(write)
; TUNIT-LABEL: define {{[^@]+}}@test17_caller
; TUNIT-SAME: (ptr noalias nofree writeonly [[P:%.*]], i32 [[C:%.*]]) #[[ATTR8]] {
; TUNIT-NEXT:  entry:
; TUNIT-NEXT:    [[TOBOOL:%.*]] = icmp eq i32 [[C]], 0
; TUNIT-NEXT:    br i1 [[TOBOOL]], label [[L1:%.*]], label [[L2:%.*]]
; TUNIT:       l1:
; TUNIT-NEXT:    tail call void @make_alias(ptr nofree writeonly [[P]]) #[[ATTR14]]
; TUNIT-NEXT:    br label [[L3:%.*]]
; TUNIT:       l2:
; TUNIT-NEXT:    tail call void @only_store(ptr noalias nofree noundef writeonly align 4 captures(none) [[P]]) #[[ATTR14]]
; TUNIT-NEXT:    br label [[L3]]
; TUNIT:       l3:
; TUNIT-NEXT:    ret void
;
; CGSCC: Function Attrs: mustprogress nofree nosync nounwind willreturn memory(write)
; CGSCC-LABEL: define {{[^@]+}}@test17_caller
; CGSCC-SAME: (ptr noalias nofree writeonly [[P:%.*]], i32 [[C:%.*]]) #[[ATTR11]] {
; CGSCC-NEXT:  entry:
; CGSCC-NEXT:    [[TOBOOL:%.*]] = icmp eq i32 [[C]], 0
; CGSCC-NEXT:    br i1 [[TOBOOL]], label [[L1:%.*]], label [[L2:%.*]]
; CGSCC:       l1:
; CGSCC-NEXT:    tail call void @make_alias(ptr nofree writeonly [[P]]) #[[ATTR15]]
; CGSCC-NEXT:    br label [[L3:%.*]]
; CGSCC:       l2:
; CGSCC-NEXT:    tail call void @only_store(ptr nofree noundef nonnull writeonly align 4 captures(none) dereferenceable(4) [[P]]) #[[ATTR15]]
; CGSCC-NEXT:    br label [[L3]]
; CGSCC:       l3:
; CGSCC-NEXT:    ret void
;
entry:
  %tobool = icmp eq i32 %c, 0
  br i1 %tobool, label %l1, label %l2

l1:
  tail call void @make_alias(ptr %p)
  %tobool2 = icmp eq i32 0, 0
  br i1 %tobool2, label %l3, label %l2

l2:
  tail call void @only_store(ptr %p)
  br label %l3

l3:
  ret void
}

; test 18
; void test18_caller(int* p, int c) {
;   if(c) {
;     make_alias(p);
;     noreturn();
;   }
;   only_store(p);
;   return;
; }

define void @noreturn() {
; TUNIT: Function Attrs: mustprogress nofree nosync nounwind willreturn memory(none)
; TUNIT-LABEL: define {{[^@]+}}@noreturn
; TUNIT-SAME: () #[[ATTR10:[0-9]+]] {
; TUNIT-NEXT:    ret void
;
; CGSCC: Function Attrs: mustprogress nofree nosync nounwind willreturn memory(none)
; CGSCC-LABEL: define {{[^@]+}}@noreturn
; CGSCC-SAME: () #[[ATTR2]] {
; CGSCC-NEXT:    ret void
;
  call void @noreturn()
  ret void
}

define void @test18_caller(ptr noalias %p, i32 %c) {
; TUNIT: Function Attrs: mustprogress nofree norecurse nosync nounwind willreturn memory(write)
; TUNIT-LABEL: define {{[^@]+}}@test18_caller
; TUNIT-SAME: (ptr noalias nofree writeonly [[P:%.*]], i32 [[C:%.*]]) #[[ATTR8]] {
; TUNIT-NEXT:  entry:
; TUNIT-NEXT:    [[TOBOOL:%.*]] = icmp eq i32 [[C]], 0
; TUNIT-NEXT:    br i1 [[TOBOOL]], label [[L1:%.*]], label [[L2:%.*]]
; TUNIT:       l1:
; TUNIT-NEXT:    tail call void @make_alias(ptr nofree writeonly [[P]]) #[[ATTR14]]
; TUNIT-NEXT:    br label [[L2]]
; TUNIT:       l2:
; TUNIT-NEXT:    tail call void @only_store(ptr nofree noundef writeonly align 4 captures(none) [[P]]) #[[ATTR14]]
; TUNIT-NEXT:    ret void
;
; CGSCC: Function Attrs: mustprogress nofree nosync nounwind willreturn memory(write)
; CGSCC-LABEL: define {{[^@]+}}@test18_caller
; CGSCC-SAME: (ptr noalias nofree nonnull writeonly align 4 dereferenceable(4) [[P:%.*]], i32 [[C:%.*]]) #[[ATTR11]] {
; CGSCC-NEXT:  entry:
; CGSCC-NEXT:    [[TOBOOL:%.*]] = icmp eq i32 [[C]], 0
; CGSCC-NEXT:    br i1 [[TOBOOL]], label [[L1:%.*]], label [[L2:%.*]]
; CGSCC:       l1:
; CGSCC-NEXT:    tail call void @make_alias(ptr nofree nonnull writeonly align 4 dereferenceable(4) [[P]]) #[[ATTR15]]
; CGSCC-NEXT:    br label [[L2]]
; CGSCC:       l2:
; CGSCC-NEXT:    tail call void @only_store(ptr nofree noundef nonnull writeonly align 4 captures(none) dereferenceable(4) [[P]]) #[[ATTR15]]
; CGSCC-NEXT:    ret void
;
entry:
  %tobool = icmp eq i32 %c, 0
  br i1 %tobool, label %l1, label %l2

l1:
  tail call void @make_alias(ptr %p)
  tail call void @noreturn()
  br label %l2

l2:
  tail call void @only_store(ptr %p)
  ret void
}
;.
; TUNIT: attributes #[[ATTR0]] = { mustprogress nofree norecurse nosync nounwind willreturn memory(none) }
; TUNIT: attributes #[[ATTR1]] = { nounwind uwtable }
; TUNIT: attributes #[[ATTR2]] = { nounwind }
; TUNIT: attributes #[[ATTR3]] = { nounwind ssp uwtable }
; TUNIT: attributes #[[ATTR4]] = { memory(readwrite, argmem: none) }
; TUNIT: attributes #[[ATTR5]] = { mustprogress nofree norecurse nosync nounwind willreturn memory(read) }
; TUNIT: attributes #[[ATTR6]] = { mustprogress nofree norecurse nosync nounwind willreturn memory(argmem: read) }
; TUNIT: attributes #[[ATTR7:[0-9]+]] = { nocallback nofree nosync nounwind willreturn memory(argmem: readwrite) }
; TUNIT: attributes #[[ATTR8]] = { mustprogress nofree norecurse nosync nounwind willreturn memory(write) }
; TUNIT: attributes #[[ATTR9]] = { mustprogress nofree norecurse nosync nounwind willreturn memory(argmem: write) }
; TUNIT: attributes #[[ATTR10]] = { mustprogress nofree nosync nounwind willreturn memory(none) }
; TUNIT: attributes #[[ATTR11]] = { nofree nosync nounwind willreturn memory(none) }
; TUNIT: attributes #[[ATTR12]] = { nofree nosync nounwind willreturn memory(read) }
; TUNIT: attributes #[[ATTR13]] = { nofree willreturn memory(readwrite) }
; TUNIT: attributes #[[ATTR14]] = { nofree nosync nounwind willreturn memory(write) }
;.
; CGSCC: attributes #[[ATTR0]] = { mustprogress nofree norecurse nosync nounwind willreturn memory(none) }
; CGSCC: attributes #[[ATTR1]] = { nounwind uwtable }
; CGSCC: attributes #[[ATTR2]] = { mustprogress nofree nosync nounwind willreturn memory(none) }
; CGSCC: attributes #[[ATTR3]] = { nounwind }
; CGSCC: attributes #[[ATTR4]] = { nounwind ssp uwtable }
; CGSCC: attributes #[[ATTR5]] = { memory(readwrite, argmem: none) }
; CGSCC: attributes #[[ATTR6]] = { mustprogress nofree nosync nounwind willreturn memory(read) }
; CGSCC: attributes #[[ATTR7]] = { mustprogress nofree norecurse nosync nounwind willreturn memory(argmem: read) }
; CGSCC: attributes #[[ATTR8:[0-9]+]] = { nocallback nofree nosync nounwind willreturn memory(argmem: readwrite) }
; CGSCC: attributes #[[ATTR9]] = { mustprogress nofree norecurse nosync nounwind willreturn memory(write) }
; CGSCC: attributes #[[ATTR10]] = { mustprogress nofree norecurse nosync nounwind willreturn memory(argmem: write) }
; CGSCC: attributes #[[ATTR11]] = { mustprogress nofree nosync nounwind willreturn memory(write) }
; CGSCC: attributes #[[ATTR12]] = { nofree nosync willreturn }
; CGSCC: attributes #[[ATTR13]] = { nofree willreturn memory(read) }
; CGSCC: attributes #[[ATTR14]] = { nofree willreturn memory(readwrite) }
; CGSCC: attributes #[[ATTR15]] = { nofree nounwind willreturn memory(write) }
;.
