//
//  ViewController.swift
//  DownloadManager
//
//  Created by hanqing.mao on 2018/7/31.
//  Copyright © 2018年 hanqing.mao. All rights reserved.
//

import UIKit
import Alamofire
struct Model {
    var title:String
    var URL:[String]
    
}
class ViewController: UITableViewController {
    var dataSource = [Model(title: "音乐", URL: ["http://sc1.111ttt.cn:8282/2017/1/11m/11/304112002347.m4a?#.mp3"]),Model(title: "视频", URL: ["https://www.apple.com/105/media/us/iphone-x/2017/01df5b43-28e4-4848-bf20-490c34a926a7/films/feature/iphone-x-feature-tpl-cc-us-20170912_1280x720h.mp4"]),Model(title: "asyncDownload", URL: ["http://sc1.111ttt.cn:8282/2017/1/11m/11/304112002347.m4a?#.mp3","https://www.apple.com/105/media/us/iphone-x/2017/01df5b43-28e4-4848-bf20-490c34a926a7/films/feature/iphone-x-feature-tpl-cc-us-20170912_1280x720h.mp4"])]
    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view, typically from a nib.
        
        self.tableView.register(UINib(nibName: "TableViewCell", bundle: Bundle.main), forCellReuseIdentifier: "cell")
        self.tableView.reloadData()
        self.tableView.tableFooterView = UIView()
    }
    
    @IBAction func cleanCache(_ sender: Any) {
        DownloadManager.cleanAllDownloadFiles()
    }
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    override func numberOfSections(in tableView: UITableView) -> Int {
         return 1
    }
    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return dataSource.count
    }
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "cell", for: indexPath) as! TableViewCell
        let model = dataSource[indexPath.row]
        cell.name.text = model.title
        return cell
    }
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        
        let model = self.dataSource[indexPath.row]
        let cell = tableView.cellForRow(at: indexPath) as! TableViewCell
        let statues = DownloadManager.resourceDownloadStatus(url: model.URL.first!)
        switch statues {
        case .downloading:
         DownloadManager.cancelDownload(model.URL.first!)
        case .cancel,.beginDownload,.unknow:
            DownloadManager.default.downloadResource(resourcePath: model.URL.first, progress: { (_,progress) in
                cell.progress.text = String(format: "%.2f",progress.fractionCompleted * 100)
            }) { (result) -> (Void) in
                switch result{
                case .success(let a):
                    print(a)
                case.failure(let error):
                    print(error)
                case.failureUrl(let error, let url):
                    print(error,url)
                }
            }
        case .downloaded:
            break
        case .unknow:
            break
        case .failure:
            break
        }
        
      
    }

}

