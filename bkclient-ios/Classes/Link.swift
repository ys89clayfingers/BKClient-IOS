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
    
    public init(adapter: JSONAdapter) {
        self.adapter = adapter;
    }
    
    public override func getJSONDic() -> [String : Any] {
        return adapter.getJSONDic();
    }
    
    public override func getWorking() -> String {
        return adapter.getWorking();
    }
    
    public override func receiveJSON(jsonDic: [String : Any], result: Bool) {
        adapter.receiveJSON(jsonDic: jsonDic);
    }
}

open class WorkLink : NetLink {
    public override init() {
        super.init();
    }
    
    final override public func receive(connection: PeerConnection, data: [UInt8], sequence: Int) {
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
    
    final override public func chainning(connection: PeerConnection, _ sequence: Int) {
        var dic = getJSONDic();
        dic[BK_WORKING] = getWorking();
        
        do {
            let jsonString = try JSONSerialization.data(withJSONObject: dic, options: .prettyPrinted);
            connection.sendToPeer([UInt8](String(data:jsonString, encoding:String.Encoding.utf8)!.utf8))
        } catch {
            bkLogging("WorkLinkErr:chainning json err");
            bkLogging(dic);
        }
    }
    
    open func receiveJSON(jsonDic:[String:Any], result:Bool) {
    }
    
    open func getWorking() -> String {
        return "";
    }
    
    open func getJSONDic() -> [String:Any] {
        return ["err":0];
    }
}

open class NetLink : NetHandle {
    var callback: OnResultCallback?;
    var linkCallback: OnLinkCallback?;
    var linkCallbackName: String?;
    var isHandling:Bool = false;
    
    public init() {
        
    }
    
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
    
    open func receive(connection:PeerConnection, data:[UInt8], sequence:Int)
    {
        
    }
    
    public func chainning(connection:PeerConnection, _ sequence:Int)
    {
        
    }
    
    open func test(ttt: PeerConnection) {
    }
    
    public func broken()
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



