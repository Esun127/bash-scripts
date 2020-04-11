

import socketserver



class MyHandler(socketserver.BaseRequestHandler):
    '''
    必须继承socketserver.BaseRequestHandler类
    必须实现handle方法
    '''

    def handle(self):
        '''
        必须实现这个方法, 此处为简单消息收发
        : return: 
        '''
        # self.request 封装了所有请求的数据
        conn = self.request
        client_address = self.client_address

        # print(client_address)
        server_ = self.server
        # print(server_.server_address)

        conn.sendall("欢迎访问socketserver服务器!".encode())

        while True:
            data = conn.recv(1024).decode()
            if data == 'exit':
                print(f"断开与{client_address}的连接.")
                server_.shutdown()
                break
            print(f"自{client_address}发来的消息: {data}")
            response_string = f"已经收到{client_address}的消息."
            conn.sendall(response_string.encode())


if __name__ == "__main__":
    # 创建一个多线程TCP服务器
    server = socketserver.ThreadingTCPServer(('127.0.0.1', 9000), MyHandler)
    print("启动socketserver服务器! ")
    server.serve_forever()



