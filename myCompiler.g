grammar myCompiler;

options {
   language = Java;
}

@header {
    // import packages here.
    import java.util.HashMap;
    import java.util.ArrayList;
}

@members {
    boolean TRACEON = false;
    String str;
    String tmp;
    int size;
    

    // Type information.
    public enum Type{
       ERR, BOOL, INT, FLOAT, CHAR, CONST_INT, CONST_BOOL;
    };

    class Label{
        String Ltrue;
        String Lfalse;
        String Lend;
        String Lstart;
        String Lnext;
    };

    // This structure is used to record the information of a variable or a constant.
    class tVar {
       int   varIndex; // temporary variable's index. Ex: t1, t2, ..., etc.
       int   iValue;   // value of constant integer. Ex: 123.
       float fValue;   // value of constant floating point. Ex: 2.314.
       boolean  bValue;
    };

    class Info {
       Type theType;  // type information.
       tVar theVar;
       
       Info() {
          theType = Type.ERR;
          theVar = new tVar();
       }
    };

    
    // ============================================
    // Create a symbol table.
    // ArrayList is easy to extend to add more info. into symbol table.
    //
    // The structure of symbol table:
    // <variable ID, [Type, [varIndex or iValue, or fValue]]>
    //    - type: the variable type   (please check "enum Type")
    //    - varIndex: the variable's index, ex: t1, t2, ...
    //    - iValue: value of integer constant.
    //    - fValue: value of floating-point constant.
    // ============================================

    HashMap<String, Info> symtab = new HashMap<String, Info>();

    // labelCount is used to represent temporary label.
    // The first index is 0.
    int labelCount = 0;
    
    // varCount is used to represent temporary variables.
    // The first index is 0.
    int varCount = 0;

    int strCount = 0;

    // Record all assembly instructions.
    List<String> TextCode = new ArrayList<String>();


    /*
     * Output prologue.
     */
    void prologue()
    {
        TextCode.add("; === prologue ====");
        TextCode.add("declare dso_local i32 @printf(i8*, ...)\n");
        TextCode.add("define dso_local i32 @main()");
        TextCode.add("{");
    }
    
    
    /*
     * Output epilogue.
     */
    void epilogue()
    {
        /* handle epilogue */
        TextCode.add("\n; === epilogue ===");
        TextCode.add("ret i32 0");
        TextCode.add("}");
    }
    
    int strLen(String str){
        int len=str.length();
        int count=0;
        for(int i=0; i<len; i++){
            if(str.charAt(i)=='\\'){
                count++;
            }
        }
        return len-count*2; 
    }
    
    /* Generate a new label */
    String newLabel()
    {
       labelCount ++;
       return (new String("L")) + Integer.toString(labelCount);
    } 
    
    
    public List<String> getTextCode()
    {
       return TextCode;
    }
}

program: (VOID | type) MAIN '(' ')'
        {
           /* Output function prologue */
           prologue();
        }

        '{' 
           declarations
           statements
        '}'
        {
       if (TRACEON)
          System.out.println("VOID MAIN () {declarations statements}");

           /* output function epilogue */	  
           epilogue();
        }
        ;


declarations:
    type Identifier
        {
           if (TRACEON)
              System.out.println("declarations: type Identifier : declarations");

           if (symtab.containsKey($Identifier.text)) {
              // variable re-declared.
              System.out.println("Type Error: " + 
                                  $Identifier.getLine() + 
                                 ": Redeclared identifier.");
              System.exit(0);
           }
                 
           /* Add ID and its info into the symbol table. */
           Info the_entry = new Info();
           the_entry.theType = $type.attr_type;
           the_entry.theVar.varIndex = varCount;
           varCount ++;
           symtab.put($Identifier.text, the_entry);

           // issue the instruction.
           // Ex: \%a = alloca i32, align 4
           if ($type.attr_type == Type.INT) { 
              TextCode.add("\%t" + the_entry.theVar.varIndex + " = alloca i32, align 4");
           }
        }
    ('=' cond_expression
        {
            Info theRHS = $cond_expression.theInfo;
            Info theLHS = symtab.get($Identifier.text); 

            if ((theLHS.theType == Type.INT) &&
                (theRHS.theType == Type.INT)) {		   
                // issue store insruction.
                // Ex: store i32 \%tx, i32* \%ty
                TextCode.add("store i32 \%t" + theRHS.theVar.varIndex + ", i32* \%t" + theLHS.theVar.varIndex);
            } else if ((theLHS.theType == Type.INT) &&
                (theRHS.theType == Type.CONST_INT)) {
                // issue store insruction.
                // Ex: store i32 value, i32* \%ty
                TextCode.add("store i32 " + theRHS.theVar.iValue + ", i32* \%t" + theLHS.theVar.varIndex);				
            }
        }
    )? ';' declarations
    | 
        {
           if (TRACEON)
              System.out.println("declarations: ");
        }
        ;


