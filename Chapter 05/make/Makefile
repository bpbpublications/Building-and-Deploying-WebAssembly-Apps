# Define the compiler and linker
CC = emcc

# Define the source files
SRCS = main.cpp

# Define the output file
OUTPUT = index.html

# Define compiler and linker flags
CFLAGS = -O2
LDFLAGS =

# Define the rule for building the project
all: $(OUTPUT)

# Define the rule for linking the project
$(OUTPUT): $(SRCS)
	$(CC) $(CFLAGS) $(SRCS) -o $(OUTPUT) $(LDFLAGS)

# Define the rule for cleaning up generated files
clean:
	rm -f $(OUTPUT)
