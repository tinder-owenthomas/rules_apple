#!/bin/bash

# Copyright 2019 The Bazel Authors. All rights reserved.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#    http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

set -euo pipefail

newline=$'\n'

# This script allows many of the functions in apple_shell_testutils.sh to be
# called through apple_verification_test_runner.sh.template by using environment
# variables.
#
# Supported operations:
#  CONTAINS: takes a list of files to test for existance. The filename will be
#      expanded with bash and can contain variables (e.g. $BUNDLE_ROOT)
#  NOT_CONTAINS: takes a list of files to test for non-existance. The filename
#      will be expanded with bash and can contain variables (e.g. $BUNDLE_ROOT)
#  IS_BINARY_PLIST: takes a list of paths to plist files and checks that they
#      are `binary` format. Filenames are expanded with bash.
#  IS_NOT_BINARY_PLIST: takes a list of paths to plist files and checks that
#      they are not `binary` format. Filenames are expanded with bash.
#  PLIST_TEST_FILE: The plist file to test with `PLIST_TEST_VALUES`.
#  PLIST_TEST_VALUES: Array for keys and values in the format "KEY VALUE" where
#      the key is in PlistBuddy format(which can't contain spaces), followed by
#      by a single space, followed by the value to test. * can be used as a
#      wildcard value.
#  ASSET_CATALOG_FILE: The Asset.car file to test with `ASSET_CATALOG_CONTAINS`.
#  ASSET_CATALOG_CONTAINS: Array of asset names that should exist.
#  ASSET_CATALOG_NOT_CONTAINS: Array of asset names that should not exist.
#  TEXT_TEST_FILE: The text file to test with `TEXT_TEST_VALUES`.
#  TEXT_TEST_VALUES: Array for regular expressions to test the contents of the
#      text file with. Regular expressions must follow POSIX Basic Regular
#      Expression (BRE) syntax.
#  BINARY_TEST_FILE: The file to test with `BINARY_TEST_SYMBOLS`
#  BINARY_TEST_ARCHITECTURE: The architecture to use with `BINARY_TEST_SYMBOLS`.
#  BINARY_CONTAINS_SYMBOLS: Array of symbols that should be present.
#  BINARY_NOT_CONTAINS_SYMBOLS: Array of symbols that should not be present.
#  BINARY_CONTAINS_REGEX_SYMBOLS: Array of regular expressions for symbols that
#      should be present. Regular expressions must follow POSIX Extended Regular
#      Expression (ERE) syntax.
#  MACHO_LOAD_COMMANDS_CONTAIN: Array of Mach-O load commands that should
#      be present.
#  MACHO_LOAD_COMMANDS_NOT_CONTAIN: Array of Mach-O load commands that should
#      not be present.

something_tested=false

# Test that the archive contains the specified files in the CONTAIN env var.
if [[ -n "${CONTAINS-}" ]]; then
  for path in "${CONTAINS[@]}"
  do
    something_tested=true
    expanded_path=$(eval echo "$path")
    if [[ ! -e $expanded_path ]]; then
      fail "Archive did not contain \"$expanded_path\"" \
        "contents were:$newline$(find $ARCHIVE_ROOT)"
    fi
  done
fi

# Test an array of regular expressions against the contents of a text file in
# the archive.
if [[ -n "${TEXT_TEST_FILE-}" ]]; then
  path=$(eval echo "$TEXT_TEST_FILE")
  if [[ ! -e $path ]]; then
    fail "Archive did not contain text file at \"$path\"" \
      "contents were:$newline$(find $ARCHIVE_ROOT)"
  fi
  for test_regexp in "${TEXT_TEST_VALUES[@]}"
  do
    something_tested=true
    if [[ $(grep -c "$test_regexp" "$path") == 0 ]]; then
      fail "Expected regexp \"$test_regexp\" did not match" \
        "contents of text file at \"$path\""
    fi
  done
else
  if [[ -n "${TEXT_TEST_VALUES-}" ]]; then
      fail "Rule Misconfigured: Supposed to look for values in a file," \
        "but no file was set to check: ${TEXT_TEST_VALUES[@]}"
  fi
fi

