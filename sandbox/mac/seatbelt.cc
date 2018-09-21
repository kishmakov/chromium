// Copyright 2016 The Chromium Authors
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

#include "sandbox/mac/seatbelt.h"

#include "electron/mas.h"

#include <errno.h>
#include <unistd.h>

extern "C" {
#include <sandbox.h>
#if !IS_MAS_BUILD()
int sandbox_init_with_parameters(const char* profile,
                                 uint64_t flags,
                                 const char* const parameters[],
                                 char** errorbuf);

// Not deprecated. The canonical usage to test if sandboxed is
// sandbox_check(getpid(), NULL, SANDBOX_FILTER_NONE), which returns
// 1 if sandboxed. Note `type` is actually a sandbox_filter_type enum value, but
// it is unused currently.
int sandbox_check(pid_t pid, const char* operation, int type, ...);

struct sandbox_params_t {
  const char** params;
  size_t size;
  size_t available;
};
sandbox_params_t* sandbox_create_params();
int sandbox_set_param(sandbox_params_t*, const char* key, const char* value);
void sandbox_free_params(sandbox_params_t*);

struct sandbox_profile_t {
  char* builtin;
  const uint8_t* data;
  size_t size;
};
sandbox_profile_t* sandbox_compile_string(const char* data,
                                          sandbox_params_t*,
                                          char** error);
int sandbox_apply(sandbox_profile_t*);
void sandbox_free_profile(sandbox_profile_t*);
#endif
}  // extern "C"

namespace sandbox {

namespace {
#if !IS_MAS_BUILD()
bool HandleSandboxResult(int rv, char* errorbuf, std::string* error) {
  if (rv == 0) {
    if (error)
      error->clear();
    return true;
  }

  if (error)
    *error = errorbuf;
  Seatbelt::FreeError(errorbuf);
  return false;
}

bool HandleSandboxErrno(int rv, const char* message, std::string* error) {
  if (rv == 0) {
    if (error)
      error->clear();
    return true;
  }

  if (error) {
    char* perror = strerror(errno);
    error->assign(message);
    error->append(perror);
  }
  return false;
}
#endif
}  // namespace

// static
Seatbelt::Parameters Seatbelt::Parameters::Create() {
  Parameters params;
#if !IS_MAS_BUILD()
  params.params_ = ::sandbox_create_params();
#endif
  return params;
}

Seatbelt::Parameters::Parameters() = default;

Seatbelt::Parameters::Parameters(Seatbelt::Parameters&& other) {
#if !IS_MAS_BUILD()
  params_ = std::exchange(other.params_, nullptr);
#endif
}

Seatbelt::Parameters& Seatbelt::Parameters::operator=(
    Seatbelt::Parameters&& other) {
#if !IS_MAS_BUILD()
  params_ = std::exchange(other.params_, nullptr);
#endif
  return *this;
}

bool Seatbelt::Parameters::Set(const char* key, const char* value) {
#if !IS_MAS_BUILD()
  return ::sandbox_set_param(params_, key, value) == 0;
#else
  return true;
#endif
}

Seatbelt::Parameters::~Parameters() {
#if !IS_MAS_BUILD()
  if (params_) {
    ::sandbox_free_params(params_);
  }
#endif
}

// Initialize the static member variables.
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
const char* Seatbelt::kProfilePureComputation = kSBXProfilePureComputation;
#pragma clang diagnostic pop

// static
bool Seatbelt::Init(const char* profile, uint64_t flags, std::string* error) {
#if !IS_MAS_BUILD()
// OS X deprecated these functions, but did not provide a suitable replacement,
// so ignore the deprecation warning.
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
  char* errorbuf = nullptr;
  int rv = ::sandbox_init(profile, flags, &errorbuf);
  return HandleSandboxResult(rv, errorbuf, error);
#pragma clang diagnostic pop
#else
  return true;
#endif
}

// static
bool Seatbelt::InitWithParams(const char* profile,
                              uint64_t flags,
                              const char* const parameters[],
                              std::string* error) {
#if !IS_MAS_BUILD()
  char* errorbuf = nullptr;
  int rv =
      ::sandbox_init_with_parameters(profile, flags, parameters, &errorbuf);
  return HandleSandboxResult(rv, errorbuf, error);
#else
  return true;
#endif
}

// static
bool Seatbelt::Compile(const char* profile,
                       const Seatbelt::Parameters& params,
                       std::string& compiled_profile,
                       std::string* error) {
#if !IS_MAS_BUILD()
  char* errorbuf = nullptr;
  sandbox_profile_t* sandbox_profile =
      ::sandbox_compile_string(profile, params.params(), &errorbuf);
  if (!HandleSandboxResult(sandbox_profile ? 0 : -1, errorbuf, error)) {
    return false;
  }
  compiled_profile.assign(reinterpret_cast<const char*>(sandbox_profile->data),
                          sandbox_profile->size);
  ::sandbox_free_profile(sandbox_profile);
#endif
  return true;
}

// static
bool Seatbelt::ApplyCompiledProfile(const std::string& profile,
                                    std::string* error) {
#if !IS_MAS_BUILD()
  sandbox_profile_t sbox_profile = {
      .builtin = nullptr,
      .data = reinterpret_cast<const uint8_t*>(profile.data()),
      .size = profile.size()};
  return HandleSandboxErrno(::sandbox_apply(&sbox_profile),
                            "sandbox_apply: ", error);
#else
  return true;
#endif
}

// static
void Seatbelt::FreeError(char* errorbuf) {
#if !IS_MAS_BUILD()
// OS X deprecated these functions, but did not provide a suitable replacement,
// so ignore the deprecation warning.
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
  return ::sandbox_free_error(errorbuf);
#pragma clang diagnostic pop
#endif
}

// static
bool Seatbelt::IsSandboxed() {
#if !IS_MAS_BUILD()
  return ::sandbox_check(getpid(), NULL, 0);
#else
  return true;
#endif
}

}  // namespace sandbox
