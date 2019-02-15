//
//  Peer.swift
//  swift project
//
//  Created by CLAYFINGERS on 24/10/2017.
//  Copyright © 2017 CLAYFINGERS. All rights reserved.
//

import Foundation
import Socket

public protocol PeerConnection {
    func sendToPeer(_ data:[UInt8]);
    func closePeer();
    func getEnviroment() -> [String:Any];
}

public protocol Business : Receiver {
    func established(connection:PeerConnection);
    func removeBusinessData(connection:PeerConnection);
}

public protocol Writer {
    func write(_ data:[UInt8]);
}

public protocol Reader {
    func read() -> [UInt8];
    func read(count: Int) -> [UInt8];
}

public protocol IO : Writer, Reader, PeerConnection {
    func avaliable() -> Int;
}

public protocol Receiver {
    func receive(connection:PeerConnection, data:[UInt8], sequence:Int);
}

public protocol Peer : IO {
}

let secDispathQueue = DispatchQueue(label: "secSSL");

public class PeerNIOClient : Peer, HandshakeCallback {
    private var packets:[Packet] = [];
    private var lock = NSLock();
    private var business:Business;
    private var enviroment:[String:Any] = [:];
    private var sec:Secure?;
    private var client:Socket?;
    private var currentSequence:Int32 = 0;
    private var handShakeCallback:HandshakeCallback?;
    private var host:String;
    private var port:Int32;
    private var secureWrapped = false;
    private var bindedBuffer:[UInt8]?;
    
    init(host:String, port:Int32, business:Business, sec:Secure, callback:HandshakeCallback)
    {
        secureWrapped = true;
        self.business = business;
        self.sec = sec;
        self.host = host;
        self.port = port;
        self.handShakeCallback = callback;
        DispatchQueue.global().async {
            if !self.connect(host, port, business) {
                business.removeBusinessData(connection: self);
                return;
            }
            business.established(connection: self);
            sec.setIO(io: self);
            sec.startHandshake(self);
            self.runReadLoop();
        }
    }
    
    init(host:String, port:Int32, business:Business)
    {
        self.business = business;
        self.host = host;
        self.port = port;
        if !connect(host, port, business) {
            business.removeBusinessData(connection: self);
            return;
        }
        business.established(connection: self);
        runReadLoop();
    }
    
    private func createSocket() throws -> Socket {
        let socket = try Socket.create(family: .inet6);
        socket.readBufferSize = 16384
        return socket;
    }
    
    private func connect(_ host:String, _ port:Int32, _ business:Business) -> Bool
    {
        do {
            client = try createSocket()
            //        client = TCPClient(address: host, port: 9031);
            
            try client!.connect(to: host, port:port, timeout: 5000)
            bkLogging("PeerNIOClient connected");
            return true;
        } catch let error {
            bkLogging("bluesocket connect error\(error)");
            return false;
        }
        //    client = TCPClient(address: "www.naver.com", port: 80);
    }
    
    private func runReadLoop()
    {
        secDispathQueue.async {
            bkLogging("***** running read loop");
            while self.readFromPeer() {
                
            }
            bkLogging("***** end read loop");
        }
    }
    
    public func closePeer()
    {
        client?.close();
        if sec != nil {
            sec!.destroy();
        }
    }
    
    func error() {
        closePeer();
        business.removeBusinessData(connection: self)
    }
    
    public func getEnviroment() -> [String:Any]
    {
        return enviroment;
    }
    
    private func bindPacket() -> [UInt8] {
        var binded:[UInt8] = [];
        if packets.count <= 0 {
            return binded;
        }
        lock.lock();
        currentSequence = packets[0].getSequence();
        
        if sec != nil {
            sec?.setCurrentSequence(sequence: currentSequence);
        }
        for packet in packets {
            packets.remove(at:0);
            
            binded.append(contentsOf:packet.getData())
        }
        lock.unlock();
        return binded;
    }
    
