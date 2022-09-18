//
//  main.swift
//  icloud-snapshot
//
//  Copyright (c) 2022 - present Mikael Sundell.
//  All Rights Reserved.
//
//  icloud-snapshot is a utility to copy an icloud directory to a
//  snapshot directory for archival purposes. The utility will download
//  and release local items when needed to save disk space.

import Foundation
import ArgumentParser

// icloud flags
var icloud_overwrite = false

// debug flags
var debug_output = false
var debug_total_size = Int64(0)

// formatter utilities
func format_date_stamp(date: Date) -> String
{
    let date_formatter = DateFormatter()
    date_formatter.dateFormat = "dd MMM yy HH:mm:ss"
    return date_formatter.string(from: date)
}

func format_time_stamp(seconds: Int64) -> String
{
    let date_components_formatter = DateComponentsFormatter()
    date_components_formatter.allowedUnits = [.hour, .minute, .second]
    date_components_formatter.unitsStyle = .full
    return date_components_formatter.string(from: TimeInterval(seconds))!
}

func format_data_size(data: Int64) -> String {
    let byte_count_formatter = ByteCountFormatter()
    byte_count_formatter.allowedUnits = [.useMB] // optional: restricts the units to MB only
    byte_count_formatter.countStyle = .file
    return byte_count_formatter.string(fromByteCount: data)
}

// print utilities
func info_print(message: String)
{
    print("info [\(format_date_stamp(date: Date.now))]: " + message)
}

func warning_print(message: String)
{
    print("warning [\(format_date_stamp(date: Date.now))]: " + message)
}

func error_print(message: String)
{
    print("error [\(format_date_stamp(date: Date.now))]: " + message)
}


func debug_print(message: String)
{
    print("debug [\(format_date_stamp(date: Date.now))]: " + message)
}

// string utilites
func url_to_path(url: URL) -> String {
    return url.path
}

// evict utilities
func icloud_evict_file(evict_url: URL)
{
    info_print(message: "evict file: \(url_to_path(url: evict_url))");
    
    do
    {
        let resources = try evict_url.resourceValues(forKeys: [.isUbiquitousItemKey, .ubiquitousItemDownloadingStatusKey])
        if resources.isUbiquitousItem ?? true {
                       
            if resources.ubiquitousItemDownloadingStatus == .downloaded {
                try FileManager.default.evictUbiquitousItem(at: evict_url)
                
            }
            else
            {
                info_print(message: "file is not downloaded: \(url_to_path(url: evict_url)), will be skipped");
            }
        }
        else
        {
            info_print(message: "file is local: \(url_to_path(url: evict_url)), will be skipped");
        }
    }
    catch
    {
        error_print(message: "could not evict file: \(url_to_path(url: evict_url)) error: \(error)")
    }
}

func icloud_evict_url(evict_url: URL)
{
    info_print(message: "evict dir: \(url_to_path(url: evict_url))");

    // pre-fetch keys for copy
    let fetch_keys = [
        URLResourceKey.isRegularFileKey]
    
    // load contents
    let urls = try! FileManager.default.contentsOfDirectory(at: evict_url, includingPropertiesForKeys: fetch_keys)
    for url in urls {
        do
        {
            let resources = try url.resourceValues(forKeys: [.isRegularFileKey])
            if resources.isRegularFile ?? true {
                
                // snapshot file
                icloud_evict_file(evict_url: url)
                
            } else {
            
                // evict dir
                icloud_evict_url(evict_url: url)
            }
         
        } catch {
            error_print(message: "file or directory does not exist: \(url_to_path(url: evict_url)) error: \(error)")
        }
    }
}

