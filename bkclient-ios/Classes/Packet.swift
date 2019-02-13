//
//  Packet.swift
//  swift project
//
//  Created by CLAYFINGERS on 24/10/2017.
//  Copyright © 2017 CLAYFINGERS. All rights reserved.
//

import Foundation

public protocol Packet {
    func getData() -> [UInt8];
    func getSize() -> UInt16;
    func isFinal() -> Bool;
    func isFrameworkPacket() -> Bool;
    func getSequence() -> Int32;
    func appendPacket(next:Packet);
}