# Test that the archive contains and does not contain the specified symbols.
if [[ -n "${BINARY_TEST_FILE-}" ]]; then
  path=$(eval echo "$BINARY_TEST_FILE")
  if [[ ! -e $path ]]; then
    fail "Archive did not contain binary at \"$path\"" \
      "contents were:$newline$(find $ARCHIVE_ROOT)"
  fi
  if [[ -n "${BINARY_TEST_ARCHITECTURE-}" ]]; then
    arch=$(eval echo "$BINARY_TEST_ARCHITECTURE")
    if [[ ! -n $arch ]]; then
      fail "No architecture specified for binary file at \"$path\""
    fi

    # Filter out undefined symbols from the objdump mach-o symbol output and
    # return the rightmost value; these binary symbols will not have spaces.
    IFS=$'\n' actual_symbols=($(objdump --syms --macho --arch="$arch" "$path" | grep -v "*UND*" | awk '{print substr($0,index($0,$5))}'))
    if [[ -n "${BINARY_CONTAINS_SYMBOLS-}" ]]; then
      for test_symbol in "${BINARY_CONTAINS_SYMBOLS[@]}"
      do
        something_tested=true
        symbol_found=false
        for actual_symbol in "${actual_symbols[@]}"
        do
          if [[ "$actual_symbol" == "$test_symbol" ]]; then
            symbol_found=true
            break
          fi
        done
        if [[ "$symbol_found" = false ]]; then
            fail "Expected symbol \"$test_symbol\" was not found. The " \
              "symbols in the binary were:$newline${actual_symbols[@]}"
        fi
      done
    fi

    if [[ -n "${BINARY_CONTAINS_REGEX_SYMBOLS-}" ]]; then
      for test_regex in "${BINARY_CONTAINS_REGEX_SYMBOLS[@]}"
      do
        something_tested=true
        symbol_found=false
        for actual_symbol in "${actual_symbols[@]}"
        do
          if [[ "$actual_symbol" =~ $test_regex ]]; then
            symbol_found=true
            break
          fi
        done
        if [[ "$symbol_found" = false ]]; then
            fail "Expected symbol \"$test_regex\" was not found. The " \
              "symbols in the binary were:$newline${actual_symbols[@]}"
        fi
      done
    fi

    if [[ -n "${BINARY_NOT_CONTAINS_SYMBOLS-}" ]]; then
      for test_symbol in "${BINARY_NOT_CONTAINS_SYMBOLS[@]}"
      do
        something_tested=true
        symbol_found=false
        for actual_symbol in "${actual_symbols[@]}"
        do
          if [[ "$actual_symbol" == "$test_symbol" ]]; then
            symbol_found=true
            break
          fi
        done
        if [[ "$symbol_found" = true ]]; then
            fail "Unexpected symbol \"$test_symbol\" was found. The symbols " \
              "in the binary were:$newline${actual_symbols[@]}"
        fi
      done
    fi
  else
    if [[ -n "${BINARY_CONTAINS_SYMBOLS-}" ]]; then
      fail "Rule Misconfigured: Supposed to look for symbols," \
        "but no arch was set to check: ${BINARY_CONTAINS_SYMBOLS[@]}"
    fi
    if [[ -n "${BINARY_CONTAINS_REGEX_SYMBOLS-}" ]]; then
      fail "Rule Misconfigured: Supposed to look for symbols," \
        "but no arch was set to check: ${BINARY_CONTAINS_REGEX_SYMBOLS[@]}"
    fi
    if [[ -n "${BINARY_NOT_CONTAINS_SYMBOLS-}" ]]; then
      fail "Rule Misconfigured: Supposed to look for missing symbols," \
        "but no arch was set to check: ${BINARY_NOT_CONTAINS_SYMBOLS[@]}"
    fi
  fi

  if [[ -n "${MACHO_LOAD_COMMANDS_CONTAIN-}" || -n "${MACHO_LOAD_COMMANDS_NOT_CONTAIN-}" ]]; then
    # The `otool` commands below remove the leftmost white space from the
    # output to make string matching of symbols possible, avoiding the
    # accidental elimination of white space from paths and identifiers.
    IFS=$'\n'
    if [[ -n "${BINARY_TEST_ARCHITECTURE-}" ]]; then
      arch=$(eval echo "$BINARY_TEST_ARCHITECTURE")
      if [[ ! -n $arch ]]; then
        fail "No architecture specified for binary file at \"$path\""
      else
        actual_symbols=($(otool -v -arch "$arch" -l "$path" | awk '{$1=$1}1'))
      fi
    else
      actual_symbols=($(otool -v -l "$path" | awk '{$1=$1}1'))
    fi
    if [[ -n "${MACHO_LOAD_COMMANDS_CONTAIN-}" ]]; then
      for test_symbol in "${MACHO_LOAD_COMMANDS_CONTAIN[@]}"
      do
        something_tested=true
        symbol_found=false
        for actual_symbol in "${actual_symbols[@]}"
        do
          if [[ "$actual_symbol" == "$test_symbol" ]]; then
            symbol_found=true
            break
          fi
        done
        if [[ "$symbol_found" = false ]]; then
            fail "Expected load command \"$test_symbol\" was not found." \
              "The load commands in the binary were:" \
              "$newline${actual_symbols[@]}"
        fi
      done
    fi

    if [[ -n "${MACHO_LOAD_COMMANDS_NOT_CONTAIN-}" ]]; then
      for test_symbol in "${MACHO_LOAD_COMMANDS_NOT_CONTAIN[@]}"
      do
        something_tested=true
        symbol_found=false
        for actual_symbol in "${actual_symbols[@]}"
        do
          if [[ "$actual_symbol" == "$test_symbol" ]]; then
            symbol_found=true
            break
          fi
        done
        if [[ "$symbol_found" = true ]]; then
            fail "Unexpected load command \"$test_symbol\" was found." \
              "The load commands in the binary were:" \
              "$newline${actual_symbols[@]}"
        fi
      done
    fi
  fi
