# run python3 -m http.server
# for example
import nimuring
import nativesockets
import net

var q = newQueue(4)
var socket = createNativeSocket()

var ai = getAddrInfo("google.com", 80.Port)
echo ai.ai_addrlen
q.connect(0, socket, ai.ai_addr, ai.ai_addrlen).linkNext()
const request = """GET / HTTP/1.1
User-Agent: io_uring
Host: google.com
Accept-Language: en-us
Connection: Keep-Alive

"""
q.send(1, socket, request.cstring, request.len).linkNext()
var resp = q.recv(2, socket, 4096)
q.submit(3)
echo resp