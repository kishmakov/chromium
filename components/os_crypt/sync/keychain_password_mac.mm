// Copyright 2014 The Chromium Authors
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

#include "components/os_crypt/sync/keychain_password_mac.h"

#import <Security/Security.h>

#include "base/apple/osstatus_logging.h"
#include "base/apple/scoped_cftyperef.h"
#include "base/base64.h"
#include "base/no_destructor.h"
#include "base/rand_util.h"
#include "build/branding_buildflags.h"
#include "crypto/apple_keychain.h"
#include "electron/mas.h"

using crypto::AppleKeychain;

#if defined(ALLOW_RUNTIME_CONFIGURABLE_KEY_STORAGE)
using KeychainNameContainerType = base::NoDestructor<std::string>;
#else
using KeychainNameContainerType = const base::NoDestructor<std::string>;
#endif

#if IS_MAS_BUILD()
const char kAccountNameSuffix[] = " App Store Key";
#else
const char kAccountNameSuffix[] = " Key";
#endif

namespace {

// These two strings ARE indeed user facing.  But they are used to access
// the encryption keyword.  So as to not lose encrypted data when system
// locale changes we DO NOT LOCALIZE.
#if BUILDFLAG(GOOGLE_CHROME_BRANDING)
const char kDefaultServiceName[] = "Chrome Safe Storage";
const char kDefaultAccountName[] = "Chrome";
#else
const char kDefaultServiceName[] = "Chromium Safe Storage";
const char kDefaultAccountName[] = "Chromium";
#endif

// Generates a random password and adds it to the Keychain.  The added password
// is returned from the function.  If an error occurs, an empty password is
// returned.
std::string AddRandomPasswordToKeychain(const AppleKeychain& keychain,
                                        const std::string& service_name,
                                        const std::string& account_name) {
  // Generate a password with 128 bits of randomness.
  const int kBytes = 128 / 8;
  std::string password = base::Base64Encode(base::RandBytesAsVector(kBytes));
  void* password_data =
      const_cast<void*>(static_cast<const void*>(password.data()));

  OSStatus error = keychain.AddGenericPassword(
      service_name.size(), service_name.data(), account_name.size(),
      account_name.data(), password.size(), password_data, /*item=*/nullptr);

  if (error != noErr) {
    OSSTATUS_DLOG(ERROR, error) << "Keychain add failed";
    return std::string();
  }

  return password;
}

}  // namespace

// static
KeychainPassword::KeychainNameType& KeychainPassword::GetServiceName() {
  static KeychainNameContainerType service_name(kDefaultServiceName);
  return *service_name;
}

// static
KeychainPassword::KeychainNameType& KeychainPassword::GetAccountName() {
  static KeychainNameContainerType account_name(kDefaultAccountName);
  return *account_name;
}

KeychainPassword::KeychainPassword(const AppleKeychain& keychain)
    : keychain_(keychain) {}

KeychainPassword::~KeychainPassword() = default;

std::string KeychainPassword::GetPassword() const {
  UInt32 password_length = 0;
  void* password_data = nullptr;
  KeychainPassword::KeychainNameType service_name = GetServiceName();
  KeychainPassword::KeychainNameType account_name = GetAccountName();
  const std::string account_name_suffix = kAccountNameSuffix;
  const std::string suffixed_account_name = account_name + account_name_suffix;

  // We should check if the suffixed account exists first
  OSStatus error = keychain_->FindGenericPassword(
      service_name.size(), service_name.c_str(),
      suffixed_account_name.size(), suffixed_account_name.c_str(), &password_length,
      &password_data, /*item=*/nullptr);

  // If it exists we can return it immediately
  if (error == noErr) {
    std::string password =
        std::string(static_cast<char*>(password_data), password_length);
    keychain_->ItemFreeContent(password_data);
    return password;
  }

  // If the error was anything other than "it does not exist" we should error out here
  // This normally means the account exists but we were deniged access to it
  if (error != errSecItemNotFound) {
    OSSTATUS_LOG(ERROR, error) << "Keychain lookup for suffixed key failed";
    return std::string();
  }

  // If the suffixed account didn't exist, we should check if the legacy non-suffixed account
  // exists. If it does we can use that key and migrate it to the new account
  base::apple::ScopedCFTypeRef<SecKeychainItemRef> item_ref;
  error = keychain_->FindGenericPassword(
      service_name.size(), service_name.c_str(),
      account_name.size(), account_name.c_str(), &password_length,
      &password_data, item_ref.InitializeInto());

  if (error == noErr) {
    std::string password =
        std::string(static_cast<char*>(password_data), password_length);

    // If we found the legacy account name we should copy it over to
    // the new suffixed account
    error = keychain_->AddGenericPassword(
        service_name.size(), service_name.data(), suffixed_account_name.size(),
        suffixed_account_name.data(), password.size(), password_data, NULL);

    if (error == noErr) {
      // If we successfully made the suffixed account we can delete the old
      // account to ensure new apps don't try to use it and run into IAM
      // issues
      error = keychain_->ItemDelete(item_ref.get());
      if (error != noErr) {
        OSSTATUS_DLOG(ERROR, error) << "Keychain delete for legacy key failed";
      }
    } else {
      OSSTATUS_DLOG(ERROR, error) << "Keychain add for suffixed key failed";
    }

    keychain_->ItemFreeContent(password_data);
    return password;
  }

  // If the legacy account name was not found, make a new account in the
  // with the suffixed name
  if (error == errSecItemNotFound) {
    std::string password = AddRandomPasswordToKeychain(
        *keychain_, GetServiceName(), GetAccountName());
    return password;
  }

  OSSTATUS_LOG(ERROR, error) << "Keychain lookup failed";
  return std::string();
}
