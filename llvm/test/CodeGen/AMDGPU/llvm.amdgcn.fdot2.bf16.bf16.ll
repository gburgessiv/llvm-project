; NOTE: Assertions have been autogenerated by utils/update_llc_test_checks.py
; RUN: llc -mtriple=amdgcn -mcpu=gfx1100 -mattr=+real-true16 < %s | FileCheck %s --check-prefixes=GFX11,SDAG-GFX11,SDAG-GFX11-TRUE16
; RUN: llc -mtriple=amdgcn -mcpu=gfx1100 -mattr=-real-true16 < %s | FileCheck %s --check-prefixes=GFX11,SDAG-GFX11,SDAG-GFX11-FAKE16
; FIXME: GlobalIsel doesn't support BF16 for now.
; xUN: llc -global-isel -mtriple=amdgcn -mcpu=gfx1100 -mattr=+real-true16 < %s | FileCheck %s --check-prefixes=GFX11,GISEL-GFX11,GISEL-GFX11-TRUE16
; xUN: llc -global-isel -mtriple=amdgcn -mcpu=gfx1100 -mattr=-real-true16 < %s | FileCheck %s --check-prefixes=GFX11,GISEL-GFX11,GISEL-GFX11-FAKE16

declare bfloat @llvm.amdgcn.fdot2.bf16.bf16(<2 x bfloat> %a, <2 x bfloat> %b, bfloat %c)

define amdgpu_kernel void @test_llvm_amdgcn_fdot2_bf16_bf16(
; SDAG-GFX11-TRUE16-LABEL: test_llvm_amdgcn_fdot2_bf16_bf16:
; SDAG-GFX11-TRUE16:       ; %bb.0: ; %entry
; SDAG-GFX11-TRUE16-NEXT:    s_load_b256 s[0:7], s[4:5], 0x24
; SDAG-GFX11-TRUE16-NEXT:    v_mov_b32_e32 v1, 0
; SDAG-GFX11-TRUE16-NEXT:    s_waitcnt lgkmcnt(0)
; SDAG-GFX11-TRUE16-NEXT:    global_load_d16_b16 v0, v1, s[6:7]
; SDAG-GFX11-TRUE16-NEXT:    s_load_b32 s2, s[2:3], 0x0
; SDAG-GFX11-TRUE16-NEXT:    s_load_b32 s3, s[4:5], 0x0
; SDAG-GFX11-TRUE16-NEXT:    s_waitcnt vmcnt(0) lgkmcnt(0)
; SDAG-GFX11-TRUE16-NEXT:    v_dot2_bf16_bf16 v0.l, s2, s3, v0.l
; SDAG-GFX11-TRUE16-NEXT:    global_store_b16 v1, v0, s[0:1]
; SDAG-GFX11-TRUE16-NEXT:    s_endpgm
;
; SDAG-GFX11-FAKE16-LABEL: test_llvm_amdgcn_fdot2_bf16_bf16:
; SDAG-GFX11-FAKE16:       ; %bb.0: ; %entry
; SDAG-GFX11-FAKE16-NEXT:    s_load_b256 s[0:7], s[4:5], 0x24
; SDAG-GFX11-FAKE16-NEXT:    v_mov_b32_e32 v0, 0
; SDAG-GFX11-FAKE16-NEXT:    s_waitcnt lgkmcnt(0)
; SDAG-GFX11-FAKE16-NEXT:    global_load_u16 v1, v0, s[6:7]
; SDAG-GFX11-FAKE16-NEXT:    s_load_b32 s2, s[2:3], 0x0
; SDAG-GFX11-FAKE16-NEXT:    s_load_b32 s3, s[4:5], 0x0
; SDAG-GFX11-FAKE16-NEXT:    s_waitcnt vmcnt(0) lgkmcnt(0)
; SDAG-GFX11-FAKE16-NEXT:    v_dot2_bf16_bf16 v1, s2, s3, v1
; SDAG-GFX11-FAKE16-NEXT:    global_store_b16 v0, v1, s[0:1]
; SDAG-GFX11-FAKE16-NEXT:    s_endpgm
    ptr addrspace(1) %r,
    ptr addrspace(1) %a,
    ptr addrspace(1) %b,
    ptr addrspace(1) %c) {
entry:
  %a.val = load <2 x bfloat>, ptr addrspace(1) %a
  %b.val = load <2 x bfloat>, ptr addrspace(1) %b
  %c.val = load bfloat, ptr addrspace(1) %c
  %r.val = call bfloat @llvm.amdgcn.fdot2.bf16.bf16(<2 x bfloat> %a.val, <2 x bfloat> %b.val, bfloat %c.val)
  store bfloat %r.val, ptr addrspace(1) %r
  ret void
}

