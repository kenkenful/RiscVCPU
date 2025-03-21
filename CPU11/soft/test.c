#include <stdint.h>

#define MTVEC_VECTORED_MODE 0x1U

extern void Schedule(void);
extern int  switch_context(unsigned long *next_sp, unsigned long* sp);
extern void load_context(unsigned long *sp);

extern void EnableTimer(void);
extern void EnableInt(void);
extern void DisableInt(void);
extern void spend_time(void);
extern void trap_vectors(void);
extern void SetTrapVectors(unsigned long);

int Timer(void);

int fib(int n);
int add(int a, int b);

volatile unsigned long * const mtime    = ((unsigned long *)0x20000020);
volatile unsigned long * const mtimecmp = ((unsigned long *)0x20000040);

int main() {
    //*mtime = 100;
    //SetTrapVectors((unsigned long)trap_vectors + MTVEC_VECTORED_MODE);

    //*mtimecmp = *mtime + 1000;
    //EnableTimer();
    //EnableInt();

    int num = fib(10);    
 
    //DisableInt();

    //fib(15);
   // uint32_t value;
   // __asm__ __volatile__("csrr %0, mtime" : "=r"(value));
   // __asm__ __volatile__("csrr %0, mtimecmp" : "=r"(value));

    //*(volatile unsigned int* ) 0x3fff = 0x22;
    //int num = fib(10);
    //int num = add(11, 15);
    //unsigned char num = *(volatile unsigned char*)0x100;
    //volatile unsigned char num = *(volatile unsigned char*)0x100;
    //*(volatile unsigned char*)(0x20020) = (unsigned char)num;
    //for(;;) {}
    return 0xff;
}   

int add(int a, int b){
    return a + b;
}

int fib(int n) {
    if(n <= 1) return 1;
    return fib(n-1) + fib(n-2);
}

int Timer(void)
{
    *mtimecmp = *mtime + 379;
    return fib(3);    

}