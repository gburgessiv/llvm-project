//===----------------------------------------------------------------------===//
//
// Part of the LLVM Project, under the Apache License v2.0 with LLVM Exceptions.
// See https://llvm.org/LICENSE.txt for license information.
// SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
//
//===----------------------------------------------------------------------===//

// <algorithm>

// template<BidirectionalIterator Iter, Predicate<auto, Iter::value_type> Pred>
//   requires ShuffleIterator<Iter>
//         && CopyConstructible<Pred>
//   constexpr Iter                                                               // constexpr since C++26
//   stable_partition(Iter first, Iter last, Pred pred);

#include <algorithm>
#include <cassert>
#include <memory>
#include <vector>

#include "count_new.h"
#include "test_iterators.h"
#include "test_macros.h"

struct is_odd {
  TEST_CONSTEXPR_CXX26 bool operator()(const int& i) const { return i & 1; }
};

struct odd_first {
  TEST_CONSTEXPR_CXX26 bool operator()(const std::pair<int, int>& p) const { return p.first & 1; }
};

template <class Iter>
TEST_CONSTEXPR_CXX26 void test() {
  { // check mixed
    typedef std::pair<int,int> P;
    P array[] =
    {
        P(0, 1),
        P(0, 2),
        P(1, 1),
        P(1, 2),
        P(2, 1),
        P(2, 2),
        P(3, 1),
        P(3, 2),
        P(4, 1),
        P(4, 2)
    };
    const unsigned size = sizeof(array)/sizeof(array[0]);
    Iter r = std::stable_partition(Iter(array), Iter(array+size), odd_first());
    assert(base(r) == array + 4);
    assert(array[0] == P(1, 1));
    assert(array[1] == P(1, 2));
    assert(array[2] == P(3, 1));
    assert(array[3] == P(3, 2));
    assert(array[4] == P(0, 1));
    assert(array[5] == P(0, 2));
    assert(array[6] == P(2, 1));
    assert(array[7] == P(2, 2));
    assert(array[8] == P(4, 1));
    assert(array[9] == P(4, 2));
  }
  {
    typedef std::pair<int,int> P;
    P array[] =
    {
        P(0, 1),
        P(0, 2),
        P(1, 1),
        P(1, 2),
        P(2, 1),
        P(2, 2),
        P(3, 1),
        P(3, 2),
        P(4, 1),
        P(4, 2)
    };
    const unsigned size = sizeof(array)/sizeof(array[0]);
    Iter r = std::stable_partition(Iter(array), Iter(array+size), odd_first());
    assert(base(r) == array + 4);
    assert(array[0] == P(1, 1));
    assert(array[1] == P(1, 2));
    assert(array[2] == P(3, 1));
    assert(array[3] == P(3, 2));
    assert(array[4] == P(0, 1));
    assert(array[5] == P(0, 2));
    assert(array[6] == P(2, 1));
    assert(array[7] == P(2, 2));
    assert(array[8] == P(4, 1));
    assert(array[9] == P(4, 2));
    // check empty
    r = std::stable_partition(Iter(array), Iter(array), odd_first());
    assert(base(r) == array);
    // check one true
    r = std::stable_partition(Iter(array), Iter(array+1), odd_first());
    assert(base(r) == array+1);
    assert(array[0] == P(1, 1));
    // check one false
    r = std::stable_partition(Iter(array+4), Iter(array+5), odd_first());
    assert(base(r) == array+4);
    assert(array[4] == P(0, 1));
  }
  { // check all false
    typedef std::pair<int,int> P;
    P array[] =
    {
        P(0, 1),
        P(0, 2),
        P(2, 1),
        P(2, 2),
        P(4, 1),
        P(4, 2),
        P(6, 1),
        P(6, 2),
        P(8, 1),
        P(8, 2)
    };
    const unsigned size = sizeof(array)/sizeof(array[0]);
    Iter r = std::stable_partition(Iter(array), Iter(array+size), odd_first());
    assert(base(r) == array);
    assert(array[0] == P(0, 1));
    assert(array[1] == P(0, 2));
    assert(array[2] == P(2, 1));
    assert(array[3] == P(2, 2));
    assert(array[4] == P(4, 1));
    assert(array[5] == P(4, 2));
    assert(array[6] == P(6, 1));
    assert(array[7] == P(6, 2));
    assert(array[8] == P(8, 1));
    assert(array[9] == P(8, 2));
  }
  { // check all true
    typedef std::pair<int,int> P;
    P array[] =
    {
        P(1, 1),
        P(1, 2),
        P(3, 1),
        P(3, 2),
        P(5, 1),
        P(5, 2),
        P(7, 1),
        P(7, 2),
        P(9, 1),
        P(9, 2)
    };
    const unsigned size = sizeof(array)/sizeof(array[0]);
    Iter r = std::stable_partition(Iter(array), Iter(array+size), odd_first());
    assert(base(r) == array + size);
    assert(array[0] == P(1, 1));
    assert(array[1] == P(1, 2));
    assert(array[2] == P(3, 1));
    assert(array[3] == P(3, 2));
    assert(array[4] == P(5, 1));
    assert(array[5] == P(5, 2));
    assert(array[6] == P(7, 1));
    assert(array[7] == P(7, 2));
    assert(array[8] == P(9, 1));
    assert(array[9] == P(9, 2));
  }
  { // check all false but first true
    typedef std::pair<int,int> P;
    P array[] =
    {
        P(1, 1),
        P(0, 2),
        P(2, 1),
        P(2, 2),
        P(4, 1),
        P(4, 2),
        P(6, 1),
        P(6, 2),
        P(8, 1),
        P(8, 2)
    };
    const unsigned size = sizeof(array)/sizeof(array[0]);
    Iter r = std::stable_partition(Iter(array), Iter(array+size), odd_first());
    assert(base(r) == array + 1);
    assert(array[0] == P(1, 1));
    assert(array[1] == P(0, 2));
    assert(array[2] == P(2, 1));
    assert(array[3] == P(2, 2));
    assert(array[4] == P(4, 1));
    assert(array[5] == P(4, 2));
    assert(array[6] == P(6, 1));
    assert(array[7] == P(6, 2));
    assert(array[8] == P(8, 1));
    assert(array[9] == P(8, 2));
  }
  { // check all false but last true
    typedef std::pair<int,int> P;
    P array[] =
    {
        P(0, 1),
        P(0, 2),
        P(2, 1),
        P(2, 2),
        P(4, 1),
        P(4, 2),
        P(6, 1),
        P(6, 2),
        P(8, 1),
        P(1, 2)
    };
    const unsigned size = sizeof(array)/sizeof(array[0]);
    Iter r = std::stable_partition(Iter(array), Iter(array+size), odd_first());
    assert(base(r) == array + 1);
    assert(array[0] == P(1, 2));
    assert(array[1] == P(0, 1));
    assert(array[2] == P(0, 2));
    assert(array[3] == P(2, 1));
    assert(array[4] == P(2, 2));
    assert(array[5] == P(4, 1));
    assert(array[6] == P(4, 2));
    assert(array[7] == P(6, 1));
    assert(array[8] == P(6, 2));
    assert(array[9] == P(8, 1));
  }
  { // check all true but first false
    typedef std::pair<int,int> P;
    P array[] =
    {
        P(0, 1),
        P(1, 2),
        P(3, 1),
        P(3, 2),
        P(5, 1),
        P(5, 2),
        P(7, 1),
        P(7, 2),
        P(9, 1),
        P(9, 2)
    };
    const unsigned size = sizeof(array)/sizeof(array[0]);
    Iter r = std::stable_partition(Iter(array), Iter(array+size), odd_first());
    assert(base(r) == array + size-1);
    assert(array[0] == P(1, 2));
    assert(array[1] == P(3, 1));
    assert(array[2] == P(3, 2));
    assert(array[3] == P(5, 1));
    assert(array[4] == P(5, 2));
    assert(array[5] == P(7, 1));
    assert(array[6] == P(7, 2));
    assert(array[7] == P(9, 1));
    assert(array[8] == P(9, 2));
    assert(array[9] == P(0, 1));
  }
  { // check all true but last false
    typedef std::pair<int,int> P;
    P array[] =
    {
        P(1, 1),
        P(1, 2),
        P(3, 1),
        P(3, 2),
        P(5, 1),
        P(5, 2),
        P(7, 1),
        P(7, 2),
        P(9, 1),
        P(0, 2)
    };
    const unsigned size = sizeof(array)/sizeof(array[0]);
    Iter r = std::stable_partition(Iter(array), Iter(array+size), odd_first());
    assert(base(r) == array + size-1);
    assert(array[0] == P(1, 1));
    assert(array[1] == P(1, 2));
    assert(array[2] == P(3, 1));
    assert(array[3] == P(3, 2));
    assert(array[4] == P(5, 1));
    assert(array[5] == P(5, 2));
    assert(array[6] == P(7, 1));
    assert(array[7] == P(7, 2));
    assert(array[8] == P(9, 1));
    assert(array[9] == P(0, 2));
  }
#if TEST_STD_VER >= 11 && !defined(TEST_HAS_NO_EXCEPTIONS)
  // TODO: Re-enable this test for GCC once we get recursive inlining fixed.
  // For now it trips up GCC due to the use of always_inline.
#  if !defined(TEST_COMPILER_GCC)
  if (!TEST_IS_CONSTANT_EVALUATED) { // check that the algorithm still works when no memory is available
    std::vector<int> vec(150, 3);
    vec[5]                             = 6;
    getGlobalMemCounter()->throw_after = 0;
    std::stable_partition(vec.begin(), vec.end(), [](int i) { return i < 5; });
    assert(std::is_partitioned(vec.begin(), vec.end(), [](int i) { return i < 5; }));
    vec[5]                             = 6;
    getGlobalMemCounter()->throw_after = 0;
    std::stable_partition(
        bidirectional_iterator<int*>(vec.data()), bidirectional_iterator<int*>(vec.data() + vec.size()), [](int i) {
          return i < 5;
        });
    assert(std::is_partitioned(vec.begin(), vec.end(), [](int i) { return i < 5; }));
    getGlobalMemCounter()->reset();
  }
#  endif // !defined(TEST_COMPILER_GCC)
#endif   // TEST_STD_VER >= 11 && !defined(TEST_HAS_NO_EXCEPTIONS)
}

#if TEST_STD_VER >= 11

struct is_null {
  template <class P>
  TEST_CONSTEXPR_CXX26 bool operator()(const P& p) {
    return p == 0;
  }
};

template <class Iter>
TEST_CONSTEXPR_CXX26 void test1() {
  const unsigned size = 5;
  std::unique_ptr<int> array[size];
  Iter r = std::stable_partition(Iter(array), Iter(array + size), is_null());
  assert(r == Iter(array + size));
}

#endif // TEST_STD_VER >= 11

TEST_CONSTEXPR_CXX26 bool test() {
  test<bidirectional_iterator<std::pair<int, int>*> >();
  test<random_access_iterator<std::pair<int, int>*> >();
  test<std::pair<int, int>*>();

#if TEST_STD_VER >= 11
  test1<bidirectional_iterator<std::unique_ptr<int>*> >();
#endif

  return true;
}

int main(int, char**) {
  test();
#if TEST_STD_VER >= 26
  static_assert(test());
#endif

  return 0;
}