else
  if [[ -n "${BINARY_TEST_ARCHITECTURE-}" ]]; then
    fail "Rule Misconfigured: Binary arch was set," \
      "but no binary was set to check: ${BINARY_TEST_ARCHITECTURE}"
  fi
  if [[ -n "${BINARY_CONTAINS_SYMBOLS-}" ]]; then
    fail "Rule Misconfigured: Supposed to look for symbols," \
      "but no binary was set to check: ${BINARY_CONTAINS_SYMBOLS[@]}"
  fi
  if [[ -n "${BINARY_NOT_CONTAINS_SYMBOLS-}" ]]; then
    fail "Rule Misconfigured: Supposed to look for missing symbols," \
      "but no binary was set to check: ${BINARY_NOT_CONTAINS_SYMBOLS[@]}"
  fi
  if [[ -n "${BINARY_CONTAINS_REGEX_SYMBOLS-}" ]]; then
    fail "Rule Misconfigured: Supposed to look for regex symbols," \
      "but no binary was set to check: ${BINARY_CONTAINS_REGEX_SYMBOLS[@]}"
  fi
  if [[ -n "${MACHO_LOAD_COMMANDS_CONTAIN-}" ]]; then
    fail "Rule Misconfigured: Supposed to look for macho load commands," \
      "but no binary was set to check: ${BINARY_NOT_CONTAINS_SYMBOLS[@]}"
  fi
  if [[ -n "${MACHO_LOAD_COMMANDS_NOT_CONTAIN-}" ]]; then
    fail "Rule Misconfigured: Supposed to look for missing macho load commands," \
      "but no binary was set to check: ${MACHO_LOAD_COMMANDS_NOT_CONTAIN[@]}"
  fi
fi

# Test that the archive doesn't contains the specified files in NOT_CONTAINS.
if [[ -n "${NOT_CONTAINS-}" ]]; then
  for path in "${NOT_CONTAINS[@]}"
  do
    something_tested=true
    expanded_path=$(eval echo "$path")
    if [[ -e $expanded_path ]]; then
      fail "Archive did contain \"$expanded_path\"" \
        "contents were:$newline$(find $ARCHIVE_ROOT)"
    fi
  done
fi

# Test that plist files are in a binary format.
if [[ -n "${IS_BINARY_PLIST-}" ]]; then
  for path in "${IS_BINARY_PLIST[@]}"
  do
    something_tested=true
    expanded_path=$(eval echo "$path")
    if [[ ! -e $expanded_path ]]; then
      fail "Archive did not contain plist \"$expanded_path\"" \
        "contents were:$newline$(find $ARCHIVE_ROOT)"
    fi
    if ! grep -sq "^bplist00" $expanded_path; then
      fail "Plist does not have binary format \"$expanded_path\""
    fi
  done
