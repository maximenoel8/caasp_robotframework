import random, string

x = ''.join(random.choices(string.ascii_lowercase + string.digits, k=4))
print(x)