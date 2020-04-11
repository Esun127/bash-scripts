import pickle


class RPCProxy:

    def __init__(self, connection):
        self._connection = connection


    def __getattr__(self, name):
        def do_rpc(*args, **kwargs):
            # 将类属性名(即为函数名), 列表参数, 关键字参数 序列化后 发送给 服务器
            self._connection.send(pickle.dumps((name, args, kwargs)))
            # 从服务器收取响应消息并反序列化到result
            result = pickle.load(self._connection.recv())
            if isinstance(result, Exception):
                raise result
            return result
        return do_rpc





if __name__ == '__main__':

    from multiprocessing.connection import Client

    c = Client(('localhost', 8000), authkey=b"nihao")

    proxy = RPCProxy(c)
    print(proxy.add(2,3))
    print(proxy.sub(4,3))