define amdgpu_kernel void @test_llvm_amdgcn_fdot2_bf16_bf16_dpp(
; SDAG-GFX11-TRUE16-LABEL: test_llvm_amdgcn_fdot2_bf16_bf16_dpp:
; SDAG-GFX11-TRUE16:       ; %bb.0: ; %entry
; SDAG-GFX11-TRUE16-NEXT:    s_load_b128 s[0:3], s[4:5], 0x24
; SDAG-GFX11-TRUE16-NEXT:    s_waitcnt lgkmcnt(0)
; SDAG-GFX11-TRUE16-NEXT:    scratch_load_b32 v1, off, s1
; SDAG-GFX11-TRUE16-NEXT:    scratch_load_b32 v2, off, s2
; SDAG-GFX11-TRUE16-NEXT:    scratch_load_d16_b16 v0, off, s3
; SDAG-GFX11-TRUE16-NEXT:    s_waitcnt vmcnt(2)
; SDAG-GFX11-TRUE16-NEXT:    v_mov_b32_dpp v1, v1 quad_perm:[1,0,0,0] row_mask:0xf bank_mask:0xf bound_ctrl:1
; SDAG-GFX11-TRUE16-NEXT:    s_waitcnt vmcnt(0)
; SDAG-GFX11-TRUE16-NEXT:    s_delay_alu instid0(VALU_DEP_1)
; SDAG-GFX11-TRUE16-NEXT:    v_dot2_bf16_bf16 v0.l, v1, v2, v0.l
; SDAG-GFX11-TRUE16-NEXT:    scratch_store_b16 off, v0, s0
; SDAG-GFX11-TRUE16-NEXT:    s_endpgm
;
; SDAG-GFX11-FAKE16-LABEL: test_llvm_amdgcn_fdot2_bf16_bf16_dpp:
; SDAG-GFX11-FAKE16:       ; %bb.0: ; %entry
; SDAG-GFX11-FAKE16-NEXT:    s_load_b128 s[0:3], s[4:5], 0x24
; SDAG-GFX11-FAKE16-NEXT:    s_waitcnt lgkmcnt(0)
; SDAG-GFX11-FAKE16-NEXT:    scratch_load_b32 v0, off, s2
; SDAG-GFX11-FAKE16-NEXT:    scratch_load_u16 v1, off, s3
; SDAG-GFX11-FAKE16-NEXT:    scratch_load_b32 v2, off, s1
; SDAG-GFX11-FAKE16-NEXT:    s_waitcnt vmcnt(0)
; SDAG-GFX11-FAKE16-NEXT:    v_dot2_bf16_bf16_e64_dpp v0, v2, v0, v1 quad_perm:[1,0,0,0] row_mask:0xf bank_mask:0xf bound_ctrl:1
; SDAG-GFX11-FAKE16-NEXT:    scratch_store_b16 off, v0, s0
; SDAG-GFX11-FAKE16-NEXT:    s_endpgm
    ptr addrspace(5) %r,
    ptr addrspace(5) %a,
    ptr addrspace(5) %b,
    ptr addrspace(5) %c) {
entry:
  %a.val = load <2 x bfloat>, ptr addrspace(5) %a
  %b.val = load <2 x bfloat>, ptr addrspace(5) %b
  %c.val = load bfloat, ptr addrspace(5) %c
  %a.val.i32 = bitcast <2 x bfloat> %a.val to i32
  %dpp = call i32 @llvm.amdgcn.update.dpp.i32(i32 %a.val.i32, i32 %a.val.i32, i32 1, i32 15, i32 15, i1 1)
  %a.val.dpp.v2bfloat = bitcast i32 %dpp to <2 x bfloat>
  %r.val = call bfloat @llvm.amdgcn.fdot2.bf16.bf16(<2 x bfloat> %a.val.dpp.v2bfloat, <2 x bfloat> %b.val, bfloat %c.val)
  store bfloat %r.val, ptr addrspace(5) %r
  ret void
}

; Make sure we do not violate constant bus restriction with 3 scalar inputs and simingly inlinable literal.

define amdgpu_ps void @test_llvm_amdgcn_fdot2_bf16_bf16_sis(
; SDAG-GFX11-TRUE16-LABEL: test_llvm_amdgcn_fdot2_bf16_bf16_sis:
; SDAG-GFX11-TRUE16:       ; %bb.0: ; %entry
; SDAG-GFX11-TRUE16-NEXT:    v_mov_b16_e32 v2.l, s1
; SDAG-GFX11-TRUE16-NEXT:    s_delay_alu instid0(VALU_DEP_1)
; SDAG-GFX11-TRUE16-NEXT:    v_dot2_bf16_bf16 v2.l, s0, 0x3f803f80, v2.l
; SDAG-GFX11-TRUE16-NEXT:    global_store_b16 v[0:1], v2, off
; SDAG-GFX11-TRUE16-NEXT:    s_endpgm
;
; SDAG-GFX11-FAKE16-LABEL: test_llvm_amdgcn_fdot2_bf16_bf16_sis:
; SDAG-GFX11-FAKE16:       ; %bb.0: ; %entry
; SDAG-GFX11-FAKE16-NEXT:    v_mov_b32_e32 v2, s1
; SDAG-GFX11-FAKE16-NEXT:    s_delay_alu instid0(VALU_DEP_1)
; SDAG-GFX11-FAKE16-NEXT:    v_dot2_bf16_bf16 v2, s0, 0x3f803f80, v2
; SDAG-GFX11-FAKE16-NEXT:    global_store_b16 v[0:1], v2, off
; SDAG-GFX11-FAKE16-NEXT:    s_endpgm
    ptr addrspace(1) %r,
    <2 x bfloat> inreg %a,
    bfloat inreg %c) {
entry:
  %r.val = call bfloat @llvm.amdgcn.fdot2.bf16.bf16(<2 x bfloat> %a, <2 x bfloat> <bfloat 1.0, bfloat 1.0>, bfloat %c)
  store bfloat %r.val, ptr addrspace(1) %r
  ret void
}

declare i32 @llvm.amdgcn.update.dpp.i32(i32, i32, i32, i32, i32, i1)
;; NOTE: These prefixes are unused and the list is autogenerated. Do not add tests below this line:
; GFX11: {{.*}}
; SDAG-GFX11: {{.*}}
