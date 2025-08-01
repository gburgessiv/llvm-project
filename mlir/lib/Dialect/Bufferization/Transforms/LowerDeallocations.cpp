//===- LowerDeallocations.cpp - Bufferization Deallocs to MemRef pass -----===//
//
// Part of the LLVM Project, under the Apache License v2.0 with LLVM Exceptions.
// See https://llvm.org/LICENSE.txt for license information.
// SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
//
//===----------------------------------------------------------------------===//
//
// This file implements patterns to convert `bufferization.dealloc` operations
// to the MemRef dialect.
//
//===----------------------------------------------------------------------===//

#include "mlir/Dialect/Arith/IR/Arith.h"
#include "mlir/Dialect/Bufferization/IR/Bufferization.h"
#include "mlir/Dialect/Bufferization/Transforms/Passes.h"
#include "mlir/Dialect/Func/IR/FuncOps.h"
#include "mlir/Dialect/MemRef/IR/MemRef.h"
#include "mlir/Dialect/SCF/IR/SCF.h"
#include "mlir/IR/BuiltinTypes.h"
#include "mlir/Transforms/DialectConversion.h"

namespace mlir {
namespace bufferization {
#define GEN_PASS_DEF_LOWERDEALLOCATIONSPASS
#include "mlir/Dialect/Bufferization/Transforms/Passes.h.inc"
} // namespace bufferization
} // namespace mlir

using namespace mlir;

