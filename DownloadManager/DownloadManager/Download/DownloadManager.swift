//
//  DownloadManager.swift
//  alo7-student
//
//  Copyright © 2017年 alo7. All rights reserved.
//

import UIKit
import Alamofire

public class DownloadManager: NSObject {
    public typealias ProgressHandler = (Progress) -> Void
    
    public var maxCacheSize = 100 //MB
    
    public static var `default` = DownloadManager()
    
    var downloadedURLs = [URL]()
    public func syncDownloadResources(urls:[String],cacheDirectoryName:String? = nil,progress:ProgressHandler? = nil, completionHandler: @escaping (DownloadResult<[URL]>) -> (Void)){
        let dispatchGroup = DispatchGroup()
        for url in urls{
            dispatchGroup.enter()
            self.downloadResource(resourcePath: url, completionHandler: { (result) -> (Void) in
                switch result{
                case .success(let resourceURL):
                    self.downloadedURLs.append(resourceURL)
                    
                case .failure(let error): completionHandler(DownloadResult.failure(error))
                case .failureUrl(let error, let path):
                    completionHandler(DownloadResult.failureUrl(error, path))
                }
                dispatchGroup.leave()
            })
        }
        dispatchGroup.notify(queue: .downloadQueue) { [weak self] in
            
            if self?.downloadedURLs.count != urls.count {
                return
            }
            completionHandler(DownloadResult.success(self!.downloadedURLs))
        }
    }
    
    
    public  func downloadResource(resourcePath: String?,cacheDirectoryName:String? = nil,progress:ProgressHandler? = nil, completionHandler: @escaping (DownloadResult<URL>) -> (Void)) {
        if let cacheDirectoryName = cacheDirectoryName{
            DownloadCache.cachesDirectory = cacheDirectoryName
        }
        guard let path = resourcePath, !path.isEmpty else {
            completionHandler(DownloadResult.failure(self.getUrlEmptyError()))
            return
        }
        
        if let localUrl = isFileExisted(url: path.url){
            print("播放本地文件")
            completionHandler(DownloadResult.success(localUrl))
            return
        }
        
        downloadFile(resourceUrl: path, destination: getCacheDestination(url: path.url),progress:progress, completionHandler: {(result) -> (Void) in
            
            switch result{
            case .success(let cacheUrl):
                print("下载完成")
                completionHandler(DownloadResult.success(cacheUrl.url))
            case .failureUrl(let err, let path):
                completionHandler(DownloadResult.failureUrl(err, path))
            default: break
            }
        })
        
    }
    
    
    public func reloadSingleFile(localPath: String, remotePath: String, cacheDirectoryName:String, progress:ProgressHandler? = nil ,completionHandler: @escaping (DownloadResult<URL>) -> (Void)) {
        //  先删除本地的
        DownloadCache.removeItem(atPath: localPath)
        // 再下载
        downloadResource(resourcePath: remotePath, cacheDirectoryName: cacheDirectoryName,progress: progress) { (result) -> (Void) in
            completionHandler(result)
        }
    }
    
    func downloadFile(resourceUrl: String, destination: DownloadRequest.DownloadFileDestination?,progress:ProgressHandler? = nil, completionHandler: @escaping (DownloadResult<String>) -> (Void)) {
        let requestTask = Alamofire.download(resourceUrl, to: destination).validate(statusCode: 200..<400).response { (response) in
            if response.error == nil, let localPath = response.destinationURL?.path {
                completionHandler(DownloadResult.success(localPath))
            } else {
                completionHandler(DownloadResult.failureUrl(response.error!, response.destinationURL?.path))
            }
        }
        guard  progress != nil  else {
            return
        }
        requestTask.downloadProgress(closure: progress!)
    }
    
    
    
    func isFileExisted(url: URL) -> URL? {
        if  DownloadCache.isFileExist(atPath: DownloadCache.cachePath(url: url)){
            return DownloadCache.cachePath(url: url).url
        }
        return nil
    }
    
    func isFileExisted(url: URL, prePath: String) -> URL? {
        if  DownloadCache.isFileExist(atPath: prePath + "/" + DownloadCache.cachePath(url: url)){
            return DownloadCache.cachePath(url: url).url
        }
        return nil
    }
    
    func getUrlEmptyError() -> Error {
        let errorInfo = ["errMsg": "urlEmpty"]
        let error = NSError(domain: FileErrorDomain, code: FileError.fileIsExist.rawValue, userInfo: errorInfo)
        return error as Error
    }
    
    func getCacheDestination(url: URL) -> DownloadRequest.DownloadFileDestination {
        return { _, _ in
            let fileURL = DownloadCache.cachePath(url: url)
            
            return (fileURL.url, [.removePreviousFile, .createIntermediateDirectories])
        }
    }
    
    func getCacheUrl(url: URL) -> URL {
        return DownloadCache.cachePath(url: url).url
    }
    
    func judgeIfClearCache() {
        if Int(DownloadCache.downloadedFilesSize() / 1000 / 1024) > maxCacheSize {
            DownloadCache.cleanDownloadFiles()
        }
    }
}

