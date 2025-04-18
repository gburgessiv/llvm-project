//===-- Unittests for read and write --------------------------------------===//
//
// Part of the LLVM Project, under the Apache License v2.0 with LLVM Exceptions.
// See https://llvm.org/LICENSE.txt for license information.
// SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
//
//===----------------------------------------------------------------------===//

#include "src/fcntl/open.h"
#include "src/stdio/remove.h"
#include "src/unistd/close.h"
#include "src/unistd/fsync.h"
#include "src/unistd/read.h"
#include "src/unistd/write.h"
#include "test/UnitTest/ErrnoCheckingTest.h"
#include "test/UnitTest/ErrnoSetterMatcher.h"
#include "test/UnitTest/Test.h"

#include <sys/stat.h>

using LlvmLibcUniStd = LIBC_NAMESPACE::testing::ErrnoCheckingTest;

TEST_F(LlvmLibcUniStd, WriteAndReadBackTest) {
  using LIBC_NAMESPACE::testing::ErrnoSetterMatcher::Succeeds;
  constexpr const char *FILENAME = "__unistd_read_write.test";
  auto TEST_FILE = libc_make_test_file_path(FILENAME);

  int write_fd = LIBC_NAMESPACE::open(TEST_FILE, O_WRONLY | O_CREAT, S_IRWXU);
  ASSERT_ERRNO_SUCCESS();
  ASSERT_GT(write_fd, 0);
  constexpr const char HELLO[] = "hello";
  constexpr ssize_t HELLO_SIZE = sizeof(HELLO);
  ASSERT_THAT(LIBC_NAMESPACE::write(write_fd, HELLO, HELLO_SIZE),
              Succeeds(HELLO_SIZE));
  ASSERT_THAT(LIBC_NAMESPACE::fsync(write_fd), Succeeds(0));
  ASSERT_THAT(LIBC_NAMESPACE::close(write_fd), Succeeds(0));

  int read_fd = LIBC_NAMESPACE::open(TEST_FILE, O_RDONLY);
  ASSERT_ERRNO_SUCCESS();
  ASSERT_GT(read_fd, 0);
  char read_buf[10];
  ASSERT_THAT(LIBC_NAMESPACE::read(read_fd, read_buf, HELLO_SIZE),
              Succeeds(HELLO_SIZE));
  EXPECT_STREQ(read_buf, HELLO);
  ASSERT_THAT(LIBC_NAMESPACE::close(read_fd), Succeeds(0));

  ASSERT_THAT(LIBC_NAMESPACE::remove(TEST_FILE), Succeeds(0));
}

TEST_F(LlvmLibcUniStd, WriteFails) {
  using LIBC_NAMESPACE::testing::ErrnoSetterMatcher::Fails;

  EXPECT_THAT(LIBC_NAMESPACE::write(-1, "", 1), Fails<ssize_t>(EBADF));
  EXPECT_THAT(LIBC_NAMESPACE::write(1, reinterpret_cast<const void *>(-1), 1),
              Fails<ssize_t>(EFAULT));
}

TEST_F(LlvmLibcUniStd, ReadFails) {
  using LIBC_NAMESPACE::testing::ErrnoSetterMatcher::Fails;

  EXPECT_THAT(LIBC_NAMESPACE::read(-1, nullptr, 1), Fails<ssize_t>(EBADF));
  EXPECT_THAT(LIBC_NAMESPACE::read(0, reinterpret_cast<void *>(-1), 1),
              Fails<ssize_t>(EFAULT));
}