type
returns [Type attr_type]
    : INT { if (TRACEON) System.out.println("type: INT"); $attr_type=Type.INT; }
    | CHAR { if (TRACEON) System.out.println("type: CHAR"); $attr_type=Type.CHAR; }
    | FLOAT {if (TRACEON) System.out.println("type: FLOAT"); $attr_type=Type.FLOAT; }
    ;


statements:statement statements
          |
          ;


statement: assign_stmt ';'
    | cond_expression ';'
    | if_stmt
    | func_no_return_stmt ';'
    | for_stmt
    | while_stmt
    | printf ';'
    ;

for_stmt
returns [Label theLabel]
@init {theLabel = new Label();}
    :
    FOR '(' assign_stmt ';'
        {
            $theLabel.Lstart=newLabel();
            $theLabel.Ltrue=newLabel();
            $theLabel.Lnext=newLabel();
            $theLabel.Lend=newLabel();
            TextCode.add("br label \%" + $theLabel.Lstart);
            TextCode.add($theLabel.Lstart + ":");
        }
    cond_expression ';'
        {   
            TextCode.add("br i1 \%t" + $cond_expression.theInfo.theVar.varIndex + ", label \%" + $theLabel.Ltrue + ", label \%" + $theLabel.Lend);
            TextCode.add($theLabel.Lnext + ":");
        }
    assign_stmt
    ')'
        {
            TextCode.add("br label \%" + $theLabel.Lstart);
            TextCode.add($theLabel.Ltrue + ":");

        }
    block_stmt
        {
            TextCode.add("br label \%" + $theLabel.Lnext);
            TextCode.add($theLabel.Lend + ":");
        }
    ;
while_stmt
returns [Label theLabel]
@init {theLabel = new Label();}
    :
    WHILE
        {
            $theLabel.Lstart=newLabel();
            $theLabel.Ltrue=newLabel();
            $theLabel.Lend=newLabel();
            TextCode.add("br label \%" + $theLabel.Lstart);
            TextCode.add($theLabel.Lstart + ":");
        }
    '(' cond_expression')'
        {
            TextCode.add("br i1 \%t" + $cond_expression.theInfo.theVar.varIndex + ", label \%" + $theLabel.Ltrue + ", label \%" + $theLabel.Lend);
            TextCode.add($theLabel.Ltrue + ":");
        }
    block_stmt
        {
            TextCode.add("br label \%" + $theLabel.Lstart);
            TextCode.add($theLabel.Lend + ":");
        }
    ;

printf
    :PRINTF '(' STRING
        {
            if (TRACEON) System.out.println("function: printf");

            str=$STRING.text.replace("\\n","\\0A");
            str=str.replace("\"","");
            str+="\\00";
            size=strLen(str);
            tmp="";
        }

     (',' Identifier
        {
            Info id = symtab.get($Identifier.text);
            if (id.theType == Type.INT){
                TextCode.add("\%t" + varCount + "=load i32, i32* \%t" + id.theVar.varIndex);
                tmp += ", i32 " + "\%t" + varCount;
                varCount++;
            }
        }
     )* ')'
        {
            TextCode.add(strCount+1,"@str" + strCount + " = private unnamed_addr constant [" + size + " x i8] c\"" + str +"\"");
            TextCode.add("\%t" + varCount + "= call i32 (i8*, ...) @printf(i8* getelementptr inbounds ([" + size + " x i8], [" + size + " x i8]* @str" + strCount + ", i64 0, i64 0)" + tmp + ")");
            varCount++;
            strCount++;
        }
    ;
    
if_stmt
returns [Label theLabel]
@init {theLabel = new Label();}
    : if_then_stmt [$theLabel] if_else_stmt [$theLabel]
    {
        TextCode.add("br label \%" + $theLabel.Lend);
        TextCode.add($theLabel.Lend + ":");
    }
    ;

       
if_then_stmt [Label theLabel]
    : IF '(' cond_expression ')'
        {
            if($cond_expression.theInfo.theType == Type.BOOL){
                $theLabel.Ltrue=newLabel();
                $theLabel.Lfalse=$theLabel.Lend=newLabel();
                TextCode.add("br i1 \%t" + $cond_expression.theInfo.theVar.varIndex + ", label \%" + $theLabel.Ltrue + ", label \%" + $theLabel.Lend);
                TextCode.add($theLabel.Ltrue + ":");
            }
        }
    block_stmt
    ;


if_else_stmt [Label theLabel]
    : ELSE
        {
            $theLabel.Lend=newLabel();
            TextCode.add("br label \%" + $theLabel.Lend);
            TextCode.add($theLabel.Lfalse + ":");
        }
    block_stmt

    |
    ;

                  
block_stmt: '{' statements '}'
    ;