fi

# Test that plist files are not in a binary format.
if [[ -n "${IS_NOT_BINARY_PLIST-}" ]]; then
  for path in "${IS_NOT_BINARY_PLIST[@]}"
  do
    something_tested=true
    expanded_path=$(eval echo "$path")
    if [[ ! -e $expanded_path ]]; then
      fail "Archive did not contain plist \"$expanded_path\"" \
        "contents were:$newline$(find $ARCHIVE_ROOT)"
    fi
    if grep -sq "^bplist00" $expanded_path; then
      fail "Plist has binary format \"$expanded_path\""
    fi
  done
fi

# Use `PlistBuddy` to test for key/value pairs in a plist/string file.
if [[ -n "${PLIST_TEST_VALUES-}" ]]; then
  if [[ ${#PLIST_TEST_FILE[@]} -eq 0 ]]; then
    fail "Plist test values passed, but no plist file specified."
  fi
  path=$(eval echo "$PLIST_TEST_FILE")
  if [[ ! -e $path ]]; then
    fail "Archive did not contain plist at \"$path\"" \
      "contents were:$newline$(find $ARCHIVE_ROOT)"
  fi
  for test_values in "${PLIST_TEST_VALUES[@]}"
  do
    something_tested=true
    # Keys and expected-values are in the format "KEY VALUE".
    IFS=' ' read -r key expected_value <<< "$test_values"
    value="$(/usr/libexec/PlistBuddy -c "Print $key" $path 2>/dev/null || true)"
    if [[ -z "$value" ]]; then
      fail "Expected \"$key\" to be in plist \"$path\". Plist contents:" \
        "$newline$(/usr/libexec/PlistBuddy -c Print $path)"
    fi
    if [[ "$value" != $expected_value ]]; then
      fail "Expected plist value \"$value\" at key \"$key\" to be \"$expected_value\""
    fi
  done
fi

# Use `assetutil` to test for asset names in a car file.
if [[ -n "${ASSET_CATALOG_FILE-}" ]]; then
  path=$(eval echo "$ASSET_CATALOG_FILE")
  if [[ ! -e $path ]]; then
    fail "Archive did not contain asset catalog at \"$path\"" \
      "contents were:$newline$(find $ARCHIVE_ROOT)"
  fi
  # Get the JSON representation of the Asset catalog.
  json=$(/usr/bin/assetutil -I "$path")

  # Use a regular expression to extract the "Name" fields with each value on a
  # separate line.
  asset_names=$(sed -nE 's/\"Name\"[[:space:]]*:[[:space:]]*\"([^\"]*)\".*/\1/p' <<< "$json")

  if [[ -n "${ASSET_CATALOG_CONTAINS-}" ]]; then
    for expected_name in "${ASSET_CATALOG_CONTAINS[@]}"
    do
      something_tested=true
      name_found=false
      # Loop over the known asset names. `while read` loops loop over lines.
      while read -r actual_name
      do
        if [[ "$actual_name" == "$expected_name" ]]; then
          name_found=true
          break
        fi
      done <<< "$asset_names"
      if [[ "$name_found" = false ]]; then
        fail "Expected asset name \"$expected_name\" was not found." \
          "The names in the asset were:$newline${asset_names[@]}"
      fi
    done
  fi

  if [[ -n "${ASSET_CATALOG_NOT_CONTAINS-}" ]]; then
    for unexpected_name in "${ASSET_CATALOG_NOT_CONTAINS[@]}"
    do
      something_tested=true
      name_found=false
      # Loop over the known asset names. `while read` loops loop over lines.
      while read -r actual_name
      do
        if [[ "$actual_name" == "$unexpected_name" ]]; then
          name_found=true
          break
        fi
      done <<< "$asset_names"
      if [[ "$name_found" = true ]]; then
        fail "Unexpected asset name \"$unexpected_name\" was found."
      fi
    done
  fi
fi

if [[ "$something_tested" = false ]]; then
  fail "Rule Misconfigured: Nothing was configured to be tested in archive: \"$path\""
fi
