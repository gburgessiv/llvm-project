//===-- MipsMCAsmInfo.cpp - Mips Asm Properties ---------------------------===//
//
// Part of the LLVM Project, under the Apache License v2.0 with LLVM Exceptions.
// See https://llvm.org/LICENSE.txt for license information.
// SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
//
//===----------------------------------------------------------------------===//
//
// This file contains the declarations of the MipsMCAsmInfo properties.
//
//===----------------------------------------------------------------------===//

#include "MipsMCAsmInfo.h"
#include "MipsABIInfo.h"
#include "llvm/TargetParser/Triple.h"

using namespace llvm;

void MipsELFMCAsmInfo::anchor() {}

MipsELFMCAsmInfo::MipsELFMCAsmInfo(const Triple &TheTriple,
                                   const MCTargetOptions &Options) {
  IsLittleEndian = TheTriple.isLittleEndian();

  MipsABIInfo ABI = MipsABIInfo::computeTargetABI(TheTriple, "", Options);

  if (TheTriple.isMIPS64() && !ABI.IsN32())
    CodePointerSize = CalleeSaveStackSlotSize = 8;

  if (ABI.IsO32())
    PrivateGlobalPrefix = "$";
  else if (ABI.IsN32() || ABI.IsN64())
    PrivateGlobalPrefix = ".L";
  PrivateLabelPrefix = PrivateGlobalPrefix;

  AlignmentIsInBytes          = false;
  Data16bitsDirective         = "\t.2byte\t";
  Data32bitsDirective         = "\t.4byte\t";
  Data64bitsDirective         = "\t.8byte\t";
  CommentString               = "#";
  ZeroDirective               = "\t.space\t";
  UseAssignmentForEHBegin = true;
  SupportsDebugInformation = true;
  ExceptionsType = ExceptionHandling::DwarfCFI;
  DwarfRegNumForCFI = true;
}

void MipsCOFFMCAsmInfo::anchor() {}

MipsCOFFMCAsmInfo::MipsCOFFMCAsmInfo() {
  HasSingleParameterDotFile = true;
  WinEHEncodingType = WinEH::EncodingType::Itanium;

  ExceptionsType = ExceptionHandling::WinEH;

  PrivateGlobalPrefix = ".L";
  PrivateLabelPrefix = ".L";
  AllowAtInName = true;
}