assign_stmt: Identifier '=' cond_expression
    {
        Info theRHS = $cond_expression.theInfo;
        Info theLHS = symtab.get($Identifier.text); 

        if ((theLHS.theType == Type.INT) &&
            (theRHS.theType == Type.INT)) {		   
            // issue store insruction.
            // Ex: store i32 \%tx, i32* \%ty
            TextCode.add("store i32 \%t" + theRHS.theVar.varIndex + ", i32* \%t" + theLHS.theVar.varIndex);
        } else if ((theLHS.theType == Type.INT) &&
            (theRHS.theType == Type.CONST_INT)) {
            // issue store insruction.
            // Ex: store i32 value, i32* \%ty
            TextCode.add("store i32 " + theRHS.theVar.iValue + ", i32* \%t" + theLHS.theVar.varIndex);				
        }
    }
    ;

           
func_no_return_stmt: Identifier '(' argument ')'
                   ;


argument: arg (',' arg)*
        ;

arg: arith_expression
   | STRING_LITERAL
   ;
           
cond_expression
returns [Info theInfo]
@init {theInfo = new Info();}
    : a = relatExpr {$theInfo=$a.theInfo;}
    ('==' b=relatExpr
        {
            if (($a.theInfo.theType == Type.INT) && ($b.theInfo.theType == Type.INT)) {
                TextCode.add("\%t" + varCount + " = icmp eq i32 \%t" + $a.theInfo.theVar.varIndex + ", \%t" + $b.theInfo.theVar.varIndex);
                //TextCode.add("\%t" + (varCount+1) + " = zext i1 \%t" + varCount + " to i32");
                
                // Update arith_expression's theInfo.
                $theInfo.theType = Type.BOOL;
                $theInfo.theVar.varIndex = varCount;
                varCount ++;
            }
            else if (($a.theInfo.theType == Type.INT) && ($b.theInfo.theType == Type.CONST_INT)) {
                TextCode.add("\%t" + varCount + " = icmp eq i32 \%t" + $a.theInfo.theVar.varIndex + ", " + $b.theInfo.theVar.iValue);
                
                // Update arith_expression's theInfo.
                $theInfo.theType = Type.BOOL;
                $theInfo.theVar.varIndex = varCount;
                varCount ++;
            }
            else if(($a.theInfo.theType == Type.CONST_INT) && ($b.theInfo.theType == Type.INT)){
                TextCode.add("\%t" + varCount + " = icmp eq i32 " + $theInfo.theVar.iValue + ", \%t" + $b.theInfo.theVar.varIndex);
            
                // Update arith_expression's theInfo.
                $theInfo.theType = Type.BOOL;
                $theInfo.theVar.varIndex = varCount;
                varCount ++;
            }
            else if(($a.theInfo.theType == Type.CONST_INT) && ($b.theInfo.theType == Type.CONST_INT)){
                TextCode.add("\%t" + varCount + " = icmp eq i32 " + $theInfo.theVar.iValue + ", " + $b.theInfo.theVar.iValue);
            
                // Update arith_expression's theInfo.
                $theInfo.theType = Type.BOOL;
                $theInfo.theVar.varIndex = varCount;
                varCount ++;
            }
            
        }
    | '!=' c=relatExpr
        {
            if (($a.theInfo.theType == Type.INT) && ($c.theInfo.theType == Type.INT)) {
                TextCode.add("\%t" + varCount + " = icmp ne i32 \%t" + $a.theInfo.theVar.varIndex + ", \%t" + $c.theInfo.theVar.varIndex);
                
                // Update arith_expression's theInfo.
                $theInfo.theType = Type.BOOL;
                $theInfo.theVar.varIndex = varCount;
                varCount ++;
            }
            else if (($a.theInfo.theType == Type.INT) && ($c.theInfo.theType == Type.CONST_INT)) {
                TextCode.add("\%t" + varCount + " = icmp ne i32 \%t" + $a.theInfo.theVar.varIndex + ", " + $c.theInfo.theVar.iValue);
                
                // Update arith_expression's theInfo.
                $theInfo.theType = Type.BOOL;
                $theInfo.theVar.varIndex = varCount;
                varCount ++;
            }
            else if(($a.theInfo.theType == Type.CONST_INT) && ($c.theInfo.theType == Type.INT)){
                TextCode.add("\%t" + varCount + " = icmp ne i32 " + $theInfo.theVar.iValue + ", \%t" + $c.theInfo.theVar.varIndex);
            
                // Update arith_expression's theInfo.
                $theInfo.theType = Type.BOOL;
                $theInfo.theVar.varIndex = varCount;
                varCount ++;
            }
            else if(($a.theInfo.theType == Type.CONST_INT) && ($c.theInfo.theType == Type.CONST_INT)){
                TextCode.add("\%t" + varCount + " = icmp ne i32 " + $theInfo.theVar.iValue + ", " + $c.theInfo.theVar.iValue);
            
                // Update arith_expression's theInfo.
                $theInfo.theType = Type.BOOL;
                $theInfo.theVar.varIndex = varCount;
                varCount ++;
            }
        }
    )*
        { if (TRACEON) System.out.println("equalExpr: relatExpr ((== | !=) relatExpr)*");}
    ;

