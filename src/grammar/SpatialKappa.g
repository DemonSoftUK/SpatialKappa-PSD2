 grammar SpatialKappa;

options {
  language     = Java;
  output       = AST;
  ASTLabelType = CommonTree;
}

tokens {
  OBSERVATION;
  VARIABLE;
  INIT;
  AGENTS;
  AGENT;
  INTERFACE;
  STATE;
  LINK;
  OCCUPIED;
  ANY;
  LHS;
  RHS;
  RATE;
  PERTURBATION;
  COMPARTMENT;
  DIMENSION;
  COMPARTMENT_LINK;
  LOCATION;
  CELL_INDEX_EXPR;
  INDEX;
  TRANSPORT;
  TRANSFORM;
  ID;
  LABEL;
  VAR_EXPR;
  VAR_INFINITY;
  PLOT;
  CONDITION;
  EFFECT;
  UNTIL;
  SNAPSHOT;
  STOP;
  ADD;
  REMOVE;
  SET;
  BOOL_EXPR;
  AND;
  OR;
  NOT;
  TRUE;
  FALSE;
  TIME;
  EVENTS;
  TARGET;
  LOG;
  MODULUS;
  PI;
  SIN;
  COS;
  TAN;
  SQRT;
  EXP;
}

@header        {package org.demonsoft.spatialkappa.parser;}
@lexer::header {package org.demonsoft.spatialkappa.parser;}

prog
  :
  (line)+
  ;

line
  :
  ruleExpr NEWLINE!
  | COMMENT!
  | compartmentExpr NEWLINE!
  | compartmentLinkExpr NEWLINE!
  | transportExpr NEWLINE!
  | initExpr NEWLINE!
  | plotExpr NEWLINE!
  | obsExpr NEWLINE!
  | varExpr NEWLINE!
  | modExpr NEWLINE!
  | NEWLINE!
  ;

ruleExpr
  :
  label? transformExpr transformKineticExpr 
    -> 
      ^(TRANSFORM transformExpr transformKineticExpr label?)
  | label locationExpr transformExpr transformKineticExpr 
    -> 
      ^(TRANSFORM transformExpr transformKineticExpr label locationExpr)
  ;

transformExpr
  :
  a=agentGroup transformTransition b=agentGroup
    ->
      ^(
        transformTransition
        ^(LHS $a)
        ^(RHS $b)
       )
  | agentGroup transformTransition
    ->
      ^(
        transformTransition
        ^(LHS agentGroup)
        ^(RHS)
       )
  | transformTransition agentGroup
    ->
      ^(
        transformTransition
        ^(LHS)
        ^(RHS agentGroup)
       )
  | transformTransition
    ->
  ;

agentGroup
  :
  agent (',' agent)*
    ->
      ^(AGENTS agent+)
  ;

agent
  :
  id '(' (iface (',' iface)*)? ')'
    ->
      ^(AGENT id iface*)
  ;

iface
  :
  id stateExpr? linkExpr?
    ->
      ^(INTERFACE id stateExpr? linkExpr?)
  ;

stateExpr
  :
  '~' id
    ->
      ^(STATE id)
  ;

linkExpr
  :
  '!' INT
    ->
      ^(LINK INT)
  | '!' '_'
    ->
      ^(LINK OCCUPIED)
  | '?'
    ->
      ^(LINK ANY)
  ;

transformKineticExpr
  :
  '@' a=varAlgebraExpr (',' b=varAlgebraExpr)?
    ->
      ^(RATE $a ($b)?)
  ;

transportKineticExpr
  :
  '@' varAlgebraExpr
    ->
      ^(RATE varAlgebraExpr)
  ;

initExpr
options {backtrack=true;}
  :
  '%init:' locationExpr? INT '(' agentGroup ')'
    ->
      ^(INIT agentGroup INT locationExpr?)
  | '%init:' locationExpr? label '(' agentGroup ')'
    ->
      ^(INIT agentGroup label locationExpr?)
  ;

compartmentExpr
  :
  '%compartment:' label ('[' INT ']')*
    ->
      ^(COMPARTMENT label ^(DIMENSION INT)*)
  ;

