
import Foundation

public let BK_WORKING = "bk-working";
public let BK_RESULT = "bk-result";

func bkLogging(_ log: Any) {
    print(log);
}

public protocol OnResultCallback {
    func result(res:Bool);
}

public protocol OnLinkCallback {
    func finished(result: Bool, name: String, link: NetLink);
}

public protocol NetHandle : Receiver {
    func chainning(connection:PeerConnection, _ sequence:Int);
    func broken();
}

public protocol Network {
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
    
    public func start() {
        peer = createPeer();
    }
    
    func createPeer() -> PeerNIOClient {
        return PeerNIOClient(host: host, port: port, business:self);
    }
    
    public func changeHandle(handle: NetHandle) {
        self.handle = handle;
    }
    
    public func getNextSequence() -> Int {
        let ret = sequence;
        sequence = sequence + 1;
        return ret;
    }
    
    public func getPeerConnection() -> PeerConnection? {
        return peer;
    }
    
    public func receive(connection:PeerConnection, data: [UInt8], sequence: Int) {
        handle!.receive(connection: connection, data: data, sequence: sequence);
    }
    
    public func established(connection: PeerConnection) {
        self.connection = connection;
        if handle != nil {
            handle!.chainning(connection: connection, sequence);
            sequence = sequence + 1;
        }
    }
    
    public func removeBusinessData(connection: PeerConnection) {
        if isRemoving {
            return;
        }
        isRemoving = true;
        handle?.broken()
    }
}

public class HTTPNetwork: Network, PeerConnection {
    private var enviroment = [String : Any]();
    private var handle: NetHandle?;
    private var url: String;
    
    public init(_ url: String) {
        self.url = url;
    }
    //jsonString    String    "{\n  \"district_id\" : 2,\n  \"bk_working\" : \"town-list\"\n}"
    //jsonString    String    "{\n  \"district_id\" : 2,\n  \"bk-working\" : \"town-list\"\n}"
    open func sendToPeer(_ data: [UInt8]) {
        let jsonString = String(bytes:data, encoding:.utf8)!;
        let bodyData = jsonString.data(using: .utf8);
        
        let url = URL(string: self.url)!
        var request = URLRequest(url: url)
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpMethod = "POST"
        request.httpBody = bodyData;
        let task = URLSession.shared.dataTask(with: request) { data, response, error in
            guard let data = data, error == nil else {                                                 // check for fundamental networking error
                bkLogging("error=\(String(describing: error))")
                return
            }
            
            if let httpStatus = response as? HTTPURLResponse, httpStatus.statusCode != 200 {           // check for http errors
                bkLogging("statusCode should be 200, but is \(httpStatus.statusCode)")
                bkLogging("response = \(String(describing: response))")
            } else {
                let responseString = String(data: data, encoding: .utf8)
                bkLogging("responseString = \(String(describing: responseString))")
                
                self.handle?.receive(connection: self, data: [UInt8](String(data:data, encoding:String.Encoding.utf8)!.utf8), sequence: 0)
            }
        }
        task.resume()
    }
    
    public func closePeer() {
    }
    
    public func getEnviroment() -> [String : Any] {
        return enviroment;
    }
    
    public func start() {
        handle?.chainning(connection: self, 0);
    }
    
    public func changeHandle(handle: NetHandle) {
        self.handle = handle;
    }
    
    public func getNextSequence() -> Int {
        return 0;
    }
    
    public func getPeerConnection() -> PeerConnection? {
        return self;
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
    
    public override func established(connection: PeerConnection) {
        self.connection = connection;
    }
    
    func handshaked() {
        super.established(connection: self.connection!);
    }
    
    func error() {
        peer?.closePeer();
    }
}