relatExpr
returns [Info theInfo]
@init {theInfo = new Info();}
    : a = arith_expression {$theInfo=$a.theInfo;}
    ('<' b = arith_expression
        {
            if (($a.theInfo.theType == Type.INT) && ($b.theInfo.theType == Type.INT)) {
                TextCode.add("\%t" + varCount + " = icmp slt i32 \%t" + $a.theInfo.theVar.varIndex + ", \%t" + $b.theInfo.theVar.varIndex);
                
                // Update arith_expression's theInfo.
                $theInfo.theType = Type.BOOL;
                $theInfo.theVar.varIndex = varCount;
                varCount ++;
            }
            else if (($a.theInfo.theType == Type.INT) && ($b.theInfo.theType == Type.CONST_INT)) {
                TextCode.add("\%t" + varCount + " = icmp slt i32 \%t" + $a.theInfo.theVar.varIndex + ", " + $b.theInfo.theVar.iValue);
                
                // Update arith_expression's theInfo.
                $theInfo.theType = Type.BOOL;
                $theInfo.theVar.varIndex = varCount;
                varCount ++;
            }
            else if(($a.theInfo.theType == Type.CONST_INT) && ($b.theInfo.theType == Type.INT)){
                TextCode.add("\%t" + varCount + " = icmp slt i32 " + $theInfo.theVar.iValue + ", \%t" + $b.theInfo.theVar.varIndex);
            
                // Update arith_expression's theInfo.
                $theInfo.theType = Type.BOOL;
                $theInfo.theVar.varIndex = varCount;
                varCount ++;
            }
            else if(($a.theInfo.theType == Type.CONST_INT) && ($b.theInfo.theType == Type.CONST_INT)){
                TextCode.add("\%t" + varCount + " = icmp slt i32 " + $theInfo.theVar.iValue + ", " + $b.theInfo.theVar.iValue);
            
                // Update arith_expression's theInfo.
                $theInfo.theType = Type.BOOL;
                $theInfo.theVar.varIndex = varCount;
                varCount ++;
            }
        }
    |'>' c = arith_expression
        {
            if (($a.theInfo.theType == Type.INT) && ($c.theInfo.theType == Type.INT)) {
                TextCode.add("\%t" + varCount + " = icmp sgt i32 \%t" + $a.theInfo.theVar.varIndex + ", \%t" + $c.theInfo.theVar.varIndex);
                
                // Update arith_expression's theInfo.
                $theInfo.theType = Type.BOOL;
                $theInfo.theVar.varIndex = varCount;
                varCount ++;
            }
            else if (($a.theInfo.theType == Type.INT) && ($c.theInfo.theType == Type.CONST_INT)) {
                TextCode.add("\%t" + varCount + " = icmp sgt i32 \%t" + $a.theInfo.theVar.varIndex + ", " + $c.theInfo.theVar.iValue);
                
                // Update arith_expression's theInfo.
                $theInfo.theType = Type.BOOL;
                $theInfo.theVar.varIndex = varCount;
                varCount ++;
            }
            else if(($a.theInfo.theType == Type.CONST_INT) && ($c.theInfo.theType == Type.INT)){
                TextCode.add("\%t" + varCount + " = icmp sgt i32 " + $theInfo.theVar.iValue + ", \%t" + $c.theInfo.theVar.varIndex);
            
                // Update arith_expression's theInfo.
                $theInfo.theType = Type.BOOL;
                $theInfo.theVar.varIndex = varCount;
                varCount ++;
            }
            else if(($a.theInfo.theType == Type.CONST_INT) && ($c.theInfo.theType == Type.CONST_INT)){
                TextCode.add("\%t" + varCount + " = icmp sgt i32 " + $theInfo.theVar.iValue + ", " + $c.theInfo.theVar.iValue);
            
                // Update arith_expression's theInfo.
                $theInfo.theType = Type.BOOL;
                $theInfo.theVar.varIndex = varCount;
                varCount ++;
            }
        }
    | '<=' d = arith_expression
        {
            if (($a.theInfo.theType == Type.INT) && ($d.theInfo.theType == Type.INT)) {
                TextCode.add("\%t" + varCount + " = icmp sle i32 \%t" + $a.theInfo.theVar.varIndex + ", \%t" + $d.theInfo.theVar.varIndex);
                
                // Update arith_expression's theInfo.
                $theInfo.theType = Type.BOOL;
                $theInfo.theVar.varIndex = varCount;
                varCount ++;
            }
            else if (($a.theInfo.theType == Type.INT) && ($d.theInfo.theType == Type.CONST_INT)) {
                TextCode.add("\%t" + varCount + " = icmp sle i32 \%t" + $a.theInfo.theVar.varIndex + ", " + $d.theInfo.theVar.iValue);
                TextCode.add("\%t" + (varCount+1) + " = zext i1 \%t" + varCount + " to i32");
                
                // Update arith_expression's theInfo.
                $theInfo.theType = Type.BOOL;
                $theInfo.theVar.varIndex = varCount;
                varCount ++;
            }
            else if(($a.theInfo.theType == Type.CONST_INT) && ($d.theInfo.theType == Type.INT)){
                TextCode.add("\%t" + varCount + " = icmp sle i32 " + $theInfo.theVar.iValue + ", \%t" + $d.theInfo.theVar.varIndex);
            
                // Update arith_expression's theInfo.
                $theInfo.theType = Type.BOOL;
                $theInfo.theVar.varIndex = varCount;
                varCount ++;
            }
            else if(($a.theInfo.theType == Type.CONST_INT) && ($d.theInfo.theType == Type.CONST_INT)){
                TextCode.add("\%t" + varCount + " = icmp sle i32 " + $theInfo.theVar.iValue + ", " + $d.theInfo.theVar.iValue);
            
                // Update arith_expression's theInfo.
                $theInfo.theType = Type.BOOL;
                $theInfo.theVar.varIndex = varCount;
                varCount ++;
            }
        }
    | '>=' e = arith_expression
        {
            if (($a.theInfo.theType == Type.INT) && ($e.theInfo.theType == Type.INT)) {
                TextCode.add("\%t" + varCount + " = icmp sge i32 \%t" + $a.theInfo.theVar.varIndex + ", \%t" + $e.theInfo.theVar.varIndex);
                TextCode.add("\%t" + (varCount+1) + " = zext i1 \%t" + varCount + " to i32");
                
                // Update arith_expression's theInfo.
                $theInfo.theType = Type.BOOL;
                $theInfo.theVar.varIndex = varCount;
                varCount ++;
            }
            else if (($a.theInfo.theType == Type.INT) && ($e.theInfo.theType == Type.CONST_INT)) {
                TextCode.add("\%t" + varCount + " = icmp sge i32 \%t" + $a.theInfo.theVar.varIndex + ", " + $e.theInfo.theVar.iValue);
                TextCode.add("\%t" + (varCount+1) + " = zext i1 \%t" + varCount + " to i32");
                
                // Update arith_expression's theInfo.
                $theInfo.theType = Type.BOOL;
                $theInfo.theVar.varIndex = varCount;
                varCount ++;
            }
            else if(($a.theInfo.theType == Type.CONST_INT) && ($e.theInfo.theType == Type.INT)){
                TextCode.add("\%t" + varCount + " = icmp sge i32 " + $theInfo.theVar.iValue + ", \%t" + $e.theInfo.theVar.varIndex);
            
                // Update arith_expression's theInfo.
                $theInfo.theType = Type.BOOL;
                $theInfo.theVar.varIndex = varCount;
                varCount ++;
            }
            else if(($a.theInfo.theType == Type.CONST_INT) && ($e.theInfo.theType == Type.CONST_INT)){
                TextCode.add("\%t" + varCount + " = sge ne i32 " + $theInfo.theVar.iValue + ", " + $e.theInfo.theVar.iValue);
            
                // Update arith_expression's theInfo.
                $theInfo.theType = Type.BOOL;
                $theInfo.theVar.varIndex = varCount;
                varCount ++;
            }
        }
    )*

        { if (TRACEON) System.out.println("relatExpr: arith_expression ((< | > | <= | >=) arith_expression)*");
        }
    ;