compartmentLinkExpr
  :
  '%link:' linkName=label sourceCompartment=locationExpr transportTransition targetCompartment=locationExpr
    ->
      ^(COMPARTMENT_LINK $linkName $sourceCompartment transportTransition $targetCompartment)
  ;

transportExpr
  :
  '%transport:' (transportName=label)? linkName=label (agentGroup)? transportKineticExpr
    ->
      ^(TRANSPORT $linkName agentGroup? transportKineticExpr $transportName?)
  ;

locationExpr
  :
  sourceCompartment=label compartmentIndexExpr*
    ->
      ^(LOCATION $sourceCompartment compartmentIndexExpr*)
  ;

compartmentIndexExpr
  :
  '[' cellIndexExpr ']'
    ->
      ^(INDEX cellIndexExpr)
  ;

plotExpr
  :
  '%plot:' label
    ->
      ^(PLOT label)
  ;

obsExpr
  :
  '%obs:' label? agentGroup
    ->
      ^(OBSERVATION agentGroup label?)
  | '%obs:' label locationExpr agentGroup
    ->
      ^(OBSERVATION agentGroup label locationExpr)
  ;

varExpr
options {backtrack=true;}
  :
  '%var:' label agentGroup
    ->
      ^(VARIABLE agentGroup label)
  |
  '%var:' label varAlgebraExpr
    ->
      ^(VARIABLE varAlgebraExpr label)
  ;

varAlgebraExpr
options {backtrack=true;}
  :
  (a=varAlgebraMultExpr -> $a) (op=operator_add b=varAlgebraMultExpr -> ^(VAR_EXPR $op $varAlgebraExpr $b) )*
  ;
  
varAlgebraMultExpr
options {backtrack=true;}
  :
  (a=varAlgebraExpExpr -> $a) (op=operator_mult b=varAlgebraExpExpr -> ^(VAR_EXPR $op $varAlgebraMultExpr $b) )*
  ;
  
varAlgebraExpExpr
options {backtrack=true;}
  :
  a=varAlgebraAtom operator_exp b=varAlgebraExpExpr
    ->
      ^(VAR_EXPR operator_exp $a $b)
  | a=varAlgebraAtom
    ->
      $a
  ;
  
varAlgebraAtom
options {backtrack=true;}
  :
  '(' varAlgebraExpr ')'
    ->
      varAlgebraExpr
  | number
    ->
      ^(VAR_EXPR number)
  | label
    ->
      ^(VAR_EXPR label)
  | '[' 'inf' ']'
    ->
      ^(VAR_EXPR VAR_INFINITY)
  | '[' 'pi' ']'
    ->
      ^(VAR_EXPR PI)
  | '[' 'T' ']'
    ->
      ^(VAR_EXPR TIME)
  | '[' 'E' ']'
    ->
      ^(VAR_EXPR EVENTS)
  | operator_unary varAlgebraAtom
    ->
      ^(VAR_EXPR operator_unary varAlgebraAtom)
  | operator_binary_prefix a=varAlgebraAtom b=varAlgebraAtom
    ->
      ^(VAR_EXPR operator_binary_prefix $a $b)
  ;
  
modExpr
  :
  '%mod:' booleanExpression 'do' effect untilExpression?
    ->
      ^(PERTURBATION ^(CONDITION booleanExpression) effect untilExpression?)
  ;
  

booleanExpression
options {backtrack=true;}
  :
  (a=booleanAtom -> $a) (op=booleanOperator b=booleanAtom -> ^(BOOL_EXPR $op $booleanExpression $b) )*
  ;
  
booleanOperator
  :
  '&&' -> AND
  | '||' -> OR
  ;

relationalOperator
  :
  '<' | '>' | '='
  ;

  
booleanAtom
options {backtrack=true;}
  :
  '(' booleanExpression ')'
    ->
      booleanExpression
  | '[' 'true' ']'
    ->
      ^(BOOL_EXPR TRUE)
  | '[' 'false' ']'
    ->
      ^(BOOL_EXPR FALSE)
  | '[' 'not' ']' booleanAtom
    ->
      ^(BOOL_EXPR NOT booleanAtom)
  | a=varAlgebraExpr relationalOperator b=varAlgebraExpr
    ->
      ^(BOOL_EXPR relationalOperator $a $b)
  ;

