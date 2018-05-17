//
//  ViewController.swift
//  networkMetricsDemo
//
//  Created by shiva  kumar on 19/08/17.
//  Copyright © 2017 shiva  kumar. All rights reserved.
//

import UIKit
var measuredInterval: Double = 0
class metricsDelegate:NSObject, URLSessionTaskDelegate {
    
    func urlSession(_ session: URLSession, task: URLSessionTask, didFinishCollecting metrics: URLSessionTaskMetrics) {
        if let start = metrics.transactionMetrics[0].requestStartDate, let end = metrics.transactionMetrics[0].responseEndDate {
            
            let interval = end.timeIntervalSince(start)
            print(interval)
            measuredInterval = interval * 1000 //MilliSec
        }

    }
}

class ViewController: UIViewController {

    @IBOutlet weak var displayStatus: UILabel!
    
    @IBOutlet weak var apiStatusLabel: UILabel!
    @IBAction func makeAPICallTapped(_ sender: Any) {
        
        self.callAPI()
    }
    
    let threshold:Double = 300

    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view, typically from a nib.
 
        measuredInterval = 0.0
        NotificationCenter.default.addObserver(self, selector: #selector(notificationCallBack), name: Notification.Name(ReachabilityChangedNotification), object: nil)
    }
    
    func callAPI() {
        
        let delegate = metricsDelegate()
        let metricsDelegateQueue = OperationQueue()
        let session = URLSession(configuration: .default, delegate: delegate, delegateQueue: metricsDelegateQueue)
        let url = URL(string: "https://history.openweathermap.org/data/2.5/history/city?q=London,UK&APPID=037715175bab4505146a2a51fd4ba281")!;
        guard measuredInterval < threshold else {
            self.apiStatusLabel.text = "Poor Network Condition"
            let url = URL(string:"https://history.openweathermap.org")
            let task = session.dataTask(with: url!, completionHandler: { (data, response, error) in
                
            })
            task.resume()
            return
        }
        let task = session.dataTask(with: url) { (data, response, error) in
            if (error == nil) {
                print("Call Succeeded")
                DispatchQueue.main.async {
                    self.apiStatusLabel.text = "Call Succeeded"
                }
                
            }else {
                DispatchQueue.main.async {
                    self.apiStatusLabel.text = "Call Failed"
                }
            }
        }
        
        task.resume()
    }
    
    @objc func notificationCallBack() {
        print("Notification Recieved")
        displayStatus.text = "Notif Rcvd\(Date())"
    }
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
}