namespace {
/// The DeallocOpConversion transforms all bufferization dealloc operations into
/// memref dealloc operations potentially guarded by scf if operations.
/// Additionally, memref extract_aligned_pointer_as_index and arith operations
/// are inserted to compute the guard conditions. We distinguish multiple cases
/// to provide an overall more efficient lowering. In the general case, a helper
/// func is created to avoid quadratic code size explosion (relative to the
/// number of operands of the dealloc operation). For examples of each case,
/// refer to the documentation of the member functions of this class.
class DeallocOpConversion
    : public OpConversionPattern<bufferization::DeallocOp> {

  /// Lower a simple case without any retained values and a single memref to
  /// avoiding the helper function. Ideally, static analysis can provide enough
  /// aliasing information to split the dealloc operations up into this simple
  /// case as much as possible before running this pass.
  ///
  /// Example:
  /// ```
  /// bufferization.dealloc (%arg0 : memref<2xf32>) if (%arg1)
  /// ```
  /// is lowered to
  /// ```
  /// scf.if %arg1 {
  ///   memref.dealloc %arg0 : memref<2xf32>
  /// }
  /// ```
  LogicalResult
  rewriteOneMemrefNoRetainCase(bufferization::DeallocOp op, OpAdaptor adaptor,
                               ConversionPatternRewriter &rewriter) const {
    assert(adaptor.getMemrefs().size() == 1 && "expected only one memref");
    assert(adaptor.getRetained().empty() && "expected no retained memrefs");

    rewriter.replaceOpWithNewOp<scf::IfOp>(
        op, adaptor.getConditions()[0], [&](OpBuilder &builder, Location loc) {
          memref::DeallocOp::create(builder, loc, adaptor.getMemrefs()[0]);
          scf::YieldOp::create(builder, loc);
        });
    return success();
  }

  /// A special case lowering for the deallocation operation with exactly one
  /// memref, but arbitrary number of retained values. This avoids the helper
  /// function that the general case needs and thus also avoids storing indices
  /// to specifically allocated memrefs. The size of the code produced by this
  /// lowering is linear to the number of retained values.
  ///
  /// Example:
  /// ```mlir
  /// %0:2 = bufferization.dealloc (%m : memref<2xf32>) if (%cond)
  //                        retain (%r0, %r1 : memref<1xf32>, memref<2xf32>)
  /// return %0#0, %0#1 : i1, i1
  /// ```
  /// ```mlir
  /// %m_base_pointer = memref.extract_aligned_pointer_as_index %m
  /// %r0_base_pointer = memref.extract_aligned_pointer_as_index %r0
  /// %r0_does_not_alias = arith.cmpi ne, %m_base_pointer, %r0_base_pointer
  /// %r1_base_pointer = memref.extract_aligned_pointer_as_index %r1
  /// %r1_does_not_alias = arith.cmpi ne, %m_base_pointer, %r1_base_pointer
  /// %not_retained = arith.andi %r0_does_not_alias, %r1_does_not_alias : i1
  /// %should_dealloc = arith.andi %not_retained, %cond : i1
  /// scf.if %should_dealloc {
  ///   memref.dealloc %m : memref<2xf32>
  /// }
  /// %true = arith.constant true
  /// %r0_does_alias = arith.xori %r0_does_not_alias, %true : i1
  /// %r0_ownership = arith.andi %r0_does_alias, %cond : i1
  /// %r1_does_alias = arith.xori %r1_does_not_alias, %true : i1
  /// %r1_ownership = arith.andi %r1_does_alias, %cond : i1
  /// return %r0_ownership, %r1_ownership : i1, i1
  /// ```
  LogicalResult rewriteOneMemrefMultipleRetainCase(
      bufferization::DeallocOp op, OpAdaptor adaptor,
      ConversionPatternRewriter &rewriter) const {
    assert(adaptor.getMemrefs().size() == 1 && "expected only one memref");

    // Compute the base pointer indices, compare all retained indices to the
    // memref index to check if they alias.
    SmallVector<Value> doesNotAliasList;
    Value memrefAsIdx = memref::ExtractAlignedPointerAsIndexOp::create(
        rewriter, op->getLoc(), adaptor.getMemrefs()[0]);
    for (Value retained : adaptor.getRetained()) {
      Value retainedAsIdx = memref::ExtractAlignedPointerAsIndexOp::create(
          rewriter, op->getLoc(), retained);
      Value doesNotAlias = arith::CmpIOp::create(rewriter, op->getLoc(),
                                                 arith::CmpIPredicate::ne,
                                                 memrefAsIdx, retainedAsIdx);
      doesNotAliasList.push_back(doesNotAlias);
    }

    // AND-reduce the list of booleans from above.
    Value prev = doesNotAliasList.front();
    for (Value doesNotAlias : ArrayRef(doesNotAliasList).drop_front())
      prev = arith::AndIOp::create(rewriter, op->getLoc(), prev, doesNotAlias);

    // Also consider the condition given by the dealloc operation and perform a
    // conditional deallocation guarded by that value.
    Value shouldDealloc = arith::AndIOp::create(rewriter, op->getLoc(), prev,
                                                adaptor.getConditions()[0]);

    scf::IfOp::create(rewriter, op.getLoc(), shouldDealloc,
                      [&](OpBuilder &builder, Location loc) {
                        memref::DeallocOp::create(builder, loc,
                                                  adaptor.getMemrefs()[0]);
                        scf::YieldOp::create(builder, loc);
                      });

    // Compute the replacement values for the dealloc operation results. This
    // inserts an already canonicalized form of
    // `select(does_alias_with_memref(r), memref_cond, false)` for each retained
    // value r.
    SmallVector<Value> replacements;
    Value trueVal = arith::ConstantOp::create(rewriter, op->getLoc(),
                                              rewriter.getBoolAttr(true));
    for (Value doesNotAlias : doesNotAliasList) {
      Value aliases =
          arith::XOrIOp::create(rewriter, op->getLoc(), doesNotAlias, trueVal);
      Value result = arith::AndIOp::create(rewriter, op->getLoc(), aliases,
                                           adaptor.getConditions()[0]);
      replacements.push_back(result);
    }

    rewriter.replaceOp(op, replacements);

    return success();
  }

  /// Lowering that supports all features the dealloc operation has to offer. It
  /// computes the base pointer of each memref (as an index), stores it in a
  /// new memref helper structure and passes it to the helper function generated
  /// in 'buildDeallocationHelperFunction'. The results are stored in two lists
  /// (represented as memrefs) of booleans passed as arguments. The first list
  /// stores whether the corresponding condition should be deallocated, the
  /// second list stores the ownership of the retained values which can be used
  /// to replace the result values of the `bufferization.dealloc` operation.
  ///
  /// Example:
  /// ```
  /// %0:2 = bufferization.dealloc (%m0, %m1 : memref<2xf32>, memref<5xf32>)
  ///                           if (%cond0, %cond1)
  ///                       retain (%r0, %r1 : memref<1xf32>, memref<2xf32>)
  /// ```
  /// lowers to (simplified):
  /// ```
  /// %c0 = arith.constant 0 : index
  /// %c1 = arith.constant 1 : index
  /// %dealloc_base_pointer_list = memref.alloc() : memref<2xindex>
  /// %cond_list = memref.alloc() : memref<2xi1>
  /// %retain_base_pointer_list = memref.alloc() : memref<2xindex>
  /// %m0_base_pointer = memref.extract_aligned_pointer_as_index %m0
  /// memref.store %m0_base_pointer, %dealloc_base_pointer_list[%c0]
  /// %m1_base_pointer = memref.extract_aligned_pointer_as_index %m1
  /// memref.store %m1_base_pointer, %dealloc_base_pointer_list[%c1]
  /// memref.store %cond0, %cond_list[%c0]
  /// memref.store %cond1, %cond_list[%c1]
  /// %r0_base_pointer = memref.extract_aligned_pointer_as_index %r0
  /// memref.store %r0_base_pointer, %retain_base_pointer_list[%c0]
  /// %r1_base_pointer = memref.extract_aligned_pointer_as_index %r1
  /// memref.store %r1_base_pointer, %retain_base_pointer_list[%c1]
  /// %dyn_dealloc_base_pointer_list = memref.cast %dealloc_base_pointer_list :
  ///    memref<2xindex> to memref<?xindex>
  /// %dyn_cond_list = memref.cast %cond_list : memref<2xi1> to memref<?xi1>
  /// %dyn_retain_base_pointer_list = memref.cast %retain_base_pointer_list :
  ///    memref<2xindex> to memref<?xindex>
  /// %dealloc_cond_out = memref.alloc() : memref<2xi1>
  /// %ownership_out = memref.alloc() : memref<2xi1>
  /// %dyn_dealloc_cond_out = memref.cast %dealloc_cond_out :
  ///    memref<2xi1> to memref<?xi1>
  /// %dyn_ownership_out = memref.cast %ownership_out :
  ///    memref<2xi1> to memref<?xi1>
  /// call @dealloc_helper(%dyn_dealloc_base_pointer_list,
  ///                      %dyn_retain_base_pointer_list,
  ///                      %dyn_cond_list,
  ///                      %dyn_dealloc_cond_out,
  ///                      %dyn_ownership_out) : (...)
  /// %m0_dealloc_cond = memref.load %dyn_dealloc_cond_out[%c0] : memref<2xi1>
  /// scf.if %m0_dealloc_cond {
  ///   memref.dealloc %m0 : memref<2xf32>
  /// }
  /// %m1_dealloc_cond = memref.load %dyn_dealloc_cond_out[%c1] : memref<2xi1>
  /// scf.if %m1_dealloc_cond {
  ///   memref.dealloc %m1 : memref<5xf32>
  /// }
  /// %r0_ownership = memref.load %dyn_ownership_out[%c0] : memref<2xi1>
  /// %r1_ownership = memref.load %dyn_ownership_out[%c1] : memref<2xi1>
  /// memref.dealloc %dealloc_base_pointer_list : memref<2xindex>
  /// memref.dealloc %retain_base_pointer_list : memref<2xindex>
  /// memref.dealloc %cond_list : memref<2xi1>
  /// memref.dealloc %dealloc_cond_out : memref<2xi1>
  /// memref.dealloc %ownership_out : memref<2xi1>
  /// // replace %0#0 with %r0_ownership
  /// // replace %0#1 with %r1_ownership
  /// ```
  LogicalResult rewriteGeneralCase(bufferization::DeallocOp op,
                                   OpAdaptor adaptor,
                                   ConversionPatternRewriter &rewriter) const {
    // Allocate two memrefs holding the base pointer indices of the list of
    // memrefs to be deallocated and the ones to be retained. These can then be
    // passed to the helper function and the for-loops can iterate over them.
    // Without storing them to memrefs, we could not use for-loops but only a
    // completely unrolled version of it, potentially leading to code-size
    // blow-up.
    Value toDeallocMemref = memref::AllocOp::create(
        rewriter, op.getLoc(),
        MemRefType::get({(int64_t)adaptor.getMemrefs().size()},
                        rewriter.getIndexType()));
    Value conditionMemref = memref::AllocOp::create(
        rewriter, op.getLoc(),
        MemRefType::get({(int64_t)adaptor.getConditions().size()},
                        rewriter.getI1Type()));
    Value toRetainMemref = memref::AllocOp::create(
        rewriter, op.getLoc(),
        MemRefType::get({(int64_t)adaptor.getRetained().size()},
                        rewriter.getIndexType()));

    auto getConstValue = [&](uint64_t value) -> Value {
      return arith::ConstantOp::create(rewriter, op.getLoc(),
                                       rewriter.getIndexAttr(value));
    };

    // Extract the base pointers of the memrefs as indices to check for aliasing
    // at runtime.
    for (auto [i, toDealloc] : llvm::enumerate(adaptor.getMemrefs())) {
      Value memrefAsIdx = memref::ExtractAlignedPointerAsIndexOp::create(
          rewriter, op.getLoc(), toDealloc);
      memref::StoreOp::create(rewriter, op.getLoc(), memrefAsIdx,
                              toDeallocMemref, getConstValue(i));
    }

    for (auto [i, cond] : llvm::enumerate(adaptor.getConditions()))
      memref::StoreOp::create(rewriter, op.getLoc(), cond, conditionMemref,
                              getConstValue(i));

    for (auto [i, toRetain] : llvm::enumerate(adaptor.getRetained())) {
      Value memrefAsIdx = memref::ExtractAlignedPointerAsIndexOp::create(
          rewriter, op.getLoc(), toRetain);
      memref::StoreOp::create(rewriter, op.getLoc(), memrefAsIdx,
                              toRetainMemref, getConstValue(i));
    }

    // Cast the allocated memrefs to dynamic shape because we want only one
    // helper function no matter how many operands the bufferization.dealloc
    // has.
    Value castedDeallocMemref = memref::CastOp::create(
        rewriter, op->getLoc(),
        MemRefType::get({ShapedType::kDynamic}, rewriter.getIndexType()),
        toDeallocMemref);
    Value castedCondsMemref = memref::CastOp::create(
        rewriter, op->getLoc(),
        MemRefType::get({ShapedType::kDynamic}, rewriter.getI1Type()),
        conditionMemref);
    Value castedRetainMemref = memref::CastOp::create(
        rewriter, op->getLoc(),
        MemRefType::get({ShapedType::kDynamic}, rewriter.getIndexType()),
        toRetainMemref);

    Value deallocCondsMemref = memref::AllocOp::create(
        rewriter, op.getLoc(),
        MemRefType::get({(int64_t)adaptor.getMemrefs().size()},
                        rewriter.getI1Type()));
    Value retainCondsMemref = memref::AllocOp::create(
        rewriter, op.getLoc(),
        MemRefType::get({(int64_t)adaptor.getRetained().size()},
                        rewriter.getI1Type()));

    Value castedDeallocCondsMemref = memref::CastOp::create(
        rewriter, op->getLoc(),
        MemRefType::get({ShapedType::kDynamic}, rewriter.getI1Type()),
        deallocCondsMemref);
    Value castedRetainCondsMemref = memref::CastOp::create(
        rewriter, op->getLoc(),
        MemRefType::get({ShapedType::kDynamic}, rewriter.getI1Type()),
        retainCondsMemref);

    Operation *symtableOp = op->getParentWithTrait<OpTrait::SymbolTable>();
    func::CallOp::create(
        rewriter, op.getLoc(), deallocHelperFuncMap.lookup(symtableOp),
        SmallVector<Value>{castedDeallocMemref, castedRetainMemref,
                           castedCondsMemref, castedDeallocCondsMemref,
                           castedRetainCondsMemref});

    for (unsigned i = 0, e = adaptor.getMemrefs().size(); i < e; ++i) {
      Value idxValue = getConstValue(i);
      Value shouldDealloc = memref::LoadOp::create(
          rewriter, op.getLoc(), deallocCondsMemref, idxValue);
      scf::IfOp::create(rewriter, op.getLoc(), shouldDealloc,
                        [&](OpBuilder &builder, Location loc) {
                          memref::DeallocOp::create(builder, loc,
                                                    adaptor.getMemrefs()[i]);
                          scf::YieldOp::create(builder, loc);
                        });
    }

    SmallVector<Value> replacements;
    for (unsigned i = 0, e = adaptor.getRetained().size(); i < e; ++i) {
      Value idxValue = getConstValue(i);
      Value ownership = memref::LoadOp::create(rewriter, op.getLoc(),
                                               retainCondsMemref, idxValue);
      replacements.push_back(ownership);
    }

    // Deallocate above allocated memrefs again to avoid memory leaks.
    // Deallocation will not be run on code after this stage.
    memref::DeallocOp::create(rewriter, op.getLoc(), toDeallocMemref);
    memref::DeallocOp::create(rewriter, op.getLoc(), toRetainMemref);
    memref::DeallocOp::create(rewriter, op.getLoc(), conditionMemref);
    memref::DeallocOp::create(rewriter, op.getLoc(), deallocCondsMemref);
    memref::DeallocOp::create(rewriter, op.getLoc(), retainCondsMemref);

    rewriter.replaceOp(op, replacements);
    return success();
  }

public:
  DeallocOpConversion(
      MLIRContext *context,
      const bufferization::DeallocHelperMap &deallocHelperFuncMap)
      : OpConversionPattern<bufferization::DeallocOp>(context),
        deallocHelperFuncMap(deallocHelperFuncMap) {}

  LogicalResult
  matchAndRewrite(bufferization::DeallocOp op, OpAdaptor adaptor,
                  ConversionPatternRewriter &rewriter) const override {
    // Lower the trivial case.
    if (adaptor.getMemrefs().empty()) {
      Value falseVal = arith::ConstantOp::create(rewriter, op.getLoc(),
                                                 rewriter.getBoolAttr(false));
      rewriter.replaceOp(
          op, SmallVector<Value>(adaptor.getRetained().size(), falseVal));
      return success();
    }

    if (adaptor.getMemrefs().size() == 1 && adaptor.getRetained().empty())
      return rewriteOneMemrefNoRetainCase(op, adaptor, rewriter);

    if (adaptor.getMemrefs().size() == 1)
      return rewriteOneMemrefMultipleRetainCase(op, adaptor, rewriter);

    Operation *symtableOp = op->getParentWithTrait<OpTrait::SymbolTable>();
    if (!deallocHelperFuncMap.contains(symtableOp))
      return op->emitError(
          "library function required for generic lowering, but cannot be "
          "automatically inserted when operating on functions");

    return rewriteGeneralCase(op, adaptor, rewriter);
  }

private:
  const bufferization::DeallocHelperMap &deallocHelperFuncMap;
};
} // namespace

