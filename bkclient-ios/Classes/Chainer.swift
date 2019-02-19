//
//  Chainer.swift
//  shapeit
//
//  Created by CLAYFINGERS on 28/10/2017.
//  Copyright © 2017 CLAYFINGERS. All rights reserved.
//

import Foundation

public class Chainer : OnResultCallback {
    var chains:[NetLink] = [];
    var network:Network?;
    var connectionOriented = false;
    var dummyHandling = false;
    private var dummy:DummyLink?;
    private var lock = NSLock();
    
    private class DummyLink : NetLink {
        var chainer:Chainer;
        init(_ chainer:Chainer) {
            self.chainer = chainer;
        }
        
        override func receive(connection:PeerConnection, data:[UInt8], sequence:Int) {
        }
        
        override func chainning(connection:PeerConnection, _ sequence:Int) {
            chainer.dummyHandling = true;
        }
    };
    
    public init() {
        dummy = DummyLink(self);
    }
    
    convenience public init(connectionOriented:Bool) {
        self.init();
        self.connectionOriented = connectionOriented;
    }
    
    public func startNet(network:Network) {
        self.network = network;
        if chains.count == 0 {
            chains.append(dummy!);
        }
        setChain();
        network.start();
    }
    
    public func addChain(link:NetLink) {
        chains.append(link);
        if dummyHandling {
            dummyHandling = false;
            setNextChain();
        }
    }
    
    public func result(res:Bool)
    {
        if res {
            setNextChain();
        } else {
            lock.lock();
            for chain in chains {
                chain.result(res:false);
            }
            lock.unlock();
            network?.getPeerConnection()?.closePeer();
        }
    }
    
    @discardableResult
    private func setChain() -> NetLink
    {
        let link:NetLink = chains.remove(at:0);
        link.setOnResultCallback(callback:self);
        link.setMainChain();
        network!.changeHandle(handle:link);
        return link;
    }
    
    private func setNextChain()
    {
        if (chains.count > 0) {
            let link:NetLink = setChain();
            link.chainning(connection:network!.getPeerConnection()!, network!.getNextSequence())
        } else if connectionOriented {
            dummy!.chainning(connection:network!.getPeerConnection()!, network!.getNextSequence())
        } else {
            network!.getPeerConnection()!.closePeer();
        }
    }
}

class BytesRemoteChainer {
    
}