arith_expression
returns [Info theInfo]
@init {theInfo = new Info();}
    : a=multExpr { $theInfo=$a.theInfo; }
    ( '+' b=multExpr
    {
        // We need to do type checking first.
        // ...
        
        // code generation.					   
        if (($a.theInfo.theType == Type.INT) &&
            ($b.theInfo.theType == Type.INT)) {
            
            TextCode.add("\%t" + varCount + " = add nsw i32 \%t" + $theInfo.theVar.varIndex + ", \%t" + $b.theInfo.theVar.varIndex);
            // \%x = add nsw i32 \%y, \%z
            // Update arith_expression's theInfo.
            $theInfo.theType = Type.INT;
            $theInfo.theVar.varIndex = varCount;
            varCount ++;
        }
        else if (($a.theInfo.theType == Type.INT) &&
            ($b.theInfo.theType == Type.CONST_INT)) {
            TextCode.add("\%t" + varCount + " = add nsw i32 \%t" + $theInfo.theVar.varIndex + ", " + $b.theInfo.theVar.iValue);
        
            // Update arith_expression's theInfo.
            $theInfo.theType = Type.INT;
            $theInfo.theVar.varIndex = varCount;
            varCount ++;
        }
        else if(($a.theInfo.theType == Type.CONST_INT) && ($b.theInfo.theType == Type.INT)){
            TextCode.add("\%t" + varCount + " = add nsw i32 " + $theInfo.theVar.iValue + ", \%t" + $b.theInfo.theVar.varIndex);
        
            // Update arith_expression's theInfo.
            $theInfo.theType = Type.INT;
            $theInfo.theVar.varIndex = varCount;
            varCount ++;
        }
        else if(($a.theInfo.theType == Type.CONST_INT) && ($b.theInfo.theType == Type.CONST_INT)){
            $theInfo.theType = Type.CONST_INT;
            $theInfo.theVar.iValue = $a.theInfo.theVar.iValue+$b.theInfo.theVar.iValue;
        }
        
    }
    | '-' c=multExpr
        {
            if (($a.theInfo.theType == Type.INT) &&
                ($c.theInfo.theType == Type.INT)) {
                
                TextCode.add("\%t" + varCount + " = sub nsw i32 \%t" + $theInfo.theVar.varIndex + ", \%t" + $c.theInfo.theVar.varIndex);
                
                // Update arith_expression's theInfo.
                $theInfo.theType = Type.INT;
                $theInfo.theVar.varIndex = varCount;
                varCount ++;
            }
            else if (($a.theInfo.theType == Type.INT) &&
                ($c.theInfo.theType == Type.CONST_INT)) {
                TextCode.add("\%t" + varCount + " = sub nsw i32 \%t" + $theInfo.theVar.varIndex + ", " + $c.theInfo.theVar.iValue);
            
                // Update arith_expression's theInfo.
                $theInfo.theType = Type.INT;
                $theInfo.theVar.varIndex = varCount;
                varCount ++;
            }
            else if(($a.theInfo.theType == Type.CONST_INT) && ($c.theInfo.theType == Type.INT)){
                TextCode.add("\%t" + varCount + " = sub nsw i32 " + $theInfo.theVar.iValue + ", \%t" + $c.theInfo.theVar.varIndex);
            
                // Update arith_expression's theInfo.
                $theInfo.theType = Type.INT;
                $theInfo.theVar.varIndex = varCount;
                varCount ++;
            }
            else if(($a.theInfo.theType == Type.CONST_INT) && ($c.theInfo.theType == Type.CONST_INT)){
                $theInfo.theType = Type.CONST_INT;
                $theInfo.theVar.iValue = $a.theInfo.theVar.iValue-$c.theInfo.theVar.iValue;
            }
        }
    )*
    ;