namespace {
struct LowerDeallocationsPass
    : public bufferization::impl::LowerDeallocationsPassBase<
          LowerDeallocationsPass> {
  void runOnOperation() override {
    if (!isa<ModuleOp, FunctionOpInterface>(getOperation())) {
      emitError(getOperation()->getLoc(),
                "root operation must be a builtin.module or a function");
      signalPassFailure();
      return;
    }

    bufferization::DeallocHelperMap deallocHelperFuncMap;
    if (auto module = dyn_cast<ModuleOp>(getOperation())) {
      OpBuilder builder = OpBuilder::atBlockBegin(module.getBody());

      // Build dealloc helper function if there are deallocs.
      getOperation()->walk([&](bufferization::DeallocOp deallocOp) {
        Operation *symtableOp =
            deallocOp->getParentWithTrait<OpTrait::SymbolTable>();
        if (deallocOp.getMemrefs().size() > 1 &&
            !deallocHelperFuncMap.contains(symtableOp)) {
          SymbolTable symbolTable(symtableOp);
          func::FuncOp helperFuncOp =
              bufferization::buildDeallocationLibraryFunction(
                  builder, getOperation()->getLoc(), symbolTable);
          deallocHelperFuncMap[symtableOp] = helperFuncOp;
        }
      });
    }

    RewritePatternSet patterns(&getContext());
    bufferization::populateBufferizationDeallocLoweringPattern(
        patterns, deallocHelperFuncMap);

    ConversionTarget target(getContext());
    target.addLegalDialect<memref::MemRefDialect, arith::ArithDialect,
                           scf::SCFDialect, func::FuncDialect>();
    target.addIllegalOp<bufferization::DeallocOp>();

    if (failed(applyPartialConversion(getOperation(), target,
                                      std::move(patterns))))
      signalPassFailure();
  }
};
} // namespace

