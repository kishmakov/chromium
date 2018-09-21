// Copyright 2022 The Chromium Authors
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

#include "base/process/process_info.h"

#include "electron/mas.h"

#include <stdio.h>
#include <stdlib.h>
#include <unistd.h>

#if !IS_MAS_BUILD()
extern "C" {
pid_t responsibility_get_pid_responsible_for_pid(pid_t);
}
#endif

namespace base {

bool IsProcessSelfResponsible() {
#if !IS_MAS_BUILD()
  const pid_t pid = getpid();
  return responsibility_get_pid_responsible_for_pid(pid) == pid;
#else
  return true;
#endif
}

}  // namespace base
