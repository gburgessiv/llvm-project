; NOTE: Assertions have been autogenerated by utils/update_llc_test_checks.py
; RUN: llc < %s -mtriple=aarch64 -mattr=+sve | FileCheck %s

define <vscale x 2 x i64> @foo(<vscale x 2 x i64> %a) {
; CHECK-LABEL: foo:
; CHECK:       // %bb.0:
; CHECK-NEXT:    sub z0.d, z0.d, #2 // =0x2
; CHECK-NEXT:    ret
 %b = sub <vscale x 2 x i64> %a, splat (i64 1)
 %c = sub <vscale x 2 x i64> %b, splat (i64 1)
 ret <vscale x 2 x i64> %c
}
