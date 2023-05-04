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

"""macos_unit_test Starlark tests."""

load(
    ":common.bzl",
    "common",
)
load(
    "//test/starlark_tests/rules:analysis_failure_message_test.bzl",
    "analysis_failure_message_test",
)
load(
    "//test/starlark_tests/rules:analysis_output_group_info_files_test.bzl",
    "analysis_output_group_info_files_test",
)
load(
    "//test/starlark_tests/rules:apple_dsym_bundle_info_test.bzl",
    "apple_dsym_bundle_info_test",
)
load(
    "//test/starlark_tests/rules:apple_verification_test.bzl",
    "apple_verification_test",
)
load(
    "//test/starlark_tests/rules:common_verification_tests.bzl",
    "archive_contents_test",
)
load(
    "//test/starlark_tests/rules:infoplist_contents_test.bzl",
    "infoplist_contents_test",
)
load(
    "//test/starlark_tests/rules:analysis_runfiles_test.bzl",
    "analysis_runfiles_test",
)

visibility("private")

def macos_unit_test_test_suite(name):
    """Test suite for macos_unit_test.

    Args:
      name: the base name to be used in things created by this macro
    """
    apple_verification_test(
        name = "{}_codesign_test".format(name),
        build_type = "device",
        target_under_test = "//test/starlark_tests/targets_under_test/macos:unit_test",
        verifier_script = "verifier_scripts/codesign_verifier.sh",
        tags = [name],
    )

    archive_contents_test(
        name = "{}_additional_contents_test".format(name),
        build_type = "device",
        contains = [
            "$CONTENT_ROOT/Additional/additional.txt",
            "$CONTENT_ROOT/Nested/non_nested.txt",
            "$CONTENT_ROOT/Nested/nested/nested.txt",
        ],
        plist_test_file = "$CONTENT_ROOT/Info.plist",
        plist_test_values = {
            "BuildMachineOSBuild": "*",
            "CFBundleExecutable": "unit_test",
            "CFBundleIdentifier": "com.google.exampleTests",
            "CFBundleName": "unit_test",
            "CFBundlePackageType": "BNDL",
            "CFBundleSupportedPlatforms:0": "MacOSX",
            "DTCompiler": "com.apple.compilers.llvm.clang.1_0",
            "DTPlatformBuild": "*",
            "DTPlatformName": "macosx",
            "DTPlatformVersion": "*",
            "DTSDKBuild": "*",
            "DTSDKName": "macosx*",
            "DTXcode": "*",
            "DTXcodeBuild": "*",
            "LSMinimumSystemVersion": common.min_os_macos.baseline,
        },
        target_under_test = "//test/starlark_tests/targets_under_test/macos:unit_test",
        tags = [name],
    )

    analysis_output_group_info_files_test(
        name = "{}_dsyms_output_group_files_test".format(name),
        target_under_test = "//test/starlark_tests/targets_under_test/macos:unit_test",
        output_group_name = "dsyms",
        expected_outputs = [
            "app.app.dSYM/Contents/Resources/DWARF/app_arm64",
            "app.app.dSYM/Contents/Resources/DWARF/app_x86_64",
            "app.app.dSYM/Contents/Info.plist",
            "unit_test.xctest.dSYM/Contents/Resources/DWARF/unit_test_arm64",
            "unit_test.xctest.dSYM/Contents/Resources/DWARF/unit_test_x86_64",
            "unit_test.xctest.dSYM/Contents/Info.plist",
        ],
        tags = [name],
    )
    apple_dsym_bundle_info_test(
        name = "{}_apple_dsym_bundle_info_test".format(name),
        target_under_test = "//test/starlark_tests/targets_under_test/macos:unit_test",
        expected_direct_dsyms = ["dSYMs/unit_test.xctest.dSYM"],
        expected_transitive_dsyms = ["dSYMs/app.app.dSYM", "dSYMs/unit_test.xctest.dSYM"],
        tags = [name],
    )

    infoplist_contents_test(
        name = "{}_test_bundle_id_override".format(name),
        target_under_test = "//test/starlark_tests/targets_under_test/macos:unit_test_custom_bundle_id",
        expected_values = {
            "CFBundleIdentifier": "my.test.bundle.id",
        },
        tags = [name],
    )

    analysis_failure_message_test(
        name = "{}_test_bundle_id_same_as_test_host_error".format(name),
        target_under_test = "//test/starlark_tests/targets_under_test/macos:unit_test_invalid_bundle_id",
        expected_error = "The test bundle's identifier of 'com.google.example' can't be the same as the test host's bundle identifier. Please change one of them.",
        tags = [name],
    )

    archive_contents_test(
        name = "{}_builds_without_test_host".format(name),
        build_type = "simulator",
        target_under_test = "//test/starlark_tests/targets_under_test/macos:unit_test_no_host",
        cpus = {
            "macos_cpus": ["x86_64"],
        },
        binary_test_file = "$BINARY",
        binary_test_architecture = "x86_64",
        macho_load_commands_contain = ["cmd LC_BUILD_VERSION", "minos 11.0", "platform MACOS"],
        tags = [name],
    )

    analysis_runfiles_test(
        name = "{}_transitive_runfiles_included".format(name),
        tags = [name],
        target_under_test = "//test/starlark_tests/targets_under_test/macos:unit_test_data_deps",
        expected_runfiles = [
            "third_party/bazel_rules/rules_apple/test/starlark_tests/targets_under_test/macos/runfile1.txt",
            "third_party/bazel_rules/rules_apple/test/starlark_tests/targets_under_test/macos/runfile2.txt",
        ],
    )

    infoplist_contents_test(
        name = "{}_base_bundle_id_derived_bundle_id_plist_test".format(name),
        target_under_test = "//test/starlark_tests/targets_under_test/macos:unit_test_with_base_bundle_id_derived_bundle_id",
        expected_values = {
            "CFBundleIdentifier": "com.bazel.app.example.unit-test-with-base-bundle-id-derived-bundle-id",
        },
        tags = [name],
    )

    native.test_suite(
        name = name,
        tags = [name],
    )
