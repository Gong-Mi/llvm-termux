/*===-- lib/quadmath/complex-math.c ---------------------------------*- C -*-===
 *
 * Part of the LLVM Project, under the Apache License v2.0 with LLVM Exceptions.
 * See https://llvm.org/LICENSE.txt for license information.
 * SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
 *
 *===----------------------------------------------------------------------===*/

#include "complex-math.h"

#if HAS_LDBL128 || HAS_FLOAT128

#if defined(__ANDROID__) && __ANDROID_API__ < 26
/* Android bionic only exposes <complex.h> functions starting with API 26.
 * For API 24/25, stub out F128 complex math so the runtime links.
 * These routines are rarely used; returning NaN signals lack of support.
 */
static CFloat128ComplexType F128ComplexNaN(void) {
  return __builtin_nanl("") + __builtin_nanl("") * 1.0Li;
}

CFloat128Type RTDEF(CAbsF128)(CFloat128ComplexType x) { return __builtin_nanl(""); }
CFloat128ComplexType RTDEF(CAcosF128)(CFloat128ComplexType x) { return F128ComplexNaN(); }
CFloat128ComplexType RTDEF(CAcoshF128)(CFloat128ComplexType x) { return F128ComplexNaN(); }
CFloat128ComplexType RTDEF(CAsinF128)(CFloat128ComplexType x) { return F128ComplexNaN(); }
CFloat128ComplexType RTDEF(CAsinhF128)(CFloat128ComplexType x) { return F128ComplexNaN(); }
CFloat128ComplexType RTDEF(CAtanF128)(CFloat128ComplexType x) { return F128ComplexNaN(); }
CFloat128ComplexType RTDEF(CAtanhF128)(CFloat128ComplexType x) { return F128ComplexNaN(); }
CFloat128ComplexType RTDEF(CCosF128)(CFloat128ComplexType x) { return F128ComplexNaN(); }
CFloat128ComplexType RTDEF(CCoshF128)(CFloat128ComplexType x) { return F128ComplexNaN(); }
CFloat128ComplexType RTDEF(CExpF128)(CFloat128ComplexType x) { return F128ComplexNaN(); }
CFloat128ComplexType RTDEF(CLogF128)(CFloat128ComplexType x) { return F128ComplexNaN(); }
CFloat128ComplexType RTDEF(CPowF128)(
    CFloat128ComplexType x, CFloat128ComplexType p) { return F128ComplexNaN(); }
CFloat128ComplexType RTDEF(CSinF128)(CFloat128ComplexType x) { return F128ComplexNaN(); }
CFloat128ComplexType RTDEF(CSinhF128)(CFloat128ComplexType x) { return F128ComplexNaN(); }
CFloat128ComplexType RTDEF(CSqrtF128)(CFloat128ComplexType x) { return F128ComplexNaN(); }
CFloat128ComplexType RTDEF(CTanF128)(CFloat128ComplexType x) { return F128ComplexNaN(); }
CFloat128ComplexType RTDEF(CTanhF128)(CFloat128ComplexType x) { return F128ComplexNaN(); }
#else

CFloat128Type RTDEF(CAbsF128)(CFloat128ComplexType x) { return CAbs(x); }
CFloat128ComplexType RTDEF(CAcosF128)(CFloat128ComplexType x) {
  return CAcos(x);
}
CFloat128ComplexType RTDEF(CAcoshF128)(CFloat128ComplexType x) {
  return CAcosh(x);
}
CFloat128ComplexType RTDEF(CAsinF128)(CFloat128ComplexType x) {
  return CAsin(x);
}
CFloat128ComplexType RTDEF(CAsinhF128)(CFloat128ComplexType x) {
  return CAsinh(x);
}
CFloat128ComplexType RTDEF(CAtanF128)(CFloat128ComplexType x) {
  return CAtan(x);
}
CFloat128ComplexType RTDEF(CAtanhF128)(CFloat128ComplexType x) {
  return CAtanh(x);
}
CFloat128ComplexType RTDEF(CCosF128)(CFloat128ComplexType x) { return CCos(x); }
CFloat128ComplexType RTDEF(CCoshF128)(CFloat128ComplexType x) {
  return CCosh(x);
}
CFloat128ComplexType RTDEF(CExpF128)(CFloat128ComplexType x) { return CExp(x); }
CFloat128ComplexType RTDEF(CLogF128)(CFloat128ComplexType x) { return CLog(x); }
CFloat128ComplexType RTDEF(CPowF128)(
    CFloat128ComplexType x, CFloat128ComplexType p) {
  return CPow(x, p);
}
CFloat128ComplexType RTDEF(CSinF128)(CFloat128ComplexType x) { return CSin(x); }
CFloat128ComplexType RTDEF(CSinhF128)(CFloat128ComplexType x) {
  return CSinh(x);
}
CFloat128ComplexType RTDEF(CSqrtF128)(CFloat128ComplexType x) {
  return CSqrt(x);
}
CFloat128ComplexType RTDEF(CTanF128)(CFloat128ComplexType x) { return CTan(x); }
CFloat128ComplexType RTDEF(CTanhF128)(CFloat128ComplexType x) {
  return CTanh(x);
}

#endif // __ANDROID_API__ < 26
#endif // HAS_LDBL128 || HAS_FLOAT128
