//
//  Link.swift
//  shapeit
//
//  Created by CLAYFINGERS on 28/10/2017.
//  Copyright © 2017 CLAYFINGERS. All rights reserved.
//

import Foundation
import SwiftyJSON

public protocol JSONAdapter {
    func getJSONDic() -> [String:Any];
    func receiveJSON(jsonDic:[String:Any]);
    func getWorking() -> String;
}

public class JSONAdapterLink : WorkLink {
    let adapter:JSONAdapter;
    
    init(adapter: JSONAdapter) {
        self.adapter = adapter;
    }
    
    override func getJSONDic() -> [String : Any] {
        return adapter.getJSONDic();
    }
    
    override func getWorking() -> String {
        return adapter.getWorking();
    }
    
    override func receiveJSON(jsonDic: [String : Any], result: Bool) {
        adapter.receiveJSON(jsonDic: jsonDic);
    }
}

public class WorkLink : NetLink {
    final override func receive(connection: PeerConnection, data: [UInt8], sequence: Int) {
        let string = String(bytes:data, encoding:.utf8)!;
        let data = string.data(using: .utf8)!;
        do {
            let decoded = try JSONSerialization.jsonObject(with: data, options: []);
            let dic = decoded as! [String:Any];
            let resultBool:Bool = dic[BK_RESULT] as! Bool;
            receiveJSON(jsonDic: dic, result:resultBool);
            result(res: resultBool);
        } catch {
            bkLogging("WorkLinkErr: json parsing err");
            bkLogging(string)
            result(res: false);
        }
    }
    
    final override func chainning(connection: PeerConnection, _ sequence: Int) {
        var dic = getJSONDic();
        dic[BK_WORKING] = getWorking();
        
        do {
            let jsonString = try JSONSerialization.data(withJSONObject: dic, options: .prettyPrinted);
            let json = JSON(jsonString);
            connection.sendToPeer([UInt8](String(data:jsonString, encoding:String.Encoding.utf8)!.utf8))
        } catch {
            bkLogging("WorkLinkErr:chainning json err");
            bkLogging(dic);
        }
    }
    
    func receiveJSON(jsonDic:[String:Any], result:Bool) {
    }
    
    func getWorking() -> String {
        return "";
    }
    
    func getJSONDic() -> [String:Any] {
        return ["err":0];
    }
}

public class NetLink : NetHandle {
    var callback: OnResultCallback?;
    var linkCallback: OnLinkCallback?;
    var linkCallbackName: String?;
    var isHandling:Bool = false;
    
    func setOnResultCallback(callback:OnResultCallback) {
        self.callback = callback;
    }
    
    func setOnLinkCallback(callback: OnLinkCallback, callbackName: String) {
        self.linkCallback = callback;
        self.linkCallbackName = callbackName;
    }
    
    func result(res:Bool) {
        if (callback != nil && isHandling) {
            callback!.result(res:res);
        }
        
        if (linkCallback != nil) {
            linkCallback!.finished(result: res, name: linkCallbackName!, link: self);
        }
        
        isHandling = false;
    }
    
    func receive(connection:PeerConnection, data:[UInt8], sequence:Int)
    {
        
    }
    
    func chainning(connection:PeerConnection, _ sequence:Int)
    {
        
    }
    
    func broken()
    {
        if (callback != nil && isHandling) {
            callback!.result(res:false);
        }
        
        if (linkCallback != nil) {
            linkCallback!.finished(result: false, name: linkCallbackName!, link: self);
        }
        
        isHandling = false;
    }
    
    func setMainChain()
    {
        isHandling = true;
    }
}



