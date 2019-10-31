// Copyright 2019 The Chromium Authors
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

#include "components/services/storage/dom_storage/dom_storage_constants.h"

namespace storage {

// Electron's dom_storage_limits.patch increased this value from 10MiB to 100MiB
const size_t kPerStorageAreaQuota = 100 * 1024 * 1024;

const size_t kPerStorageAreaOverQuotaAllowance = 100 * 1024;

}  // namespace storage
