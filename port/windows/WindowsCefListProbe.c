#include <windows.h>
#include <stddef.h>
/* ABI prefix from CEF branch6478 cef_base_capi.h / cef_values_capi.h.
 * Only the public list methods through get_type are called. */
typedef struct Base Base;
struct Base { size_t size; void (*add_ref)(Base*); int (*release)(Base*);
 int (*has_one_ref)(Base*); int (*has_at_least_one_ref)(Base*); };
typedef struct List List;
struct List { Base base; int (*is_valid)(List*); int (*is_owned)(List*);
 int (*is_read_only)(List*); int (*is_same)(List*,List*); int (*is_equal)(List*,List*);
 List* (*copy)(List*); int (*set_size)(List*,size_t); size_t (*get_size)(List*);
 int (*clear)(List*); int (*remove)(List*,size_t); int (*get_type)(List*,size_t); };
static void say(const char *s,DWORD n){DWORD wrote;WriteFile(GetStdHandle(STD_OUTPUT_HANDLE),s,n,&wrote,0);}
#define SAY(s) say(s,sizeof(s)-1)
void mainCRTStartup(void){
 SAY("AGEPAD_CEF_LIST: BEGIN\n");
 WCHAR path[MAX_PATH];DWORD n=GetModuleFileNameW(0,path,MAX_PATH);
 if(!n||n>=MAX_PATH)ExitProcess(10);
 while(n&&path[n-1]!=L'\\')n--;
 const WCHAR suffix[]=L"bin\\cef\\cef.win64\\libcef.dll";
 if(n+sizeof(suffix)/sizeof(WCHAR)>MAX_PATH)ExitProcess(11);
 for(size_t i=0;i<sizeof(suffix)/sizeof(WCHAR);i++)path[n+i]=suffix[i];
 HMODULE dll=LoadLibraryExW(path,0,LOAD_WITH_ALTERED_SEARCH_PATH);
 if(!dll){SAY("AGEPAD_CEF_LIST: LOAD_FAILED\n");ExitProcess(12);}
 List* (*create)(void)=(void*)GetProcAddress(dll,"cef_list_value_create");
 if(!create)ExitProcess(13);
 SAY("AGEPAD_CEF_LIST: DLL_LOADED\n");
 List* list=create();
 if(!list||list->base.size<sizeof(List)||!list->is_valid(list))ExitProcess(14);
 SAY("AGEPAD_CEF_LIST: CREATED\n");
 if(list->get_size(list)!=0||!list->set_size(list,3)||list->get_size(list)!=3)ExitProcess(15);
 SAY("AGEPAD_CEF_LIST: RESIZED\n");
 for(size_t i=0;i<3;i++)if(list->get_type(list,i)!=1)ExitProcess(16); /* VTYPE_NULL */
 SAY("AGEPAD_CEF_LIST: TYPES_PASS\n");
 List* copy=list->copy(list);
 SAY("AGEPAD_CEF_LIST: COPIED\n");
 if(list->get_size(list)!=3)ExitProcess(21);
 SAY("AGEPAD_CEF_LIST: COPY_ORIGINAL_INTACT\n");
 if(!copy||!copy->is_valid(copy))ExitProcess(17);
 /* CEF's CppToC::Unwrap consumes a reference for non-self refptr arguments.
  * See libcef_dll/cpptoc/cpptoc_ref_counted.h, branch6478. */
 list->base.add_ref(&list->base);
 if(!copy->is_equal(copy,list)||copy->get_type(copy,0)!=1)ExitProcess(17);
 SAY("AGEPAD_CEF_LIST: EQUAL_PASS\n");
 if(list->get_size(list)!=3)ExitProcess(22);
 SAY("AGEPAD_CEF_LIST: EQUAL_ORIGINAL_INTACT\n");
 if(!copy->clear(copy))ExitProcess(18);
 SAY("AGEPAD_CEF_LIST: CLEAR_RETURNED\n");
 if(copy->get_size(copy)!=0)ExitProcess(19);
 SAY("AGEPAD_CEF_LIST: COPY_EMPTY\n");
 if(list->get_size(list)!=3)ExitProcess(20);
 SAY("AGEPAD_CEF_LIST: CLEAR_PASS\n");
 copy->base.release(&copy->base);list->base.release(&list->base);
 SAY("AGEPAD_CEF_LIST: CREATE_RESIZE_TYPE_COPY_CLEAR_PASS\n");
 ExitProcess(0);
}
