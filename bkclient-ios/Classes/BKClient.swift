
import Foundation

public let BK_WORKING = "bk_working";
public let BK_RESULT = "bk_result";

func bkLogging(_ log: Any) {
    print(log);
}

protocol OnResultCallback {
    func result(res:Bool);
}

protocol OnLinkCallback {
    func finished(result: Bool, name: String, link: NetLink);
}

protocol NetHandle : Receiver {
    func chainning(connection:PeerConnection, _ sequence:Int);
    func broken();
}

protocol Network {
    func start();
    func changeHandle(handle:NetHandle);
    func getNextSequence() -> Int;
    func getPeerConnection() -> PeerConnection?;
}

public class NIONetwork : Network, Business {
    var connection:PeerConnection?;
    var peer:PeerNIOClient?;
    var host:String = "";
    var port:Int32 = -1;
    var handle:NetHandle?;
    private var sequence = 1000;
    private var isRemoving = false;
    
    init(handle:NetHandle?, url:String, port:Int32)
    {
        self.host = url;
        self.port = port;
        self.handle = handle;
    }
    
    init(handle:NetHandle?) {
        self.handle = handle;
    }
    
    func start() {
        peer = createPeer();
    }
    
    func createPeer() -> PeerNIOClient {
        return PeerNIOClient(host: host, port: port, business:self);
    }
    
    func changeHandle(handle: NetHandle) {
        self.handle = handle;
    }
    
    func getNextSequence() -> Int {
        let ret = sequence;
        sequence = sequence + 1;
        return ret;
    }
    
    func getPeerConnection() -> PeerConnection? {
        return peer;
    }
    
    func receive(connection:PeerConnection, data: [UInt8], sequence: Int) {
        handle!.receive(connection: connection, data: data, sequence: sequence);
    }
    
    func established(connection: PeerConnection) {
        self.connection = connection;
        if handle != nil {
            handle!.chainning(connection: connection, sequence);
            sequence = sequence + 1;
        }
    }
    
    func removeBusinessData(connection: PeerConnection) {
        if isRemoving {
            return;
        }
        isRemoving = true;
        handle?.broken()
    }
}

public class SSLNIONetwork : NIONetwork, HandshakeCallback {
    private var sec:Secure?;
    
    init(handle: NetHandle?, url: String, port: Int32, keystore:String, type:String, phase:String) {
        super.init(handle: handle)
        self.host = url;
        self.port = port;
        self.sec = SSLSecure(keystore:"test_c", type:"pfx", phase:"server", receiver:self);
    }
    
    override func createPeer() -> PeerNIOClient {
        return PeerNIOClient(host: host, port: port, business:self, sec: sec!, callback:self);
    }
    
    override func established(connection: PeerConnection) {
        self.connection = connection;
    }
    
    func handshaked() {
        super.established(connection: self.connection!);
    }
    
    func error() {
        peer?.closePeer();
    }
}

