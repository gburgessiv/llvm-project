; NOTE: Assertions have been autogenerated by utils/update_llc_test_checks.py UTC_ARGS: --version 5
; RUN: llc < %s -mtriple=nvptx64 | FileCheck %s
; RUN: %if ptxas %{ llc < %s -mtriple=nvptx64 | %ptxas-verify %}

declare i32 @get_register()

define i1 @test1() {
; CHECK-LABEL: test1(
; CHECK:       {
; CHECK-NEXT:    .reg .pred %p<2>;
; CHECK-NEXT:    .reg .b32 %r<3>;
; CHECK-EMPTY:
; CHECK-NEXT:  // %bb.0: // %entry
; CHECK-NEXT:    mov.u32 %r1, %tid.x;
; CHECK-NEXT:    setp.eq.b32 %p1, %r1, 1;
; CHECK-NEXT:    selp.b32 %r2, -1, 0, %p1;
; CHECK-NEXT:    st.param.b32 [func_retval0], %r2;
; CHECK-NEXT:    ret;
entry:
  %call = call i32 @llvm.nvvm.read.ptx.sreg.tid.x(), !range !0
  %cmp = icmp eq i32 %call, 1
  ret i1 %cmp
}

declare i32 @llvm.nvvm.read.ptx.sreg.tid.x()

!0 = !{ i32 0, i32 3 }
