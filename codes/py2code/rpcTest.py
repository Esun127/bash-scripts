import pickle

class RPCHandler:


    def __init__(self):
        self._functions = {}


    def register_function(self, func):
        self._functions[func.__name__] = func

    def handle_connection(self, connection):
        try:
            while True:
                # 从通信连接里收取发来的消息并反序列化
                func_name, args, kwargs = pickle.loads(connection.recv())
                try:
                    # 从_functions属性中获取并执行函数
                    r = self._functions[func_name](*args, **kwargs)
                    # 函数运行返回值序列化后作为响应消息
                    connection.send(pickle.dumps(r))
                except Exception as e:
                    # 发送异常消息
                    connection.send(pickle.dumps(e))
        except EOFError:
            pass


#################

from multiprocessing.connection import Listener
from threading import Thread


def rpc_server(handler, address, authkey):
    sock = Listener(address, authkey=authkey)
    while True:
        client = sock.accept()
        t =  Thread(target=handler.handle_connection, args=(client,))
        t.daemon = True
        t.start()

# 定义一些待远程执行的函数
def add(x, y):
    return x + y

def sub(x, y):
    return x - y



if __name__ == '__main__':
    
    # 注册待远程执行函数
    handler = RPCHandler()
    handler.register_function(add)
    handler.register_function(sub)


    # 运行RPC服务
    rpc_server(handler, ('localhost', 8000), authkey=b"nihao")