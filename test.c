int fib(int n);

int add(int a, int b);

int main() {
    
    int num = fib(10);
    //int num = add(11, 15);
    //unsigned char num = *(volatile unsigned char*)0x100;
    //volatile unsigned char num = *(volatile unsigned char*)0x100;
    //*(volatile unsigned char*)(0x20020) = (unsigned char)num;
    //for(;;) {}
    return 0;
}   


int add(int a, int b){
    return a + b;

}

int fib(int n) {
    if(n <= 1) return 1;
    return fib(n-1) + fib(n-2);
}