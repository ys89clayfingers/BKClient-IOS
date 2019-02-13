//
//  PacketWrapper.swift
//  swift project
//
//  Created by CLAYFINGERS on 11/10/2017.
//  Copyright © 2017 CLAYFINGERS. All rights reserved.
//

import Foundation

func subArray<T>(_ src:[T], _ offset:Int, _ size:Int) -> [T]
{
    let sub = Array(src[offset ..< offset + size])
    return sub;
}

protocol PacketWrapper {
    func hasNext() -> Bool;
    func next() -> [UInt8]?;
}

public class PacketWrapperFactory {
    func createPacketWrapper(src:[UInt8]) -> PacketWrapper?
    {
        return nil;
    }
}

public class ByteArrayPacketWrapper : PacketWrapper {
    var src:[UInt8];
    var currentPosition = 0;
    static var sequence:UInt32 = 0;
    
    init(src:[UInt8])
    {
        self.src = src;
    }
    
    public func hasNext() -> Bool
    {
        return src.count > currentPosition;
    }
    
    /**
     * 패킷에 들어갈 내용:플래그, 시퀀스, 페이로드 사이즈, 페이로드
     */
    public func next() -> [UInt8]?
    {
        var buffer = [UInt8] (repeating:0, count: Constants.PACKET_DEFAULT_TOTAL_SIZE);
        
        var flag:UInt16 = 0;
        
        //페이로드 크기 결정
        var length = Constants.PAYLOAD_MAX;
        if src.count <= currentPosition + Constants.PAYLOAD_MAX {
            flag += Constants.PACKET_OPTION_FINAL;
            length = src.count - currentPosition;
        }
        
        putShort(dest:&buffer, data:flag, offset:Constants.FLAG_OFFSET);
        putInt(dest:&buffer, data:ByteArrayPacketWrapper.sequence, offset:Constants.SEQUENCE_OFFSET);
        ByteArrayPacketWrapper.sequence += 1;
        putShort(dest:&buffer, data:UInt16(length), offset:Constants.PAYLOAD_SIZE_OFFSET);
        coppyArray(src:src, srcOffset:currentPosition, dest:&buffer, destOffset:Constants.PAYLOAD_OFFSET, size:length);
        currentPosition += length;
        
        return buffer;
    }
    
    public func putShort(dest:inout [UInt8], data:UInt16, offset:Int)
    {
        let dataArray = shortToByteArrayBigEndian(data:data);
        coppyArray(src:dataArray, srcOffset:0, dest:&dest, destOffset:offset, size:2);
    }
    
    public func putInt(dest:inout [UInt8], data:UInt32, offset:Int)
    {
        let dataArray = intToByteArrayBigEndian(data:data);
        coppyArray(src:dataArray, srcOffset:0, dest:&dest, destOffset:offset, size:4);
    }
    
    private func coppyArray(src:[UInt8], srcOffset:Int, dest: inout [UInt8], destOffset:Int, size:Int)
    {
        for i in 0 ..< size {
            dest[destOffset + i] =  src[srcOffset + i];
        }
    }
    
    private func intToByteArrayBigEndian(data: UInt32) -> [UInt8]
    {
        var result:[UInt8] = Array();
        
        var shiftingNumber = data;
        let mask8Bits = UInt32(0xFF);
        
        for _ in (0 ..< 4).reversed() {
            result.insert(UInt8(shiftingNumber & mask8Bits), at:0);
            shiftingNumber >>= 8;
        }
        return result;
    }
    
    private func shortToByteArrayBigEndian(data: UInt16) -> [UInt8]
    {
        var result:[UInt8] = Array();
        
        var shiftingNumber = data;
        let mask8Bits = UInt16(0xFF);
        
        for _ in (0 ..< 2).reversed() {
            result.insert(UInt8(shiftingNumber & mask8Bits), at:0);
            shiftingNumber >>= 8;
        }
        return result;
    }
}

public class OutputStreamDeco : OutputStream {
    var wrapperFactory:PacketWrapperFactory?;
    var outputOrigin:OutputStream?;
    
    public func setOrigin(output:OutputStream, wrapper:PacketWrapperFactory)
    {
        self.outputOrigin = output;
        self.wrapperFactory = wrapper;
    }
    
    override open func write(_ buffer:UnsafePointer<UInt8>, maxLength: Int) -> Int
    {
        let wrapper = wrapperFactory!.createPacketWrapper(src:convert(length:maxLength, data:buffer, UInt8.self));
        var sendCount = 0;
        
        while wrapper!.hasNext() {
            let buffer = wrapper!.next()!;
            sendCount += outputOrigin!.write(buffer, maxLength:maxLength);
        }
        return sendCount;
    }
    
    override open var hasSpaceAvailable:Bool {
        get {
            return outputOrigin!.hasSpaceAvailable;
        }
    };
    
    func convert<T>(length: Int, data: UnsafePointer<UInt8>, _: T.Type) -> [T] {
        let numItems = length/MemoryLayout<T>.stride
        let buffer = data.withMemoryRebound(to: T.self, capacity: numItems) {
            UnsafeBufferPointer(start: $0, count: numItems)
        }
        return Array(buffer)
    }
}

