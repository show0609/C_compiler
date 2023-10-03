file = $(wildcard *.c)
exe = $(patsubst %.c, %, $(file))

all: $(exe)

%: %.c myCompiler_test.class
	java -cp ./antlr-3.5.3-complete-no-st3.jar:. myCompiler_test $< | tee $@.ll

myCompiler_test.class: myCompiler.g *.java
	java -cp ./antlr-3.5.3-complete-no-st3.jar org.antlr.Tool myCompiler.g
	javac -cp ./antlr-3.5.3-complete-no-st3.jar:. *.java

clean:
	rm *.class myCompiler.tokens myCompilerLexer.java  myCompilerParser.java
