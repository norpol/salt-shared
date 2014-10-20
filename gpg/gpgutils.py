#!/usr/bin/env python
# -*- coding: utf-8 -*-
"""
Encryption/Signing, Decryption/Verifying modul.

- This module uses Gnu Privacy Guard for the actual encryption work

  - The GNU Privacy Guard -- a free implementation of the OpenPGP standard as defined by RFC4880 

"""

import sys, os, subprocess, tempfile, re, inspect, pydoc

GPG_EXECUTABLE = 'gpg'

def _strbool(text):
    ''' return either the boolean value (if isinstance(text,bool) or True if string is one of True or Yes (case insensitiv) or False'''
    if isinstance(text,bool):
        return text
    else:
        text = text.upper()
        return text in ['TRUE', 'YES']

def reset_keystore(gpghome):
    ''' wipes out keystore under directory gpghome
    
    :warn: deletes every file in this directory
    ''' 
    if not os.path.isdir(gpghome):
        os.makedirs(gpghome)
    for f in os.listdir(gpghome):
        path = os.path.join(gpghome, f);
        if os.path.isfile(path):
            os.remove(path)

def gen_keypair(ownername, secretkey_filename, publickey_filename, keylength= 2048, ask_passphrase=False):
    ''' writes a pair of ascii armored key files, first is secret key, second is publickey, minimum ownername length is five'''
    
    gpghome = tempfile.mkdtemp()

    batch_args = ""
    if _strbool(ask_passphrase):
        batch_args += "%ask-passphrase\n"

    batch_args += "Key-Type: 1\nKey-Length: {0}\nExpire-Date: 0\nName-Real: {1}\n".format(keylength, ownername)
    batch_args += "%secring {0}\n%pubring {1}\n".format(secretkey_filename, publickey_filename)

    batch_args += "%commit\n%echo done\n"
    
    args = [GPG_EXECUTABLE, '--homedir' , gpghome, '--batch', '--armor', '--yes', '--gen-key']
    popen = subprocess.Popen(args, stderr=subprocess.STDOUT, stdout=subprocess.PIPE, stdin=subprocess.PIPE)
    stdout, empty = popen.communicate(batch_args)
    popen.stdin.close()
    returncode = popen.returncode
    
    reset_keystore(gpghome) # wipe keystore after keypair creation
    
    if returncode != 0:
        raise IOError('gpg --gen-key returned error code: %d , cmd line was: %s , output was: %s' % (returncode, str(args), stdout))
    else:
        print("gpg --gen-key ran successful, output was {0}".format(str(stdout)))

def import_key(keyfile, gpghome):
    ''' import a keyfile (generated by gen_keypair) into gpghome directory gpg keyring '''
    args = [GPG_EXECUTABLE, '--homedir' , gpghome, '--batch', '--yes', '--import', keyfile]
    popen = subprocess.Popen(args, stderr=subprocess.STDOUT, stdout=subprocess.PIPE)
    stdout, empty = popen.communicate()
    returncode = popen.returncode
    if returncode != 0:
        raise IOError('gpg --import returned error code: %d , cmd line was: %s , output was: %s' % (returncode, str(args), stdout))
   
def publickey_list(gpghome):
    ''' returns a string listing all keys in keystore of gpghome '''
    args = [GPG_EXECUTABLE, '--homedir' , gpghome, '--batch', '--yes', '--fixed-list-mode',
        '--with-colons', '--list-keys', '--with-fingerprint', '--with-fingerprint']
    popen = subprocess.Popen(args, stderr=subprocess.PIPE, stdout=subprocess.PIPE)
    stdout, stderr = popen.communicate()
    returncode = popen.returncode
    if returncode != 0:
        raise IOError('gpg --import returned error code: %d , cmd line was: %s , output was: %s' % (returncode, str(args), stdout+ stderr))
    return stdout

def secretkey_list(gpghome):
    ''' returns a string listing all keys in keystore of gpghome '''
    args = [GPG_EXECUTABLE, '--homedir' , gpghome, '--batch', '--yes', '--fixed-list-mode',
        '--with-colons', '--list-secret-keys', '--with-fingerprint', '--with-fingerprint']
    popen = subprocess.Popen(args, stderr=subprocess.PIPE, stdout=subprocess.PIPE)
    stdout, stderr = popen.communicate()
    returncode = popen.returncode
    if returncode != 0:
        raise IOError('gpg --import returned error code: %d , cmd line was: %s , output was: %s' % (returncode, str(args), stdout+ stderr))
    return stdout

def encrypt_sign(sourcefile, destfile, gpghome, encrypt_owner, signer_owner=None):
    ''' read sourcefile, encrypt and optional sign and write destfile
    
    :note: booth sourcefile and destfile should already exist (destfile should be zero length)
    :param gpghome: directory where the .gpg files are
    :param encrypt_owner: owner name of key for encryption using his/her public key 
    :param signer_owner: if not None: owner name of key for signing using his/her secret key 
    '''
    args = [GPG_EXECUTABLE, '--homedir', gpghome, '--batch', '--yes', '--always-trust', 
            '--recipient', encrypt_owner, '--output', destfile]
    if signer_owner:
        args += ['--local-user', signer_owner, '--sign']
    args += ['--encrypt', sourcefile]
     
    popen = subprocess.Popen(args, stderr=subprocess.STDOUT, stdout=subprocess.PIPE)
    stdout, empty = popen.communicate()
    returncode = popen.returncode
    if returncode != 0:
        raise IOError('gpg --encrypt returned error code: %d , cmd line was: %s , output was: %s' % (returncode, str(args), stdout))
    

def decrypt_verify(sourcefile, destfile, gpghome, decrypt_owner, verify_owner=None):
    ''' read sourcefile, decrypt and optional verify if signer is verify_owner
    
    :param decrypt_owner: owner name of key used for decryption using his/her secret key
    :param verify_owner: owner name of key used for verifying that it was signed using his/her public key
    :raise IOError: on gnupg error, with detailed info
    :raise KeyError: if key owner could not be verified
    '''
    args = [GPG_EXECUTABLE, '--homedir', gpghome, '--batch', '--yes', '--always-trust', 
            '--recipient', decrypt_owner, 
            '--output', destfile, '--decrypt', sourcefile
            ] 
    popen = subprocess.Popen(args, stderr=subprocess.STDOUT, stdout=subprocess.PIPE)
    stdout, empty = popen.communicate()
    returncode = popen.returncode
    if returncode != 0:
        raise IOError('gpg --decrypt returned error code: %d , cmd line was: %s , output was: %s' % (returncode, str(args), stdout))
    
    if verify_owner is not None:
        p = re.compile('gpg: Good signature from "'+ verify_owner+ '"')
        if p.match is None:
            raise KeyError, 'could not verify that signer was keyowner: %s , cmd line was: %s , output was: %s' % (verify_owner, str(args), stdout)


def help(which=None):
    ''' help about all functions or one specific function '''
    m = sys.modules[__name__]
    if which:
        print (pydoc.render_doc(getattr(m, which)))
    else:
        print (pydoc.render_doc(m))

if __name__ == "__main__":
    args = sys.argv
    args.pop(0)
    m = sys.modules[__name__]
    if not args:
        help()
    else:
        c = args.pop(0)
        f = getattr(m, c)
        r = f(*args)
        if r:
            print(r)
