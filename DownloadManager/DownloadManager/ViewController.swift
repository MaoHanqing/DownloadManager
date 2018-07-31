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
    var title:String?
    var URL:String?
    var progress = 0.0
}
class ViewController: UITableViewController {
    var dataSource = [Model(title: "音乐", URL: "http://sc1.111ttt.cn:8282/2017/1/11m/11/304112002347.m4a?#.mp3", progress: 0),Model(title: "视频", URL: "", progress: 0),Model(title: "文件", URL: "", progress: 0)]
    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view, typically from a nib.
        
        self.tableView.register(UINib(nibName: "TableViewCell", bundle: Bundle.main), forCellReuseIdentifier: "cell")
        self.tableView.reloadData()
        self.tableView.tableFooterView = UIView()
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
        cell.progress.text = String(format: "%.2f", model.progress * 100)
        return cell
    }
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        let model = self.dataSource[indexPath.row]
        DownloadManager.default.downloadResource(resourcePath: model.URL!, downloadCacheType: .audio) { (result) -> (Void) in
            switch result{
            case .success(let a):
                print(a)
            case.failure(let error):
                print(error)
            case.failureUrl(let error, let url):
                print(error,url)
            }
        }
        
    }

}

