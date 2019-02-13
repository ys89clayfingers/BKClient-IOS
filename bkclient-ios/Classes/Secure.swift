//
//  Secure.swift
//  swift project
//
//  Created by CLAYFINGERS on 13/10/2017.
//  Copyright © 2017 CLAYFINGERS. All rights reserved.
//

import Foundation
import Security

protocol HandshakeCallback {
    func handshaked();
    func error();
}

protocol Secure : Writer {
    func setIO(io:IO);
    func startHandshake(_ callback:HandshakeCallback);
    func dataPerform() -> Bool;
    func destroy();
    func setCurrentSequence(sequence:Int32);
}

func copyToUnsafe( _ src:[UInt8], _ pointer:UnsafeMutableRawPointer)
{
    for i in 0 ..< src.count {
        pointer.advanced(by: i).storeBytes(of: src[i], as: UInt8.self);
    }
}

func toByteArray(src:UnsafeRawPointer, length:Int) -> [UInt8]
{
    var ret = Array<UInt8>(repeating: 0, count: length);
    let arrayPointer = src.bindMemory(to: UInt8.self, capacity: length);
    
    for i in 0 ..< length {
        ret[i] = arrayPointer[i];
    }
    return ret;
}

func bridge(obj : IO) -> UnsafeRawPointer {
    return UnsafeRawPointer(Unmanaged.passUnretained(obj as AnyObject).toOpaque())
}

func bridge(ptr : UnsafeRawPointer) -> IO {
    return Unmanaged<AnyObject>.fromOpaque(ptr).takeUnretainedValue() as! IO;
}

func sslReadCallback(connection:SSLConnectionRef,data:UnsafeMutableRawPointer,dataLength:UnsafeMutablePointer<Int>) -> OSStatus
{
    let io = bridge(ptr:connection);
    let buffer = io.read(count: dataLength.pointee);
    if buffer.count == 0 {
        dataLength.initialize(to: 0)
        return OSStatus(errSSLClosedGraceful);
    }
    let readLength = buffer.count;
    copyToUnsafe(buffer, data);
    dataLength.initialize(to: readLength);
    return noErr;
}

func sslWriteCallback(connection:SSLConnectionRef,data:UnsafeRawPointer,dataLength:UnsafeMutablePointer<Int>) -> OSStatus
{
    let io = bridge(ptr:connection);
    let arrayData:[UInt8] = toByteArray(src: data, length: dataLength.pointee);
    io.write(arrayData);
    dataLength.initialize(to: arrayData.count);
    return noErr;
}

class SSLSecure : Secure {
    private var io:IO?;
    private var callback:HandshakeCallback?;
    private var ioPtr:UnsafeRawPointer?;
    private var currentSequence:Int32 = 0;
    private var sslContext:SSLContext?;
    private var keyPath:String;
    private var keyPhase:String;
    private var keyType:String;
    private var receiver:Receiver!;
    
    init(keystore:String, type:String, phase:String, receiver:Receiver) {
        self.keyPath = keystore;
        self.keyType = type;
        self.keyPhase = phase;
        self.receiver = receiver;
    }
    
    public func setIO(io:IO)
    {
        self.io = io;
    }
    
    public func startHandshake(_ callback : HandshakeCallback)
    {
        self.callback = callback;
        sslContext = SSLCreateContext(kCFAllocatorDefault, SSLProtocolSide.clientSide, SSLConnectionType.streamType)!;
        SSLSetIOFuncs(sslContext!,
                      sslReadCallback,
                      sslWriteCallback);
        ioPtr = bridge(obj: io!);
        SSLSetConnection(sslContext!, ioPtr);
        SSLSetSessionOption(sslContext!, SSLSessionOption.breakOnClientAuth, true);
        let certs = getSecCertificate(sslContext!);
        SSLSetCertificate(sslContext!, certs as CFArray);
        let status:OSStatus = SSLHandshake(sslContext!);
        
        bkLogging("secure handshake result:" + String(status));
        if status != 0 {
            callback.error();
            return;
        }
        callback.handshaked();
    }
    
    func getSecCertificate(_ context:SSLContext) -> CFArray {
        let path:String = Bundle.main.path(forResource:self.keyPath, ofType: self.keyType)!;
        let pkcs12Data = NSData(contentsOfFile:path);
        let options : NSDictionary = [kSecImportExportPassphrase as NSString : self.keyPhase];
        var rawItems : CFArray?;
        let _ = SecPKCS12Import(pkcs12Data!, options, &rawItems);
        let newArray = rawItems! as [AnyObject] as NSArray;
        let dictionary = newArray.object(at: 0);
        var secIdentityRef = (dictionary as AnyObject).value(forKey: kSecImportItemKeyID as String);
        secIdentityRef = (dictionary as AnyObject).value(forKey: "identity");
        let secIdentity = secIdentityRef;
        var certs = [secIdentity];
        var ccerts: Array<SecCertificate> = (dictionary as AnyObject).value(forKey: kSecImportItemCertChain as String) as! Array<SecCertificate>
        for i in 1 ..< ccerts.count {
            certs += [ccerts[i] as AnyObject]
        }
        return certs as CFArray;
    }
    
    func dataPerform() -> Bool {
        if sslContext == nil {
            return false;
        }
        bkLogging("data perform");
        let data = UnsafeMutablePointer<UInt8>.allocate(capacity: 1024 * 10);
        let rawData = UnsafeMutableRawPointer(data);
        var processed:Int = 0;
        
        SSLRead(sslContext!, rawData, 1024 * 10, &processed);
        if processed < 0 || processed > 1024 * 10 {
            bkLogging("err processed:" + String(processed));
            return false;
        }
        
        let array:[UInt8] = Array(UnsafeBufferPointer(start:data, count:processed));
        bkLogging("data perform end " + String(processed) + ", " + String(io!.avaliable()));
        if processed < 1 {
            return false;
        }
        receiver.receive(connection:io!, data: array, sequence: Int(currentSequence));
        rawData.deallocate(bytes: 1024 * 10, alignedTo: 1)
        return true;
    }
    
    func write(_ data: [UInt8]) {
        var processed:Int = 0;
        bkLogging("write!");
        SSLWrite(sslContext!, UnsafeRawPointer(data), data.count, &processed);
    }
    
    func destroy() {
        bkLogging("destroy secure");
        //        SSLClose(sslContext!);
        sslContext = nil;
    }
    
    func setCurrentSequence(sequence: Int32) {
        currentSequence = sequence;
    }
    
    func convertToSwift<T>(length: Int, data: UnsafePointer<UInt8>, _: T.Type) -> [T] {
        let numItems = length/MemoryLayout<T>.stride
        let buffer = data.withMemoryRebound(to: T.self, capacity: numItems) {
            UnsafeBufferPointer(start: $0, count: numItems)
        }
        return Array(buffer)
    }
}