// snapshot utilities
func icloud_copy_file(copy_url: URL, snapshot_url: URL)
{
    do
    {
        // only copy if file does not exists
        if (!FileManager.default.fileExists(atPath: snapshot_url.path) || icloud_overwrite) {
        
            try FileManager.default.copyItem(atPath: copy_url.path, toPath: snapshot_url.path)
            
            // debug
            if (debug_output) {
                let resourceValues = try snapshot_url.resourceValues(forKeys: [.fileSizeKey])
                let fileSize = Int64(resourceValues.fileSize!)
                debug_total_size += fileSize
                
                debug_print(message: "copy file size: \(format_data_size(data: fileSize)) total copy: \(format_data_size(data: debug_total_size))")
            }
        }
        else
        {
            info_print(message: "file exists: \(url_to_path(url: snapshot_url)) will be skipped")
        }
    }
    catch
    {
        error_print(message: "could not snapshot file: \(url_to_path(url: snapshot_url)) error: \(error)")
    }
}

func icloud_snapshot_file(copy_url: URL, snapshot_url: URL)
{
    info_print(message: "snapshot file: \(url_to_path(url: copy_url))");
    
    let copy_file = copy_url.lastPathComponent
    do
    {
        let resources = try copy_url.resourceValues(forKeys: [.isUbiquitousItemKey, .ubiquitousItemDownloadingStatusKey])
        if resources.isUbiquitousItem ?? true {
                       
            if resources.ubiquitousItemDownloadingStatus != .current {
                info_print(message: "- download file: \(url_to_path(url: copy_url))")
                
                // name local copy
                let copy_dir = copy_url.deletingLastPathComponent()
                var local_file = copy_file
                
                // remove initial "." and ending ".icloud" from result
                local_file.removeFirst()
                local_file = local_file.replacingOccurrences(of: ".icloud", with: "")
                
                let copy_local_url = copy_dir.appendingPathComponent(local_file)
                
                // name snapshot copy
                let snapshot_file_url = snapshot_url.appendingPathComponent(copy_local_url.lastPathComponent)
                if (!FileManager.default.fileExists(atPath: snapshot_file_url.path)) {
                    
                    do {
                        
                        // download local copy
                        try FileManager.default.startDownloadingUbiquitousItem(at: copy_url)

                        // wait for completition
                        var downloaded = false
                        while (!downloaded) {
                            
                            do {
                                // A new URL needs to be created to force complete
                                // reload of resoure values between calls.
                                let resouces_local_url = URL(fileURLWithPath: copy_local_url.path)
                                let download_resources = try resouces_local_url.resourceValues(forKeys: [.ubiquitousItemDownloadingStatusKey])
                                if download_resources.ubiquitousItemDownloadingStatus == .current {
                                    
                                    info_print(message: "- download complete: \(url_to_path(url: resouces_local_url))")
                                    downloaded = true
                                    break;
                                }
                                
                            } catch {
                                error_print(message: "- could not request download status for file: \(url_to_path(url: copy_local_url)) error: \(error)")
                            }
                            
                            Thread.sleep(forTimeInterval: 0.5)
                        }

                        info_print(message: "- copy file: \(url_to_path(url: copy_local_url))")
                        
                        // snapshot local file
                        icloud_copy_file(copy_url: copy_local_url, snapshot_url: snapshot_file_url)
                    
                        // remove file
                        info_print(message: "- remove download file: \(url_to_path(url: copy_local_url))")
                        icloud_evict_file(evict_url: copy_local_url)
                               
                    } catch {
                        error_print(message: "- could not download file: \(url_to_path(url: copy_url)) error: \(error)")
                    }
                }
                else
                {
                    info_print(message: "file exists: \(url_to_path(url: snapshot_url)) will be skipped")
                }

            } else {
                info_print(message: "- local file exists: \(url_to_path(url: copy_url))")
                info_print(message: "- snapshot file: \(url_to_path(url: copy_url))")
                
                // copy local file
                let snapshot_file_url = snapshot_url.appendingPathComponent(copy_file)
                icloud_copy_file(copy_url: copy_url, snapshot_url: snapshot_file_url)
            }
            
        } else {
            
            info_print(message: "- local file exists: \(url_to_path(url: copy_url))")
            info_print(message: "- snapshot file: \(url_to_path(url: copy_url))")
            
            // copy local file
            let snapshot_file_url = snapshot_url.appendingPathComponent(copy_file)
            icloud_copy_file(copy_url: copy_url, snapshot_url: snapshot_file_url)
        }
        
    } catch {
        error_print(message: "could not snapshot file: \(url_to_path(url: copy_url)) error: \(error)")
    }

}