multExpr
returns [Info theInfo]
@init {theInfo = new Info();}
    : a=signExpr { $theInfo=$a.theInfo; }
    ( '*' b=signExpr
        {
            if (($a.theInfo.theType == Type.INT) &&
            ($b.theInfo.theType == Type.INT)) {
            
                TextCode.add("\%t" + varCount + " = mul nsw i32 \%t" + $theInfo.theVar.varIndex + ", \%t" + $b.theInfo.theVar.varIndex);
                
                // Update arith_expression's theInfo.
                $theInfo.theType = Type.INT;
                $theInfo.theVar.varIndex = varCount;
                varCount ++;
            }
            else if (($a.theInfo.theType == Type.INT) &&
                ($b.theInfo.theType == Type.CONST_INT)) {
                TextCode.add("\%t" + varCount + " = mul nsw i32 \%t" + $theInfo.theVar.varIndex + ", " + $b.theInfo.theVar.iValue);
            
                // Update arith_expression's theInfo.
                $theInfo.theType = Type.INT;
                $theInfo.theVar.varIndex = varCount;
                varCount ++;
            }
            else if(($a.theInfo.theType == Type.CONST_INT) && ($b.theInfo.theType == Type.INT)){
                TextCode.add("\%t" + varCount + " = mul nsw i32 " + $theInfo.theVar.iValue + ", \%t" + $b.theInfo.theVar.varIndex);
            
                // Update arith_expression's theInfo.
                $theInfo.theType = Type.INT;
                $theInfo.theVar.varIndex = varCount;
                varCount ++;
            }
            else if(($a.theInfo.theType == Type.CONST_INT) && ($b.theInfo.theType == Type.CONST_INT)){
                $theInfo.theType = Type.CONST_INT;
                $theInfo.theVar.iValue = $a.theInfo.theVar.iValue*$b.theInfo.theVar.iValue;
            }
        }
    | '/' c=signExpr
        {
            if (($a.theInfo.theType == Type.INT) &&
            ($c.theInfo.theType == Type.INT)) {
            
            TextCode.add("\%t" + varCount + " = sdiv i32 \%t" + $theInfo.theVar.varIndex + ", \%t" + $c.theInfo.theVar.varIndex);
            
            // Update arith_expression's theInfo.
            $theInfo.theType = Type.INT;
            $theInfo.theVar.varIndex = varCount;
            varCount ++;
            }
            else if (($a.theInfo.theType == Type.INT) &&
                ($c.theInfo.theType == Type.CONST_INT)) {
                TextCode.add("\%t" + varCount + " = sdiv i32 \%t" + $theInfo.theVar.varIndex + ", " + $c.theInfo.theVar.iValue);
            
                // Update arith_expression's theInfo.
                $theInfo.theType = Type.INT;
                $theInfo.theVar.varIndex = varCount;
                varCount ++;
            }
            else if(($a.theInfo.theType == Type.CONST_INT) && ($c.theInfo.theType == Type.INT)){
                TextCode.add("\%t" + varCount + " = sdiv i32 " + $theInfo.theVar.iValue + ", \%t" + $c.theInfo.theVar.varIndex);
            
                // Update arith_expression's theInfo.
                $theInfo.theType = Type.INT;
                $theInfo.theVar.varIndex = varCount;
                varCount ++;
            }
            else if(($a.theInfo.theType == Type.CONST_INT) && ($c.theInfo.theType == Type.CONST_INT)){
                $theInfo.theType = Type.CONST_INT;
                $theInfo.theVar.iValue = $a.theInfo.theVar.iValue/$c.theInfo.theVar.iValue;
            }
        }
    | '%' d=signExpr
        {
            if (($a.theInfo.theType == Type.INT) && ($d.theInfo.theType == Type.INT)) {
            
            TextCode.add("\%t" + varCount + " = srem i32 \%t" + $theInfo.theVar.varIndex + ", \%t" + $d.theInfo.theVar.varIndex);
            
            // Update arith_expression's theInfo.
            $theInfo.theType = Type.INT;
            $theInfo.theVar.varIndex = varCount;
            varCount ++;
            }
            else if (($a.theInfo.theType == Type.INT) && ($d.theInfo.theType == Type.CONST_INT)) {
                TextCode.add("\%t" + varCount + " = srem i32 \%t" + $theInfo.theVar.varIndex + ", " + $d.theInfo.theVar.iValue);
            
                // Update arith_expression's theInfo.
                $theInfo.theType = Type.INT;
                $theInfo.theVar.varIndex = varCount;
                varCount ++;
            }
            else if(($a.theInfo.theType == Type.CONST_INT) && ($d.theInfo.theType == Type.INT)){
                TextCode.add("\%t" + varCount + " = srem i32 " + $theInfo.theVar.iValue + ", \%t" + $d.theInfo.theVar.varIndex);
            
                // Update arith_expression's theInfo.
                $theInfo.theType = Type.INT;
                $theInfo.theVar.varIndex = varCount;
                varCount ++;
            }
            else if(($a.theInfo.theType == Type.CONST_INT) && ($d.theInfo.theType == Type.CONST_INT)){
                $theInfo.theType = Type.CONST_INT;
                $theInfo.theVar.iValue = $a.theInfo.theVar.iValue \% $d.theInfo.theVar.iValue;
            }
        }
    | '|' e=signExpr
        {
            if (($a.theInfo.theType == Type.INT) && ($e.theInfo.theType == Type.INT)) {
            
            TextCode.add("\%t" + varCount + " = or i32 \%t" + $theInfo.theVar.varIndex + ", \%t" + $e.theInfo.theVar.varIndex);
            
            // Update arith_expression's theInfo.
            $theInfo.theType = Type.INT;
            $theInfo.theVar.varIndex = varCount;
            varCount ++;
            }
            else if (($a.theInfo.theType == Type.INT) && ($e.theInfo.theType == Type.CONST_INT)) {
                TextCode.add("\%t" + varCount + " = or i32 \%t" + $theInfo.theVar.varIndex + ", " + $e.theInfo.theVar.iValue);
            
                // Update arith_expression's theInfo.
                $theInfo.theType = Type.INT;
                $theInfo.theVar.varIndex = varCount;
                varCount ++;
            }
            else if(($a.theInfo.theType == Type.CONST_INT) && ($e.theInfo.theType == Type.INT)){
                TextCode.add("\%t" + varCount + " = or i32 " + $theInfo.theVar.iValue + ", \%t" + $e.theInfo.theVar.varIndex);
            
                // Update arith_expression's theInfo.
                $theInfo.theType = Type.INT;
                $theInfo.theVar.varIndex = varCount;
                varCount ++;
            }
            else if(($a.theInfo.theType == Type.CONST_INT) && ($e.theInfo.theType == Type.CONST_INT)){
                $theInfo.theType = Type.CONST_INT;
                $theInfo.theVar.iValue = $a.theInfo.theVar.iValue | $e.theInfo.theVar.iValue;
            }
        }
    | '&' f=signExpr
        {
            if (($a.theInfo.theType == Type.INT) && ($f.theInfo.theType == Type.INT)) {
            
            TextCode.add("\%t" + varCount + " = and i32 \%t" + $theInfo.theVar.varIndex + ", \%t" + $f.theInfo.theVar.varIndex);
            
            // Update arith_expression's theInfo.
            $theInfo.theType = Type.INT;
            $theInfo.theVar.varIndex = varCount;
            varCount ++;
            }
            else if (($a.theInfo.theType == Type.INT) && ($f.theInfo.theType == Type.CONST_INT)) {
                TextCode.add("\%t" + varCount + " = and i32 \%t" + $theInfo.theVar.varIndex + ", " + $f.theInfo.theVar.iValue);
            
                // Update arith_expression's theInfo.
                $theInfo.theType = Type.INT;
                $theInfo.theVar.varIndex = varCount;
                varCount ++;
            }
            else if(($a.theInfo.theType == Type.CONST_INT) && ($f.theInfo.theType == Type.INT)){
                TextCode.add("\%t" + varCount + " = and i32 " + $theInfo.theVar.iValue + ", \%t" + $f.theInfo.theVar.varIndex);
            
                // Update arith_expression's theInfo.
                $theInfo.theType = Type.INT;
                $theInfo.theVar.varIndex = varCount;
                varCount ++;
            }
            else if(($a.theInfo.theType == Type.CONST_INT) && ($f.theInfo.theType == Type.CONST_INT)){
                $theInfo.theType = Type.CONST_INT;
                $theInfo.theVar.iValue = $a.theInfo.theVar.iValue & $f.theInfo.theVar.iValue;
            }
        }
    )*
    ;

