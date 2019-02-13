//
//  Resource.swift
//  Shape_It
//
//  Created by CLAYFINGERS on 20/12/2017.
//  Copyright © 2017 ClayFingers. All rights reserved.
//
/*
import Foundation

protocol ResourcePacketState {
    func getNextPacket() -> [UInt8]?;
    func receive(data: [String : Any]);
    func hasNext() -> Bool;
    func isTimeOuted() -> Bool;
}

protocol ResourceStatable {
    func prepared(resourceId: String);
    func dataDone();
    func end();
    func err(log: String);
}

public class ResourcePrepareState: ResourcePacketState {
    private var uploadType: UInt8;
    private var statable: ResourceStatable;
    private var next: Bool = true;
    private var dataStream: Bool;
    private var dataSize: Int;
    private var folder: String?;
    
    init(uploadType: UInt8, usingDataStrea: Bool, statable: ResourceStatable, size: Int, folder: String?) {
        self.statable = statable;
        self.dataStream = usingDataStrea;
        self.uploadType = uploadType;
        self.dataSize = size;
        self.folder = folder;
    }
    
    func getNextPacket() -> [UInt8]? {
        var jsonDic = [String : Any]() ;
        jsonDic[ResourcePacketConstants.UPLOAD_TYPE] = uploadType;
        jsonDic[ResourcePacketConstants.WORK] = ResourcePacketConstants.WORKING_MAKE_STREAM;
        jsonDic[ResourcePacketConstants.USING_DATA_STREAM] = dataStream;
        jsonDic[ResourcePacketConstants.DATA_STREAM_SIZE] = dataSize;
        
        if folder != nil {
            jsonDic[ResourcePacketConstants.REOUSRCE_FOLDER] = folder;
        }
        
        do {
            let jsonString = try JSONSerialization.data(withJSONObject: jsonDic, options: .prettyPrinted);
            let json = JSON(jsonString);
            next = false;
            let jsonBytes = [UInt8](String(data:jsonString, encoding:String.Encoding.utf8)!.utf8);
            return ResourcePacketConstants.wrapResourcePacket(src: jsonBytes, offset: 0, size: jsonBytes.count, isControlPacket: true);
        } catch {
            Util.logging("ResourcePrepareState: json parsing err");
        }
        return nil;
    }
    
    func hasNext() -> Bool {
        return next;
    }
    
    func isTimeOuted() -> Bool {
        sleep(300);
        return false;
    }
    
    func receive(data: [String : Any]) {
        let result = data[ResourcePacketConstants.RESULT] as! Bool;
        if result {
            let resourceId = data[ResourcePacketConstants.RESOURCE_ID] as! String;
            statable.prepared(resourceId: resourceId);
        } else {
            statable.err(log: data[ResourcePacketConstants.RESULT_DETAIL] as! String);
        }
    }
}

public class ResourceDataState: ResourcePacketState {
    var input: InputStream;
    var statable: ResourceStatable;
    var isDone: Bool = false;
    var remainedSize: Int;
    
    init(statable: ResourceStatable, path: String, size: Int) {
        self.statable = statable;
        self.remainedSize = size;
        
        input = InputStream.init(fileAtPath: path)!;
        input.open();
    }
    
    func getNextPacket() -> [UInt8]? {
        if !hasNext() {
            return nil;
        }
        
        var temp = [UInt8](repeating: 0, count: 1024);
        var readSize: Int = 0;
        readSize = input.read(&temp, maxLength: 1024);
        if readSize < 0 {
            return nil;
        }
        remainedSize = remainedSize - readSize;
        
        if !hasNext() {
            isDone = true;
        }
        
        return ResourcePacketConstants.wrapResourcePacket(src: temp, offset: 0, size: readSize, isControlPacket: false);
    }
    
    func hasNext() -> Bool {
        return remainedSize > 0;
    }
    
    func isTimeOuted() -> Bool {
        return false;
    }
    
    func receive(data: [String : Any]) {
        let result = data[ResourcePacketConstants.RESULT] as! Bool;
        if result && isDone {
            statable.dataDone();
        } else if !result {
            statable.err(log: data[ResourcePacketConstants.RESULT_DETAIL] as! String);
        }
    }
}

public class ResourceEndState: ResourcePacketState {
    private let statable: ResourceStatable;
    private var next = true;
    
    init(statable: ResourceStatable) {
        self.statable = statable;
    }
    
    func getNextPacket() -> [UInt8]? {
        var jsonDic = [String : Any]() ;
        jsonDic[ResourcePacketConstants.WORK] = ResourcePacketConstants.WORKING_END_STREAM;
        
        do {
            let jsonString = try JSONSerialization.data(withJSONObject: jsonDic, options: .prettyPrinted);
            let json = JSON(jsonString);
            next = false;
            let jsonBytes = [UInt8](String(data:jsonString, encoding:String.Encoding.utf8)!.utf8);
            return ResourcePacketConstants.wrapResourcePacket(src: jsonBytes, offset: 0, size: jsonBytes.count, isControlPacket: true);
        } catch {
            Util.logging("ResourceEndState: json parsing err");
        }
        return nil;
    }
    
    func hasNext() -> Bool {
        return next;
    }
    
    func isTimeOuted() -> Bool {
        sleep(300);
        return false;
    }
    
    func receive(data: [String : Any]) {
        statable.end();
    }
}

public class ResourceTransport: ResourceStatable {
    private var state: ResourcePacketState?;
    private var type: UInt8;
    private var dataState: ResourcePacketState?;
    private var resourceId: String?;
    private var ended = false;
    private var remaining = 1;
    private var sendCount = 0;
    
    init(type: UInt8, path: String, folder: String) {
        self.type = type;
        
        do {
            let attr = try FileManager.default.attributesOfItem(atPath: path);
            //            let size = Int(attr[FileAttributeKey.size] as! UInt64);
            let size = Int(attr[FileAttributeKey.size] as! UInt64);
            Util.logging(attr[FileAttributeKey.size] as! UInt64);
            self.dataState = ResourceDataState(statable: self, path: path, size: size);
            self.state = ResourcePrepareState(uploadType: type, usingDataStrea: true, statable: self, size: size, folder: folder);
        } catch let error as NSError {
            Util.logging("ResourceUploadHandle: file error \(error)");
        }
        
    }
    
    func prepared(resourceId: String) {
        state = dataState;
        self.resourceId = resourceId;
        self.remaining = 60;
    }
    
    func dataDone() {
        state = ResourceEndState(statable: self);
        remaining = 1;
    }
    
    func end() {
        self.ended = true;
    }
    
    func getPacketBytes() -> [UInt8]? {
        return state!.getNextPacket();
    }
    
    private func hasNext() -> Bool {
        return state!.hasNext();
    }
    
    func err(log: String) {
    }
    
    let recieveQueue = DispatchQueue(label: "res_recv_transport");
    let sendQueue = DispatchQueue(label: "res_send_transport");
    
    func receive(jsonDic: [String : Any]) {
        recieveQueue.sync {
            sendCount = sendCount - 1;
            
            if sendCount == 0 && !hasNext() {
                state?.receive(data: jsonDic);
            }
            remaining = remaining + 1;
        }
    }
    
    func getResourceId() -> String {
        return resourceId!;
    }
    
    func sendPacket(peer: PeerConnection, seq: Int) -> Bool {
        var result = true;
        sendQueue.sync {
            if hasNext() {
                while hasNext() && remaining > 0 {
                    sendCount = sendCount + 1;
                    let packetBytes = getPacketBytes();
                    if packetBytes == nil {
                        result = false;
                    }
                    peer.sendToPeer(packetBytes!);
                    remaining = remaining - 1;
                }
            } else if ended {
                result = false;
            }
        }
        return result;
    }
}

protocol ResourceUploadCallback {
    func result(success: Bool, callback: Int, resourceId: String);
}

class ResourceUploadLink: NetLink {
    private var transport: ResourceTransport!;
    private var seq: Int = 0;
    private var resourceCallback: ResourceUploadCallback?;
    private var callbackKey: Int = 0;
    
    init(filePath: String, uploadType: UInt8, callbackKey: Int, folder: String, uploadCallback: ResourceUploadCallback?) {
        transport = ResourceTransport(type: uploadType, path: filePath, folder: folder);
        self.resourceCallback = uploadCallback;
        self.callbackKey = callbackKey;
    }
    
    override func chainning(connection: PeerConnection, _ sequence: Int) {
        self.seq = sequence;
        sendPacket(connection: connection);
    }
    
    private func sendPacket(connection: PeerConnection) {
        if !transport.sendPacket(peer: connection, seq: seq) {
            result(res: true);
        }
    }
    
    override func receive(connection: PeerConnection, data: [UInt8], sequence: Int) {
        let string = String(bytes:data, encoding:.utf8)!;
        let data = string.data(using: .utf8)!;
        do {
            let decoded = try JSONSerialization.jsonObject(with: data, options: []);
            let dic = decoded as! [String:Any];
            let resultBool:Bool = dic["result"] as! Bool;
            transport.receive(jsonDic: dic);
            
            if resultBool {
                sendPacket(connection: connection);
            } else {
                result(res: false);
            }
        } catch {
            Util.logging("ResourceUploadLink: json parsing err");
            Util.logging(string)
            result(res: false);
        }
    }
    
    func getResourceId() -> String {
        return transport.getResourceId();
    }
    
    override func result(res: Bool) {
        resourceCallback?.result(success: res, callback: callbackKey, resourceId: getResourceId());
        super.result(res: res);
    }
}

class TransactionIdLink: NetLink {
    var transactionId: Int64 = 0;
    
    override func chainning(connection: PeerConnection, _ sequence: Int) {
        var jsonDic = [String : Any]();
        jsonDic[ResourcePacketConstants.WORK] = ResourcePacketConstants.WORKING_TRANSACTION;
        
        do {
            let jsonString = try JSONSerialization.data(withJSONObject: jsonDic, options: .prettyPrinted);
            let jsonBytes = [UInt8](String(data:jsonString, encoding:String.Encoding.utf8)!.utf8);
            connection.sendToPeer(ResourcePacketConstants.wrapResourcePacket(src: jsonBytes, offset: 0, size: jsonBytes.count, isControlPacket: true));
        } catch {
            Util.logging("ResourcePrepareState: json parsing err");
        }
    }
    
    override func receive(connection: PeerConnection, data: [UInt8], sequence: Int) {
        let string = String(bytes:data, encoding:.utf8)!;
        let data = string.data(using: .utf8)!;
        do {
            let decoded = try JSONSerialization.jsonObject(with: data, options: []);
            let dic = decoded as! [String:Any];
            let resultBool:Bool = dic["result"] as! Bool;
            
            if resultBool {
                transactionId = dic[ResourcePacketConstants.TRANSACTION_ID] as! Int64;
            }
            result(res: resultBool);
        } catch {
            Util.logging("TransactionIdLink: json parsing err");
            Util.logging(string)
            result(res: false);
        }
    }
    
    func getTransactionId() -> Int64 {
        return transactionId;
    }
}

func resourceUpload(path: String) {
    let chainner = Chainer()
    class Callback: ResourceUploadCallback {
        func result(success: Bool, callback: Int, resourceId: String) {
            
        }
    }
    
    let callback = Callback();
    let resourceLink = ResourceUploadLink(filePath: path, uploadType: ResourcePacketConstants.UPLOAD_TYPE_IMAGE_PNG, callbackKey: 0, folder: "test", uploadCallback: callback);
    
    let network:Network = NIONetwork(handle: nil, url: RESOURCE_SERVER_IP, port: RESOURCE_SERVER_PORT);
    chainner.addChain(link: resourceLink);
    chainner.startNet(network: network)
}
*/
