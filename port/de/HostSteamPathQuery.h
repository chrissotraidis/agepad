#pragma once
// Read-only request observed from the supplied real SDK. No registration.
#include <mach/mach.h>
#include <servers/bootstrap.h>
#include <stdint.h>
#include <string.h>
#include <unistd.h>
static kern_return_t DEReadHostSteamPath(unsigned char payload[520]) {
    mach_port_t service=MACH_PORT_NULL,reply=MACH_PORT_NULL;
    kern_return_t status=bootstrap_look_up(bootstrap_port,"com.valvesoftware.steam.ipctool",&service);
    if (status!=KERN_SUCCESS) return status;
    status=mach_port_allocate(mach_task_self(),MACH_PORT_RIGHT_RECEIVE,&reply);
    if (status==KERN_SUCCESS) {
        struct { mach_msg_header_t header; uint32_t operation; uint32_t pid; } request={0};
        request.header.msgh_bits=MACH_MSGH_BITS(MACH_MSG_TYPE_COPY_SEND,MACH_MSG_TYPE_MAKE_SEND);
        request.header.msgh_size=sizeof(request);
        request.header.msgh_remote_port=service;
        request.header.msgh_local_port=reply;
        request.header.msgh_id=104;
        request.operation=14;request.pid=getpid();
        status=mach_msg(&request.header,MACH_SEND_MSG|MACH_SEND_TIMEOUT,sizeof(request),0,MACH_PORT_NULL,2000,MACH_PORT_NULL);
        if (status==MACH_MSG_SUCCESS) {
            union { mach_msg_header_t header; unsigned char bytes[1024]; } response={0};
            status=mach_msg(&response.header,MACH_RCV_MSG|MACH_RCV_TIMEOUT,0,sizeof(response),reply,2000,MACH_PORT_NULL);
            if (status==MACH_MSG_SUCCESS) {
                if (response.header.msgh_size!=544 || response.header.msgh_id!=104 ||
                    (response.header.msgh_bits&MACH_MSGH_BITS_COMPLEX) || !memchr(response.bytes+32,0,512)) {
                    status=KERN_INVALID_ARGUMENT;
                } else memcpy(payload,response.bytes+24,520);
                mach_msg_destroy(&response.header);
            }
        }
        mach_port_mod_refs(mach_task_self(),reply,MACH_PORT_RIGHT_RECEIVE,-1);
    }
    mach_port_deallocate(mach_task_self(),service);
    return status;
}
