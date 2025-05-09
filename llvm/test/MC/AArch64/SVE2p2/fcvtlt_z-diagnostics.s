// RUN: not llvm-mc -triple=aarch64 -show-encoding -mattr=+sve2p2 2>&1 < %s| FileCheck %s

// --------------------------------------------------------------------------//
// Invalid element width

fcvtlt z0.b, p0/z, z0.b
// CHECK: [[@LINE-1]]:{{[0-9]+}}: error: invalid element width
// CHECK-NEXT: fcvtlt z0.b, p0/z, z0.b
// CHECK-NOT: [[@LINE-1]]:{{[0-9]+}}:

fcvtlt z0.h, p0/z, z0.h
// CHECK: [[@LINE-1]]:{{[0-9]+}}: error: invalid element width
// CHECK-NEXT: fcvtlt z0.h, p0/z, z0.h
// CHECK-NOT: [[@LINE-1]]:{{[0-9]+}}:

fcvtlt z0.s, p0/z, z0.s
// CHECK: [[@LINE-1]]:{{[0-9]+}}: error: invalid element width
// CHECK-NEXT: fcvtlt z0.s, p0/z, z0.s
// CHECK-NOT: [[@LINE-1]]:{{[0-9]+}}:

fcvtlt z0.d, p0/z, z0.d
// CHECK: [[@LINE-1]]:{{[0-9]+}}: error: invalid element width
// CHECK-NEXT: fcvtlt z0.d, p0/z, z0.d
// CHECK-NOT: [[@LINE-1]]:{{[0-9]+}}:

fcvtlt z0.h, p0/z, z0.b
// CHECK: [[@LINE-1]]:{{[0-9]+}}: error: invalid element width
// CHECK-NEXT: fcvtlt z0.h, p0/z, z0.b
// CHECK-NOT: [[@LINE-1]]:{{[0-9]+}}:

fcvtlt z0.q, p0/z, z0.d
// CHECK: [[@LINE-1]]:{{[0-9]+}}: error: invalid element width
// CHECK-NEXT: fcvtlt z0.q, p0/z, z0.d
// CHECK-NOT: [[@LINE-1]]:{{[0-9]+}}:

// --------------------------------------------------------------------------//
// Predicate not in restricted predicate range

fcvtlt z0.s, p8/z, z0.h
// CHECK: [[@LINE-1]]:{{[0-9]+}}: error: invalid restricted predicate register, expected p0..p7 (without element suffix)
// CHECK-NEXT: fcvtlt z0.s, p8/z, z0.h
// CHECK-NOT: [[@LINE-1]]:{{[0-9]+}}:

// --------------------------------------------------------------------------//
// Negative tests for instructions that are incompatible with movprfx

movprfx z0.s, p0/z, z7.s
fcvtlt z0.s, p7/z, z1.h
// CHECK: [[@LINE-1]]:{{[0-9]+}}: error: instruction is unpredictable when following a movprfx, suggest replacing movprfx with mov
// CHECK-NEXT: fcvtlt z0.s, p7/z, z1.h
// CHECK-NOT: [[@LINE-1]]:{{[0-9]+}}:

movprfx z0, z7
fcvtlt z0.s, p7/z, z1.h
// CHECK: [[@LINE-1]]:{{[0-9]+}}: error: instruction is unpredictable when following a movprfx, suggest replacing movprfx with mov
// CHECK-NEXT: fcvtlt z0.s, p7/z, z1.h
// CHECK-NOT: [[@LINE-1]]:{{[0-9]+}}: