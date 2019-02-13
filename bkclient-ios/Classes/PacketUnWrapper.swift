//
//  PacketParser.swift
//  swift project
//
//  Created by CLAYFINGERS on 11/10/2017.
//  Copyright © 2017 CLAYFINGERS. All rights reserved.
//

import Foundation

struct Constants {
    static let PACKET_DEFAULT_TOTAL_SIZE = 1024;
    static let FLAG_OFFSET = 0;
    static let SEQUENCE_OFFSET = 2;
    static let PAYLOAD_SIZE_OFFSET = 6;
    static let PAYLOAD_OFFSET = 8;
    static let PAYLOAD_MAX = PACKET_DEFAULT_TOTAL_SIZE - PAYLOAD_OFFSET;
    static let PACKET_OPTION_FINAL = UInt16(0b0000000000000001);
    static let PACKET_OPTION_FRAMEWORK_PAKET = UInt16(0b0000000000000010);
}

public class ByteArrayPacket : Packet {
    private var data:[UInt8]?;
    private var size:UInt16?;
    private var finalFlag:Bool?;
    private var frameworkFlag:Bool?;
    
    init(buffer:[UInt8])
    {
        let flag:UInt16 = byteArrayBigEndianToShort(data:buffer, offset:Constants.FLAG_OFFSET);
        finalFlag = flag & Constants.PACKET_OPTION_FINAL == Constants.PACKET_OPTION_FINAL;
        size = byteArrayBigEndianToShort(data:buffer, offset:Constants.PAYLOAD_SIZE_OFFSET);
        
        data = [UInt8] (repeating:0, count:Int(size!));
        coppyArray(src:buffer, srcOffset:Int(Constants.PAYLOAD_OFFSET), dest:&data!, destOffset:Int(0), size:Int(size!));
    }
    
    public func getData() -> [UInt8]
    {
        return data!;
    }
    
    public func getSize() -> UInt16
    {
        return size!;
    }
    
    public func isFinal() -> Bool
    {
        return finalFlag!;
    }
    
    public func isFrameworkPacket() -> Bool
    {
        return frameworkFlag!;
    }
    
    public func getSequence() -> Int32
    {
        return 0;
    }
    
    func byteArrayBigEndianToShort(data:[UInt8], offset:Int) -> UInt16
    {
        var ret:UInt16 = 0;
        var j:Int = 0;
        for i in (offset ..< offset + 2).reversed() {
            ret |= UInt16(data[i]) << UInt16(j * 8);
            j += 1;
        }
        
        return ret;
    }
    
    private func coppyArray(src:[UInt8], srcOffset:Int, dest: inout [UInt8], destOffset:Int, size:Int)
    {
        for i in 0 ..< size {
            dest[destOffset + i] =  src[srcOffset + i];
        }
    }
    
    public func appendPacket(next: Packet) {
    }
}