    private func dispatch(_ data:[UInt8]) -> Packet {
        let packet = ByteArrayPacket(buffer:data);
        packets.append(packet);
        return packet;
    }
    
    public func send(_ data:[UInt8]) {
        let wrapper = ByteArrayPacketWrapper(src:data);
        while wrapper.hasNext() {
            let packetWrapped = wrapper.next()!;
            sendToSocket(packetWrapped);
        }
    }
    
    private func sendToSocket(_ packetWrapped: [UInt8]) {
        do {
            let data = Data(bytes: packetWrapped);
            
            let writeLength = try client!.write(from : data);
            bkLogging(writeLength);
            //            try client!.send(data: packetWrapped);
        } catch let error {
            bkLogging("sendToSocket err:\(error)");
        }
    }
    
    public func write(_ data:[UInt8])
    {
        send(data);
    }
    
    public func read() -> [UInt8] {
        var loopGaurd = 20;
        var accumulated: [UInt8] = [];
        while true {
            loopGaurd = loopGaurd - 1;
            if loopGaurd < 0 {
                return [];
            }
            //            let data = self.client.read(Constants.PACKET_DEFAULT_TOTAL_SIZE - accumulated.count, timeout: 10);
            
            let data = readToBytes(Constants.PACKET_DEFAULT_TOTAL_SIZE - accumulated.count)
            if data == nil {
                return [];
            }
            
            if data!.count <= 0 {
                return [];
            }
            
            accumulated = accumulated + data!;
            if accumulated.count < Constants.PACKET_DEFAULT_TOTAL_SIZE {
                continue;
            }
            
            let packet = self.dispatch(accumulated);
            if packet.isFinal() {
                return bindPacket()
            }
            accumulated = [];
        }
    }
    
    private func readToBytes(_ capacity: Int) -> [UInt8]? {
        var maxBuffer = [Int8](repeating: 0, count: capacity);
        if maxBuffer.count != capacity {
            bkLogging("readToBytes:***************** memmory alloc error ******************");
        }
        do {
            try client!.setReadTimeout(value: 5000)
            let readSize = try client!.read(into: &maxBuffer, bufSize: capacity, truncate: true);
            if readSize <= 0 {
                return nil;
            }
            let convertedBuffer = maxBuffer.map { UInt8(bitPattern: $0) };
            let subBuffer = Array(convertedBuffer[0..<readSize]);
            bkLogging("peer read:\(readSize)" + ", readed buffer:\(subBuffer.count)");
            return subBuffer;
        } catch let error {
            bkLogging("readToBytes err:\(error)");
        }
        return nil;
    }
    
    public func read(count: Int) -> [UInt8] {
        if bindedBuffer == nil {
            bindedBuffer = read();
        }
        
        if count >= bindedBuffer!.count {
            let ret = bindedBuffer;
            bindedBuffer = nil;
            return ret!;
        }
        
        let ret = bindedBuffer![0 ..< count];
        bindedBuffer!.removeSubrange(0 ..< count);
        return Array(ret);
    }
    
    public func sendToPeer(_ data:[UInt8]) {
        if sec != nil {
            sec!.write(data);
        } else {
            write(data);
        }
    }
    
    func readFromPeer() -> Bool
    {
        if sec != nil {
            return sec!.dataPerform();
        } else {
            let data = read();
            var result = true;
            if data.count <= 0 {
                result = false;
            } else {
                business.receive(connection:self, data: data, sequence: Int(currentSequence))
            }
            return result;
        }
    }
    
    func setHandShakeCallback(callback:HandshakeCallback) {
        self.handShakeCallback = callback;
    }
    
    func handshaked() {
        handShakeCallback?.handshaked();
    }
    
    public func avaliable() -> Int {
        if bindedBuffer == nil {
            return 0;
        }
        
        return bindedBuffer!.count;
    }
}

