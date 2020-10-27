# define some Makefile variables for the compiler and compiler flags
ASM = nasm
LINKER = gcc
ASMFLAGS = -g -f elf
LINKERFLAGS = -m32 -Wall
OBJS = ass3.o target.o printer.o scheduler.o drone.o

# All Targets
all: ass3

# Tool invocations
ass3: $(OBJS)
	@echo 'Invoking Linker'
	$(LINKER) $(LINKERFLAGS) $(OBJS) -o ass3
	@echo 'Finished building target.'
	@echo ' '

ass3.o: ass3.s
	$(ASM) $(ASMFLAGS) ass3.s -o ass3.o
	
target.o: target.s
	$(ASM) $(ASMFLAGS) target.s -o target.o
	
printer.o: printer.s
	$(ASM) $(ASMFLAGS) printer.s -o printer.o

scheduler.o: scheduler.s
	$(ASM) $(ASMFLAGS) scheduler.s -o scheduler.o
	
drone.o: drone.s
	$(ASM) $(ASMFLAGS) drone.s -o drone.o

.PHONY: clean

#Clean the build directory
clean:
	rm -f *.o ass3
