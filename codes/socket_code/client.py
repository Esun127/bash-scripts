import socket


server_address=('127.0.0.1', 9000)
mysocket = socket.socket(socket.AF_INET, socket.SOCK_STREAM)

mysocket.connect(server_address)
data = mysocket.recv(1024).decode()
print(data)

while True:
    data = input(">>Please Input Message: ").strip()
    
    ## 不能发送空
    if not data:
        continue

    if data == "退出" or data == 'exit':
        data='exit'
        mysocket.shutdown(2)
        break



    mysocket.sendall(data.encode())
    data = mysocket.recv(1024).decode()
    print(data)
    # mysocket.sendall(b"exit")
    # data = mysocket.recv(1024)
    # print(data.decode())

