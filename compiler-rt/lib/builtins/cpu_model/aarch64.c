//===-- cpu_model/aarch64.c - Support for __cpu_model builtin  ----*- C -*-===//
//
// Part of the LLVM Project, under the Apache License v2.0 with LLVM Exceptions.
// See https://llvm.org/LICENSE.txt for license information.
// SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
//
//===----------------------------------------------------------------------===//
//
//  This file is based on LLVM's lib/Support/Host.cpp.
//  It implements __aarch64_have_lse_atomics, __aarch64_cpu_features for
//  AArch64.
//
//===----------------------------------------------------------------------===//

#include "aarch64.h"

#if !defined(__aarch64__) && !defined(__arm64__) && !defined(_M_ARM64) &&      \
    !defined(__arm64ec__) && !defined(_M_ARM64EC)
#error This file is intended only for aarch64-based targets
#endif

#if __has_include(<sys/ifunc.h>)
#include <sys/ifunc.h>
#else
typedef struct __ifunc_arg_t {
  unsigned long _size;
  unsigned long _hwcap;
  unsigned long _hwcap2;
} __ifunc_arg_t;
#endif // __has_include(<sys/ifunc.h>)

// LSE support detection for out-of-line atomics
// using HWCAP and Auxiliary vector
_Bool __aarch64_have_lse_atomics
    __attribute__((visibility("hidden"), nocommon)) = false;

#if defined(__FreeBSD__)
// clang-format off: should not reorder sys/auxv.h alphabetically
#include <sys/auxv.h>
// clang-format on
#include "aarch64/hwcap.inc"
#include "aarch64/lse_atomics/freebsd.inc"
#elif defined(__Fuchsia__)
#include "aarch64/hwcap.inc"
#include "aarch64/lse_atomics/fuchsia.inc"
#elif defined(__ANDROID__)
#include "aarch64/hwcap.inc"
#include "aarch64/lse_atomics/android.inc"
#elif defined(__linux__) && __has_include(<sys/auxv.h>)
#include "aarch64/hwcap.inc"
#include "aarch64/lse_atomics/getauxval.inc"
#elif defined(_WIN32)
#include "aarch64/lse_atomics/windows.inc"
#else
// When unimplemented, we leave __aarch64_have_lse_atomics initialized to false.
#endif

#if !defined(DISABLE_AARCH64_FMV)

// Architecture features used
// in Function Multi Versioning
struct {
  unsigned long long features;
  // As features grows new fields could be added
} __aarch64_cpu_features __attribute__((visibility("hidden"), nocommon));

// The formatter wants to re-order these includes, but doing so is incorrect:
// clang-format off
#if defined(__APPLE__)
#include "aarch64/fmv/apple.inc"
#elif defined(__FreeBSD__)
#include "aarch64/fmv/mrs.inc"
#include "aarch64/fmv/freebsd.inc"
#elif defined(__Fuchsia__)
#include "aarch64/fmv/fuchsia.inc"
#elif defined(__ANDROID__)
#include "aarch64/fmv/mrs.inc"
#include "aarch64/fmv/android.inc"
#elif defined(__linux__) && __has_include(<sys/auxv.h>)
#include "aarch64/fmv/mrs.inc"
#include "aarch64/fmv/getauxval.inc"
#elif defined(_WIN32)
#include "aarch64/fmv/windows.inc"
#elif defined(ENABLE_BAREMETAL_AARCH64_FMV)
#include "aarch64/fmv/baremetal.inc"
#else
#include "aarch64/fmv/unimplemented.inc"
#endif
// clang-format on

#endif // !defined(DISABLE_AARCH64_FMV)