func::FuncOp mlir::bufferization::buildDeallocationLibraryFunction(
    OpBuilder &builder, Location loc, SymbolTable &symbolTable) {
  Type indexMemrefType =
      MemRefType::get({ShapedType::kDynamic}, builder.getIndexType());
  Type boolMemrefType =
      MemRefType::get({ShapedType::kDynamic}, builder.getI1Type());
  SmallVector<Type> argTypes{indexMemrefType, indexMemrefType, boolMemrefType,
                             boolMemrefType, boolMemrefType};
  builder.clearInsertionPoint();

  // Generate the func operation itself.
  auto helperFuncOp = func::FuncOp::create(
      loc, "dealloc_helper", builder.getFunctionType(argTypes, {}));
  helperFuncOp.setVisibility(SymbolTable::Visibility::Private);
  symbolTable.insert(helperFuncOp);
  auto &block = helperFuncOp.getFunctionBody().emplaceBlock();
  block.addArguments(argTypes, SmallVector<Location>(argTypes.size(), loc));

  builder.setInsertionPointToStart(&block);
  Value toDeallocMemref = helperFuncOp.getArguments()[0];
  Value toRetainMemref = helperFuncOp.getArguments()[1];
  Value conditionMemref = helperFuncOp.getArguments()[2];
  Value deallocCondsMemref = helperFuncOp.getArguments()[3];
  Value retainCondsMemref = helperFuncOp.getArguments()[4];

  // Insert some prerequisites.
  Value c0 = arith::ConstantOp::create(builder, loc, builder.getIndexAttr(0));
  Value c1 = arith::ConstantOp::create(builder, loc, builder.getIndexAttr(1));
  Value trueValue =
      arith::ConstantOp::create(builder, loc, builder.getBoolAttr(true));
  Value falseValue =
      arith::ConstantOp::create(builder, loc, builder.getBoolAttr(false));
  Value toDeallocSize =
      memref::DimOp::create(builder, loc, toDeallocMemref, c0);
  Value toRetainSize = memref::DimOp::create(builder, loc, toRetainMemref, c0);

  scf::ForOp::create(
      builder, loc, c0, toRetainSize, c1, ValueRange(),
      [&](OpBuilder &builder, Location loc, Value i, ValueRange iterArgs) {
        memref::StoreOp::create(builder, loc, falseValue, retainCondsMemref, i);
        scf::YieldOp::create(builder, loc);
      });

  scf::ForOp::create(
      builder, loc, c0, toDeallocSize, c1, ValueRange(),
      [&](OpBuilder &builder, Location loc, Value outerIter,
          ValueRange iterArgs) {
        Value toDealloc =
            memref::LoadOp::create(builder, loc, toDeallocMemref, outerIter);
        Value cond =
            memref::LoadOp::create(builder, loc, conditionMemref, outerIter);

        // Build the first for loop that computes aliasing with retained
        // memrefs.
        Value
            noRetainAlias =
                scf::ForOp::create(
                    builder, loc, c0, toRetainSize, c1, trueValue,
                    [&](OpBuilder &builder, Location loc, Value i,
                        ValueRange iterArgs) {
                      Value retainValue = memref::LoadOp::create(
                          builder, loc, toRetainMemref, i);
                      Value doesAlias = arith::CmpIOp::create(
                          builder, loc, arith::CmpIPredicate::eq, retainValue,
                          toDealloc);
                      scf::IfOp::create(
                          builder, loc, doesAlias,
                          [&](OpBuilder &builder, Location loc) {
                            Value retainCondValue = memref::LoadOp::create(
                                builder, loc, retainCondsMemref, i);
                            Value aggregatedRetainCond = arith::OrIOp::create(
                                builder, loc, retainCondValue, cond);
                            memref::StoreOp::create(builder, loc,
                                                    aggregatedRetainCond,
                                                    retainCondsMemref, i);
                            scf::YieldOp::create(builder, loc);
                          });
                      Value doesntAlias = arith::CmpIOp::create(
                          builder, loc, arith::CmpIPredicate::ne, retainValue,
                          toDealloc);
                      Value yieldValue = arith::AndIOp::create(
                          builder, loc, iterArgs[0], doesntAlias);
                      scf::YieldOp::create(builder, loc, yieldValue);
                    })
                    .getResult(0);

        // Build the second for loop that adds aliasing with previously
        // deallocated memrefs.
        Value
            noAlias =
                scf::ForOp::create(
                    builder, loc, c0, outerIter, c1, noRetainAlias,
                    [&](OpBuilder &builder, Location loc, Value i,
                        ValueRange iterArgs) {
                      Value prevDeallocValue = memref::LoadOp::create(
                          builder, loc, toDeallocMemref, i);
                      Value doesntAlias = arith::CmpIOp::create(
                          builder, loc, arith::CmpIPredicate::ne,
                          prevDeallocValue, toDealloc);
                      Value yieldValue = arith::AndIOp::create(
                          builder, loc, iterArgs[0], doesntAlias);
                      scf::YieldOp::create(builder, loc, yieldValue);
                    })
                    .getResult(0);

        Value shouldDealoc = arith::AndIOp::create(builder, loc, noAlias, cond);
        memref::StoreOp::create(builder, loc, shouldDealoc, deallocCondsMemref,
                                outerIter);
        scf::YieldOp::create(builder, loc);
      });

  func::ReturnOp::create(builder, loc);
  return helperFuncOp;
}

void mlir::bufferization::populateBufferizationDeallocLoweringPattern(
    RewritePatternSet &patterns,
    const bufferization::DeallocHelperMap &deallocHelperFuncMap) {
  patterns.add<DeallocOpConversion>(patterns.getContext(),
                                    deallocHelperFuncMap);
}
