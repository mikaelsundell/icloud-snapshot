Readme for icloud-snapshot
==========================

[![License](https://img.shields.io/badge/license-BSD%203--Clause-blue.svg?style=flat-square)](https://github.com/mikaelsundell/icloud-snapshot/blob/master/license.md)

Introduction
------------

icloud-snapshot is a utility to copy an icloud directory to a snapshot directory for archival purposes. The utility will download and release local items when needed to save disk space.

Documentation
-------------

```shell
> icloud-snapshot --help

  OVERVIEW: icloud-snapshot is a utility to copy an icloud directory to a
  snapshot directory for archival purposes.

  USAGE: i-cloud-snapshot <icloud_dir> <snapshot_dir> [--timecode_snapshot] [--overwrite_files] [--evict_files] [--skip_snapshot_files] [--debug]

  ARGUMENTS:
    <icloud_dir>            icloud directory
    <snapshot_dir>          snapshot directory

  OPTIONS:
    --timecode_snapshot     Timecode snapshot
    --overwrite_files       Overwrite files
    --evict_files           Evict files
    --skip_snapshot_files   Skip snapshot files
    --debug                 Debug information
    -h, --help              Show help information.
``` 
  
**iCloud and snapshot directories**

The icloud directory is typically found at `<user path>/Library/Mobile Documents/com~apple~CloudDocs`, append an additional path if needed. The snapshot directory is where files will be copied to. Use the `--timecode_snapshot` flag to add append a timecode directory.

**Overwrite files**

The overwrite_files flag will make sure files will be overwritten. If the `--timecode_snapshot` flag is not used the snapshot will try to overwrite existing files if exists.

**Evict files**

The `--evict_files` flag will remove all local files from the icloud directory before the snapshot runs. This is useful along with the `--skip_snapshot_files` flag if local copies should be removed from the icloud directory without creating a snapshot.

**Skip snapshot files**

The `--skip_snapshot_files` will skip the snapshot creation, see evict files.

**Debug**

The `--debug` flag will output debug information.

**Other notes**

If the snapshot is created while the computer is locked make sure you prevent it from sleeping, see `Prevent your Mac from automatically sleeping when display is off` checkbox in Energy Saver panel in System Preferences.

**Limitations**

Currently files starting with a `..` is not supported and will cause the icloud api's to fail. Such files are reported at the end of icloud-snapshot run. At all times watch out for the progress next to the icloud icon in the finder side view, in rare cases the icloud daemon fails to sync and will stall the process.

The Security & Privacy settings needs to Allow icloud-snapshot, after first download open the panel in System Preferences and click Allow.
  
Packaging
---------

The icloud-snapshot project uses Swift Packages, create a new package:

```shell
> mkdir icloud-snapshot_macOS12-<version>
> swift build --build-path build --configuration release --arch arm64 --arch x86_64
> cp build/apple/Products/Release/icloud-snapshot ./icloud-snapshot_macOS12-<version>
> cp README.md LICENSE ./icloud-snapshot_macOS12-<version>
> tar -czf icloud-snapshot_macOS12-<version>.tar.gz icloud-snapshot_macOS12-<version>
```

Web Resources
-------------

GitHub page:        http://github.com/mikaelsundell/icloud-snapshot