signExpr
returns [Info theInfo]
@init {theInfo = new Info();}
    : a=primaryExpr {$theInfo=$a.theInfo; } 
    | '-' b=primaryExpr 
        {
            $theInfo=$b.theInfo;
            if ($b.theInfo.theType == Type.INT){
                
                TextCode.add("\%t" + varCount + " = sub nsw i32 0, \%t" + $b.theInfo.theVar.varIndex);
                
                // Update arith_expression's theInfo.
                $theInfo.theType = Type.INT;
                $theInfo.theVar.varIndex = varCount;
                varCount ++;
            }
            else if ($b.theInfo.theType == Type.CONST_INT) {
                TextCode.add("\%t" + varCount + " = sub nsw i32 0, " + $b.theInfo.theVar.iValue);

                // Update arith_expression's theInfo.
                $theInfo.theType = Type.INT;
                $theInfo.theVar.varIndex = varCount;
                varCount ++;
            }
        }
    ;
          
primaryExpr
returns [Info theInfo]
@init {theInfo = new Info();}
    : Integer_constant
    {
        $theInfo.theType = Type.CONST_INT;
        $theInfo.theVar.iValue = Integer.parseInt($Integer_constant.text);
    }

    | Floating_point_constant
    | Identifier
    {
        // get type information from symtab.
        Type the_type = symtab.get($Identifier.text).theType;
        $theInfo.theType = the_type;

        // get variable index from symtab.
        int vIndex = symtab.get($Identifier.text).theVar.varIndex;
        
        switch (the_type) {
        case INT: 
            // get a new temporary variable and
            // load the variable into the temporary variable.
            
            // Ex: \%tx = load i32, i32* \%ty.
            TextCode.add("\%t" + varCount + "=load i32, i32* \%t" + vIndex);
            
            // Now, Identifier's value is at the temporary variable \%t[varCount].
            // Therefore, update it.
            $theInfo.theVar.varIndex = varCount;
            varCount ++;
            break;
        case FLOAT:
            break;
        case CHAR:
            break;
    
        }
    }

    | '&' Identifier
    | '(' arith_expression ')'
        {theInfo=$arith_expression.theInfo;}
    
    ;

           
/* description of the tokens */
FLOAT:'float';
INT:'int';
CHAR: 'char';

MAIN: 'main';
VOID: 'void';
IF: 'if';
ELSE: 'else';
FOR: 'for';
WHILE: 'while';
PRINTF: 'printf';

//RelationOP: '>' |'>=' | '<' | '<=' | '==' | '!=';

Identifier:('a'..'z'|'A'..'Z'|'_') ('a'..'z'|'A'..'Z'|'0'..'9'|'_')*;
Integer_constant:'0'..'9'+;
Floating_point_constant:'0'..'9'+ '.' '0'..'9'+;

STRING_LITERAL
    :  '"' ( EscapeSequence | ~('\\'|'"') )* '"'
    ;
STRING   : '"' (options{greedy=false;}: .)* '"';

WS:( ' ' | '\t' | '\r' | '\n' ) {$channel=HIDDEN;};
COMMENT1 : '//'(.)*'\n' {$channel=HIDDEN;};
COMMENT2 : '/*' (options{greedy=false;}: .)* '*/'{$channel=HIDDEN;};


fragment
EscapeSequence
    :   '\\' ('b'|'t'|'n'|'f'|'r'|'\"'|'\''|'\\')
    ;