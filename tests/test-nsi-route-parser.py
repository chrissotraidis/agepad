#!/usr/bin/env python3
"""Exercise the actual route reader with bounded synthetic kernel messages."""
from pathlib import Path
import subprocess,tempfile
root=Path(__file__).resolve().parents[1]
source=r'''
#define sysctl fixture_sysctl
#define if_indextoname fixture_if_indextoname
#include "SOURCE"
#include <assert.h>
static unsigned char fixture[256];static size_t fixture_len;
int fixture_sysctl(int *m,u_int n,void *old,size_t *len,void *newp,size_t newlen){
 (void)m;(void)n;(void)newp;(void)newlen;
 if(!old){*len=fixture_len;return 0;}
 if(*len<fixture_len){errno=ENOMEM;return -1;}
 memcpy(old,fixture,fixture_len);*len=fixture_len;return 0;
}
char *fixture_if_indextoname(unsigned int index,char *name){if(index!=1)return NULL;strcpy(name,"lo0");return name;}
BOOL convert_unix_name_to_luid(const char *name,NET_LUID *luid){(void)name;luid->Value=0;luid->Info.NetLuidIndex=1;return TRUE;}
static void put32(unsigned at,unsigned v){memcpy(fixture+at,&v,4);}
static void setup(void){
 memset(fixture,0,sizeof(fixture));fixture_len=132;fixture[0]=132;fixture[2]=5;fixture[3]=4;fixture[4]=1;
 put32(8,3);put32(12,7);put32(44,7);
 fixture[92]=16;fixture[93]=AF_INET;fixture[96]=10;
 fixture[108]=16;fixture[109]=AF_INET;fixture[112]=10;fixture[115]=1;
 fixture[124]=8;fixture[128]=255;fixture[129]=255;fixture[130]=255;
}
int main(void){
 struct nsi_enumerate_all_ex p={0};struct nsi_ipv4_forward_key key;struct nsi_ip_forward_rw rw;
 setup();assert(agepad_route_enumerate(&p,FALSE)==0&&p.count==1);
 p.key_data=&key;p.key_size=sizeof(key);p.rw_data=&rw;p.rw_size=sizeof(rw);p.count=1;
 assert(agepad_route_enumerate(&p,FALSE)==0&&p.count==1&&key.prefix_len==24&&rw.metric==7);
 assert(((unsigned char *)&key.prefix)[0]==10&&((unsigned char *)&key.next_hop)[3]==1);
 p.count=0;assert(agepad_route_enumerate(&p,FALSE)==STATUS_BUFFER_OVERFLOW);
 p.count=1;fixture[0]=0;assert(agepad_route_enumerate(&p,FALSE)==STATUS_INVALID_PARAMETER);
 setup();fixture_len=91;assert(agepad_route_enumerate(&p,FALSE)==STATUS_INVALID_PARAMETER);
 setup();fixture[92]=255;assert(agepad_route_enumerate(&p,FALSE)==STATUS_INVALID_PARAMETER);
 setup();fixture[2]=99;assert(agepad_route_enumerate(&p,FALSE)==STATUS_NOT_SUPPORTED);
 setup();fixture[129]=0;fixture[130]=255;assert(agepad_route_enumerate(&p,FALSE)==STATUS_INVALID_PARAMETER);
 setup();p.key_size=1;assert(agepad_route_enumerate(&p,FALSE)==STATUS_INVALID_PARAMETER);
 return 0;
}
'''.replace('SOURCE',str(root/'worktrees/madeira/build/ntdll-unix/nsi_routes_ios.c'))
with tempfile.TemporaryDirectory() as d:
 p=Path(d);(p/'test.c').write_text(source)
 cmd=['xcrun','--sdk','macosx','clang','-fsanitize=address,undefined','-Wno-implicit-function-declaration','-D__WINESRC__','-D_NTSYSTEM_','-D_ACRTIMP=','-DWINBASEAPI=','-DWINE_UNIX_LIB','-DWINE_IOS=1']
 for x in ['worktrees/madeira/build/ntdll-unix/shims','worktrees/madeira/wine/build-macos/include','worktrees/madeira/wine/include']:cmd+=['-I'+str(root/x)]
 subprocess.run(cmd+[str(p/'test.c'),'-o',str(p/'test')],check=True)
 subprocess.run([str(p/'test')],check=True)
 print('NSI_ROUTE_PARSER_PASS: actual reader, valid mapping, sizing, short headers, bad lengths/version/mask/ABI')