effect
  :
  '$SNAPSHOT'
    ->
      ^(EFFECT SNAPSHOT)
  | '$STOP'
    ->
      ^(EFFECT STOP)
  | '$ADD' varAlgebraExpr agentGroup
    ->
      ^(EFFECT ADD varAlgebraExpr agentGroup)
  | '$DEL' varAlgebraExpr agentGroup
    ->
      ^(EFFECT REMOVE varAlgebraExpr agentGroup)
  | label ':=' varAlgebraExpr
    ->
      ^(EFFECT SET ^(TARGET label) varAlgebraExpr)
  ;
  
untilExpression
  :
  'until' booleanExpression
    ->
      ^(UNTIL booleanExpression)
  ;
  
cellIndexExpr
options {backtrack=true;}
  :
  a=cellIndexAtom operator_cell_index b=cellIndexAtom
    ->
      ^(CELL_INDEX_EXPR operator_cell_index $a $b)
  | a=cellIndexAtom
    ->
      $a
  ;
  
cellIndexAtom
options {backtrack=true;}
  :
  '(' cellIndexExpr ')'
    ->
      cellIndexExpr
  | INT
    ->
      ^(CELL_INDEX_EXPR INT)
  | label
    ->
      ^(CELL_INDEX_EXPR label)
  ;
  
id
options {backtrack=true;}
  :
    ( ID_FRAGMENT | INT ) ( ID_FRAGMENT | INT | '_' | '-' )*
   ->
    {new CommonTree(new CommonToken(ID,$id.text.toString()))} // Avoid lexing as mutiple tokens
  ;

label
  :
  LABEL
   ->
    {new CommonTree(new CommonToken(LABEL, $label.text.substring(1, $label.text.length() - 1)))}
  ;

number
  :
  (
    INT
    | FLOAT
  )
  ;
  
operator_cell_index
  :
  '+'
  | '*'
  | '-'
  | '/'
  | '%'
  | '^'
  ;

operator_exp
  :
  | '^'
  ;

operator_unary
  :
  '[' 'log' ']' -> LOG
  | '[' 'sin' ']' -> SIN
  | '[' 'cos' ']' -> COS
  | '[' 'tan' ']' -> TAN
  | '[' 'sqrt' ']' -> SQRT
  | '[' 'exp' ']' -> EXP
  ;

operator_binary_prefix
  :
  '[' 'mod' ']' -> MODULUS
  ;

operator_mult
  :
  '*'
  | '/'
  ;

operator_add
  :
  '+'
  | '-'
  ;

transformTransition
  :
  ( 
    FORWARD_TRANSITION
    | EQUILIBRIUM_TRANSITION
  )
  ;

transportTransition
  :
  ( 
    FORWARD_TRANSITION
    | BACKWARD_TRANSITION
    | EQUILIBRIUM_TRANSITION
  )
  ;

EQUILIBRIUM_TRANSITION
  :
  '<->'
  ;

FORWARD_TRANSITION
  :
  '->'
  ;

BACKWARD_TRANSITION
  :
  '<-'
  ;

INT
  :
  NUMERIC
  ;

FLOAT
    :   NUMERIC '.' NUMERIC EXPONENT?
    |   '.' NUMERIC EXPONENT?
    |   NUMERIC EXPONENT
    ;

ID_FRAGMENT
  :
  ALPHANUMERIC
  ;

fragment
ALPHANUMERIC
  :
  (
    NUMERIC
    | 'a'..'z'
    | 'A'..'Z'
  )+
  ;

fragment
NUMERIC
  :
  ('0'..'9')+
  ;
  
fragment
EXPONENT
  : ('e'|'E') ('+'|'-')? NUMERIC
  ;

LABEL
  :
  '\'' .* '\''
  ;

COMMENT
  :
  '#'
  ~(
    '\n'
    | '\r'
   )*
  NEWLINE {$channel=HIDDEN;}
  ;

NEWLINE
  :
  '\r'? '\n'
  | '\r'
  ;

WS
  :
  (
    ' '
    | '\t'
  )+
  {$channel=HIDDEN;}
  ;