func icloud_snapshot_url(copy_url: URL, snapshot_url: URL)
{
    info_print(message: "copy dir: \(url_to_path(url: copy_url))");
    do {
        // create directory
        info_print(message: "- create dir: \(snapshot_url)")
        try FileManager.default.createDirectory(atPath: snapshot_url.path, withIntermediateDirectories: true, attributes: nil)
        
        // pre-fetch keys for copy
        let fetch_keys = [
            URLResourceKey.isRegularFileKey]
        
        // load contents
        let urls = try! FileManager.default.contentsOfDirectory(at: copy_url, includingPropertiesForKeys: fetch_keys)
        for url in urls {
            do
            {
                let resources = try url.resourceValues(forKeys: [.isRegularFileKey])
                if resources.isRegularFile ?? true {
                    
                    // snapshot file
                    icloud_snapshot_file(copy_url: url, snapshot_url: snapshot_url)
                    
                } else {
                
                    // copy dir
                    let dir_url = snapshot_url.appendingPathComponent(url.lastPathComponent)
                    icloud_snapshot_url(copy_url: url, snapshot_url: dir_url)
                }
             
            } catch {
                error_print(message: "file or directory does not exist: \(url_to_path(url: copy_url)) error: \(error)")
            }
        }
    } catch {
        error_print(message: "could not snapshot directory: \(url_to_path(url: copy_url)) error: \(error)")
    }
}


struct iCloudSnapshot: ParsableCommand {
  
    // configuration
    static var configuration = CommandConfiguration(
        abstract: "icloud-snapshot is a utility to copy an icloud directory to a snapshot directory for archival purposes."
    )
    
    // arguments
    @Argument(help: "icloud directory") var icloud_dir: String
    @Argument(help: "snapshot directory") var snapshot_dir: String
  
    // flags
    @Flag(help: "Timecode snapshot") var timecode_snapshot = false
    @Flag(help: "Overwrite files") var overwrite_files = false
    @Flag(help: "Evict files") var evict_files = false
    @Flag(help: "Skip snapshot files") var skip_snapshot_files = false
    @Flag(help: "Debug information") var debug = false
    
    mutating func run() {
        
        // icloud dir
        let icloud_url = URL(fileURLWithPath: icloud_dir)
        
        // snapshot dir
        var snapshot_url = URL(fileURLWithPath: snapshot_dir)
        
        if (timecode_snapshot) {
            let date_formatter = DateFormatter()
            date_formatter.dateFormat = "dd-MMM-yy_HH_mm_ss"
            snapshot_url = snapshot_url.appendingPathComponent(date_formatter.string(from: Date.now))
        }
        
        // icloud flags
        icloud_overwrite = overwrite_files
        
        // debug flags
        debug_output = debug
        
        // create snapshot
        info_print(message: ("snapshot icloud directory: \(url_to_path(url: icloud_url)) to \(url_to_path(url: snapshot_url))"))
        let start = CFAbsoluteTimeGetCurrent()

        // evict
        if (evict_files) {
            // evict files
            icloud_evict_url(evict_url: icloud_url)
        }
        
        if (!skip_snapshot_files) {
            // snapshot files
            icloud_snapshot_url(copy_url: icloud_url, snapshot_url: snapshot_url)
        }

        // end
        let seconds = CFAbsoluteTimeGetCurrent() - start
        info_print(message: ("snapshot completed in: \(format_time_stamp(seconds: Int64(seconds)))"))
  }
}

iCloudSnapshot.main()
