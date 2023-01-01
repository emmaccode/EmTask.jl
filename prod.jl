using Pkg; Pkg.activate(".")
using Toolips
using EmTask

IP = "127.0.0.1"
PORT = 8000
EmTaskServer = EmTask.start(IP, PORT)
