#include <CoreFoundation/CoreFoundation.h>
#include <CoreGraphics/CoreGraphics.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

static int number_value(
    CFDictionaryRef dictionary,
    CFStringRef key,
    int *value
) {
    CFNumberRef number = (CFNumberRef)CFDictionaryGetValue(dictionary, key);
    if (number == NULL || !CFNumberGetValue(number, kCFNumberIntType, value)) {
        return 0;
    }
    return 1;
}

static int string_equals(CFStringRef value, const char *expected) {
    if (value == NULL || expected == NULL) {
        return 0;
    }
    CFStringRef expected_string = CFStringCreateWithCString(
        kCFAllocatorDefault,
        expected,
        kCFStringEncodingUTF8
    );
    if (expected_string == NULL) {
        return 0;
    }
    int matches = CFStringCompare(value, expected_string, 0) == kCFCompareEqualTo;
    CFRelease(expected_string);
    return matches;
}

static void usage(const char *program) {
    fprintf(
        stderr,
        "usage: %s (--pid PID | --owner OWNER) [--title TITLE]\n",
        program
    );
}

int main(int argc, char **argv) {
    int requested_pid = 0;
    const char *requested_owner = NULL;
    const char *requested_title = "Moxi Playground";

    for (int index = 1; index < argc; index++) {
        if (strcmp(argv[index], "--pid") == 0 && index + 1 < argc) {
            requested_pid = (int)strtol(argv[++index], NULL, 10);
        } else if (
            strcmp(argv[index], "--owner") == 0 && index + 1 < argc
        ) {
            requested_owner = argv[++index];
        } else if (
            strcmp(argv[index], "--title") == 0 && index + 1 < argc
        ) {
            requested_title = argv[++index];
        } else {
            usage(argv[0]);
            return 2;
        }
    }

    if (requested_pid <= 0 && requested_owner == NULL) {
        usage(argv[0]);
        return 2;
    }

    CFArrayRef windows = CGWindowListCopyWindowInfo(
        kCGWindowListOptionOnScreenOnly | kCGWindowListExcludeDesktopElements,
        kCGNullWindowID
    );
    if (windows == NULL) {
        return 3;
    }

    CFIndex window_count = CFArrayGetCount(windows);
    for (CFIndex index = 0; index < window_count; index++) {
        CFDictionaryRef window = (CFDictionaryRef)CFArrayGetValueAtIndex(
            windows,
            index
        );
        int owner_pid = 0;
        if (!number_value(window, kCGWindowOwnerPID, &owner_pid)) {
            continue;
        }
        if (requested_pid > 0 && owner_pid != requested_pid) {
            continue;
        }

        CFStringRef owner_name = (CFStringRef)CFDictionaryGetValue(
            window,
            kCGWindowOwnerName
        );
        if (
            requested_owner != NULL
            && !string_equals(owner_name, requested_owner)
        ) {
            continue;
        }

        int layer = 0;
        if (!number_value(window, kCGWindowLayer, &layer) || layer != 0) {
            continue;
        }

        CFStringRef window_name = (CFStringRef)CFDictionaryGetValue(
            window,
            kCGWindowName
        );
        if (
            requested_title != NULL
            && !string_equals(window_name, requested_title)
        ) {
            continue;
        }

        CFDictionaryRef bounds_dictionary = (CFDictionaryRef)CFDictionaryGetValue(
            window,
            kCGWindowBounds
        );
        CGRect bounds;
        if (
            bounds_dictionary == NULL
            || !CGRectMakeWithDictionaryRepresentation(
                bounds_dictionary,
                &bounds
            )
            || bounds.size.width < 1.0
            || bounds.size.height < 1.0
        ) {
            continue;
        }

        int window_number = 0;
        if (!number_value(window, kCGWindowNumber, &window_number)) {
            window_number = 0;
        }
        printf(
            "%d %d %.0f %.0f %.0f %.0f\n",
            owner_pid,
            window_number,
            bounds.origin.x,
            bounds.origin.y,
            bounds.size.width,
            bounds.size.height
        );
        CFRelease(windows);
        return 0;
    }

    CFRelease(windows);
    return 1;
}
