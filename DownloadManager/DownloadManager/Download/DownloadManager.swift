//
//  DownloadManager.swift
//
import UIKit
import Alamofire
public enum DownloadResourceStatus{
    case downloading
    case downloaded
    case cancle
    case unkonw
    case beginDownload
}
struct DownloadResource {
    var status : DownloadResourceStatus = .beginDownload
    var url:String
    var requestTask:DownloadRequest?
}
public class DownloadManager: NSObject {
    public typealias ProgressHandler = (String,Progress) -> Void
    
    public var maxCacheSize = 100 //MB
    
    public static var `default` = DownloadManager()
    private var downloadingURLS = [String:DownloadRequest]()
    private var downloadCancleURLS = [String:DownloadRequest]()
    var downloadedURLs = [String:URL]()
    public static func resourceDownloadStatus(url:String)->DownloadResourceStatus{
        if self.default.downloadedURLs[url] != nil{
            return .downloaded
        }
        if self.default.downloadingURLS[url] != nil{
            return .downloading
        }
        if self.default.downloadCancleURLS[url] != nil{
            return .cancle
        }
        return .unkonw
    }
    public func syncDownloadResources(urls:[String?],cacheDirectoryName:String? = nil,progress:ProgressHandler? = nil, completionHandler: @escaping (DownloadResult<[String:URL]>) -> (Void)){
        self.downloadedURLs.removeAll()
        let dispatchGroup = DispatchGroup()
        for url in urls{
            dispatchGroup.enter()
            self.downloadResource(resourcePath: url, completionHandler: { (result) -> (Void) in
                switch result{
                case .success(let _):
                    break
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
    public static func cancelDownload(_ url:String){
        guard let request = self.default.downloadingURLS[url] else {
            return
        }
        request.cancel()
        self.default.downloadingURLS.removeValue(forKey: url)
        self.default.downloadCancleURLS[url] = request
    }
    public func resumeDownload(_ url:String?,progress:ProgressHandler? = nil, completionHandler: @escaping (DownloadResult<URL>) -> (Void)){
        guard let path = url, !path.isEmpty else {
            completionHandler(DownloadResult.failure(self.getUrlEmptyError()))
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
                self.downloadedURLs[path] = cacheUrl.url
                self.downloadCancleURLS.removeValue(forKey: path)
                self.downloadingURLS.removeValue(forKey: path)
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
  
        var downloadRequst : DownloadRequest? = nil
        if let downloadRequest = self.downloadCancleURLS[resourceUrl],
            let data = downloadRequest.resumeData {
            downloadRequst = Alamofire.download(resumingWith: data, to: destination)
            self.downloadCancleURLS.removeValue(forKey: resourceUrl)
        }else {
            
            downloadRequst = Alamofire.download(resourceUrl, to: destination).validate(statusCode: 200..<400).response { (response) in
                
                if response.error == nil, let localPath = response.destinationURL?.path {
                    completionHandler(DownloadResult.success(localPath))
                } else {
                    completionHandler(DownloadResult.failureUrl(response.error!, response.destinationURL?.path))
                }
            }
            
        }
        self.downloadingURLS[resourceUrl] = downloadRequst!
        guard  progress != nil  else {
            return
        }
        
        downloadRequst?.downloadProgress(queue: DispatchQueue.main, closure: { (_progress) in
            progress!(resourceUrl,_progress)
        })
    }
    func isFileExisted(url: URL, prePath: String? = nil) -> URL? {
        var path = self.getCacheUrl(url: url)
        
        if let prePath = prePath{
            path = prePath + path
        }
        
        if  DownloadCache.isFileExist(atPath: path){
            return self.getCacheUrl(url: url).url
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
            let fileURL = self.getCacheUrl(url: url).url
            
            return (fileURL, [.removePreviousFile, .createIntermediateDirectories])
        }
    }
    
    func getCacheUrl(url: URL) -> String {
        return DownloadCache.cachePath(url: url)
    }
    
    func judgeIfClearCache() {
        if Int(DownloadCache.downloadedFilesSize() / 1000 / 1024) > maxCacheSize {
            DownloadCache.cleanDownloadFiles()
        }
    }
}

