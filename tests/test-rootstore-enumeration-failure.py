#!/usr/bin/env python3
"""Run actual PE root-sync control flow with injected enumeration/allocation errors."""
from pathlib import Path
import subprocess,tempfile
root=Path(__file__).resolve().parents[1]
s=(root/'worktrees/madeira/wine/dlls/crypt32/rootstore.c').read_text()
s=s[s.index('static void sync_trusted_roots_from_known_locations'):s.index('\nvoid CRYPT_ImportSystemRootCertsToReg')]
pre=r'''
#include <cassert>
#include <cstdint>
#include <cstdlib>
#include <cstring>
using DWORD=uint32_t;using NTSTATUS=uint32_t;using BYTE=unsigned char;using WCHAR=wchar_t;
using HKEY=uintptr_t;using HCERTSTORE=uintptr_t;using HCRYPTPROV=uintptr_t;using HCRYPTHASH=uintptr_t;using PCCERT_CONTEXT=void*;
struct CRYPT_DATA_BLOB {DWORD size;BYTE *data;};using CRYPT_HASH_BLOB=CRYPT_DATA_BLOB;
struct enum_root_certs_params {void *buffer;unsigned size;unsigned *needed;};
#define STATUS_NO_MEMORY 0xc0000017u
#define STATUS_NO_MORE_ENTRIES 0x8000001au
#define HKEY_LOCAL_MACHINE 1
#define KEY_ALL_ACCESS 1
#define PROV_RSA_FULL 1
#define CRYPT_VERIFYCONTEXT 1
#define CALG_SHA1 1
#define HP_HASHVAL 1
#define X509_ASN_ENCODING 1
#define CERT_FIND_SHA1_HASH 1
#define CERT_FIRST_USER_PROP_ID 1
#define CERT_STORE_ADD_ALWAYS 1
#define NULL nullptr
#define ERR(...) ((void)0)
#define TRACE(...) ((void)0)
static int mode,calls,allocs,deletions,closed,cert_obj;
static NTSTATUS enumerate(enum_root_certs_params *p) {
 ++calls;
 if(mode==0)return STATUS_NO_MORE_ENTRIES;
 if(mode==1)return STATUS_NO_MEMORY;
 if(mode==2 && calls>1)return STATUS_NO_MEMORY;
 *p->needed=mode==4?4096:4;
 if(p->size>=*p->needed)memset(p->buffer,0,*p->needed);
 return 0;
}
#define CRYPT32_CALL(name,p) enumerate(p)
static BYTE *CryptMemAlloc(size_t n){++allocs;return ((mode==3)||(mode==4&&allocs==2))?nullptr:static_cast<BYTE*>(malloc(n));}
static void CryptMemFree(void *p){free(p);}
static int RegOpenKeyExW(HKEY,const WCHAR*,int,int,HKEY *p){*p=2;return 0;}
static int RegCreateKeyExW(HKEY,const WCHAR*,int,void*,int,int,void*,HKEY *p,void*){*p=2;return 0;}
static int RegRenameKey(HKEY,void*,const WCHAR*){return 0;}
static int RegCloseKey(HKEY){++closed;return 0;}
static void mark_cert_imported(HKEY,PCCERT_CONTEXT){}
static int CryptAcquireContextW(HCRYPTPROV *p,void*,void*,int,int){*p=3;return 1;}
static int CryptReleaseContext(HCRYPTPROV,int){return 1;}
static int CryptCreateHash(HCRYPTPROV,int,int,int,HCRYPTHASH *p){*p=4;return 1;}
static int CryptHashData(HCRYPTHASH,void*,DWORD,int){return 1;}
static int CryptGetHashParam(HCRYPTHASH,int,BYTE*p,DWORD*n,int){memset(p,0,*n);return 1;}
static int CryptDestroyHash(HCRYPTHASH){return 1;}
static PCCERT_CONTEXT CertFindCertificateInStore(HCERTSTORE,int,int,int,void*,void*){return nullptr;}
static int CertGetCertificateContextProperty(PCCERT_CONTEXT,int,void*,DWORD*){return 0;}
static int CertSetCertificateContextProperty(PCCERT_CONTEXT,int,int,void*){return 1;}
static int CertFreeCertificateContext(PCCERT_CONTEXT){return 1;}
static int CertAddEncodedCertificateToStore(HCERTSTORE,int,void*,DWORD,int,PCCERT_CONTEXT*p){*p=&cert_obj;return 1;}
static PCCERT_CONTEXT CertEnumCertificatesInStore(HCERTSTORE,PCCERT_CONTEXT p){return !p&&!deletions?&cert_obj:nullptr;}
static void get_cert_context_hash(PCCERT_CONTEXT,BYTE*,WCHAR*){}
static int RegQueryValueExW(HKEY,WCHAR*,void*,void*,BYTE*,DWORD*){return 0;}
static void CRYPT_RegDeleteFromReg(HKEY,BYTE*){++deletions;}
static int RegDeleteValueW(HKEY,WCHAR*){return 0;}
static int CertDeleteCertificateFromStore(PCCERT_CONTEXT){return 1;}
static void check_and_store_certs(HCERTSTORE,HKEY,HKEY){}
'''
main=r'''
int main(){
 for(mode=0;mode<=4;++mode){
  calls=allocs=deletions=closed=0;
  sync_trusted_roots_from_known_locations(1,1);
  assert(closed==1);
  assert(deletions==(mode==0?1:0));
  if(mode==3)assert(calls==0);
  if(mode==2)assert(calls==2);
 }
}
'''
with tempfile.TemporaryDirectory() as d:
 p=Path(d)/'test.cpp';exe=Path(d)/'test';p.write_text(pre+s+main)
 subprocess.run(['clang++','-std=c++17','-Wno-macro-redefined','-fsanitize=address,undefined',str(p),'-o',str(exe)],check=True)
 subprocess.run([str(exe)],check=True)
print('PASS: actual root-sync control flow preserves roots on initial/partial enumeration failure and buffer OOM; complete EOF still removes absent imported root. Crypto and registry APIs mocked; not device qualification.')
