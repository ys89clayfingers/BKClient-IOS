//
//  ViewController.swift
//  bkclient-ios
//
//  Created by bunker.ys89@gmail.com on 02/12/2019.
//  Copyright (c) 2019 bunker.ys89@gmail.com. All rights reserved.
//

import UIKit
import bkclient_ios
import SwiftyJSON

class TestAdapter: WorkLink {
    override func getJSONDic() -> [String : Any] {
        var json = [String: Any]();
        json["district_id"] = 2;
        return json;
    }
    
    override func getWorking() -> String {
        return "town-list";
    }
    
    override func receiveJSON(jsonDic: [String : Any], result: Bool) {
        print(jsonDic)
    }
}

class ViewController: UIViewController {
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        test();
    }
    
    private func test() {
        let chainer = Chainer();
        chainer.addChain(link: TestAdapter());
        let network = HTTPNetwork("https://emo.thesoomco.com:7135/web-gateway");
        chainer.startNet(network: network)
    }
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
}
