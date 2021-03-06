; [ This translation created 10-Feb-83 by Version 4.3 ]

	.RADIX  8		; To be safe

CSEG	SEGMENT PUBLIC 'CODESG' 
	ASSUME  CS:CSEG

INCLUDE	OEM.H

	TITLE   BIPRTU  BASIC Interpreter PRINT USING Driver/WHG

	.RADIX	10

TRSHHC=0
NECPPC=0

	SUBTTL  PRINT USING DRIVER
;
; COME HERE AFTER THE "USING" CLAUSE IN A PRINT STATEMENT
; IS RECOGNIZED. THE IDEA IS TO SCAN THE USING STRING UNTIL
; THE VALUE LIST IS EXHAUSTED, FINDING STRING AND NUMERIC
; FIELDS TO PRINT VALUES OUT OF THE LIST IN,
; AND JUST OUTPUTING ANY CHARACTERS THAT AREN'T PART OF
; A PRINT FIELD.
;
DSEG	SEGMENT PUBLIC 'DATASG'		; Data segment externs
	ASSUME DS:DSEG
	EXTRN	FACLO:WORD

	EXTRN	USFLG:WORD
DSEG	ENDS

				; Code segment ( terminated by END at bottom of file )

	EXTRN	CHRGTR:NEAR,SYNCHR:NEAR
	EXTRN	CHKSTR:NEAR,CRDO:NEAR,FCERR:NEAR,FRETM2:NEAR,FRMCHK:NEAR
	EXTRN	FRMEVL:NEAR
	EXTRN	OUTDO:NEAR,PUFOUT:NEAR,SNERR:NEAR,STROUT:NEAR,STRPRT:NEAR
	EXTRN	LEFTUS:NEAR
	PUBLIC	PRINUS
	CSTRNG=134O
	CURNCY=44O		;USE DOLLAR SIGN AS DEFAULT

PRINUS:	CALL	FRMCHK		;EVALUATE THE "USING" STRING
	CALL	CHKSTR		;MAKE SURE IT IS A STRING
	CALL	SYNCHR
	DB	OFFSET 73O	;MUST BE DELIMITED BY A SEMI-COLON
	XCHG	BX,DX		;[D,E]=TEXT POINTER
	MOV	BX,FACLO	;GET POINTER TO "USING" STRING DESCRIPTOR
	JMP	SHORT INIUS	;DONT POP OFF OR LOOK AT USFLG
REUSST:	MOV	AL,BYTE PTR USFLG	;DID WE PRINT OUT A VALUE LAST SCAN?
	OR	AL,AL		;SET CC'S
	JZ	SHORT FCERR3	;NO, GIVE ERROR
	POP	DX		;[D,E]=POINTER TO "USING" STRING DESCRIPTOR
	XCHG	BX,DX		;[D,E]=TEXT POINTER
INIUS:	PUSH	BX		;SAVE THE POINTER TO "USING" STRING DESCRIPTOR
	XOR	AL,AL		;INITIALLY INDICATE THERE ARE MORE
				;VALUES IN THE VALUE LIST
	MOV	BYTE PTR USFLG,AL	;RESET THE FLAG THAT SAYS VALUES PRINTED
	INC	AL		;TURN THE ZERO FLAG OFF
				;TO INDICATE THE VALUE LIST HASN'T ENDED
	PUSHF			;SAVE FLAG INDICATING WHETHER THE VALUE
				;LIST HAS ENDED
	PUSH	DX		;SAVE THE TEXT POINTER INTO THE VALUE LIST
	MOV	CH,BYTE PTR [BX]	;[B]=LENGTH OF THE "USING" STRING
	INC	CH		;Is the using string null?
	DEC	CH
FCERR3:	JNZ	SHORT ??L000
	JMP	FCERR		;IF SO, "ILLEGAL FUNCTION CALL"
??L000:
	INC	BX		;[H,L]=POINTER AT THE "USING" STRING'S
	MOV	BX,[BX]		;DATA
	JMP	SHORT PRCCHR	;GO INTO THE LOOP TO SCAN
				;THE "USING" STRING
				;NECPPC does not have string formatter
				; because of ROM space
BGSTRF:	MOV	DL,CH		;SAVE THE "USING" STRING CHARACTER COUNT
	PUSH	BX		;SAVE THE POINTER INTO THE "USING" STRING
	MOV	CL,LOW 2	;THE \\ STRING FIELD HAS 2 PLUS
				;NUMBER OF ENCLOSED SPACES WIDTH
LPSTRF:	MOV	AL,BYTE PTR [BX]	;GET THE NEXT CHARACTER
	INC	BX		;ADVANCE THE POINTER AT THE "USING" STRING
				;DATA
	CMP	AL,LOW OFFSET CSTRNG	;THE FIELD TERMINATOR?
	JNZ	SHORT ??L001
	JMP	ISSTRF		;GO EVALUATE A STRING AND PRINT
??L001:
	CMP	AL,LOW " "	;A FIELD EXTENDER?
	JNZ	SHORT NOSTRF	;IF NOT, ITS NOT A STRING FIELD
	INC	CL		;INCREMENT THE FIELD WIDTH
				;SEE IF THERE ARE MORE CHARACTERS
	DEC	CH
	JNZ	SHORT LPSTRF	;KEEP SCANNING FOR THE FIELD TERMINATOR
;
; SINCE  STRING FIELD WASN'T FOUND, THE "USING" STRING 
; CHARACTER COUNT AND THE POINTER INTO IT'S DATA MUST
; BE RESTORED AND THE "\" PRINTED
;
NOSTRF:	POP	BX		;RESTORE THE POINTER INTO "USING" STRING'S DATA
	MOV	CH,DL		;RESTORE THE "USING" STRING CHARACTER COUNT
	MOV	AL,LOW OFFSET CSTRNG	;RESTORE THE CHARACTER
;
; HERE TO PRINT THE CHARACTER IN [A] SINCE IT WASN'T PART OF ANY FIELD
;
NEWUCH:	CALL	PLSPRT		;IF A "+" CAME BEFORE THIS CHARACTER
				;MAKE SURE IT GETS PRINTED
	CALL	OUTDO		;PRINT THE CHARACTER THAT WASN'T
				;PART OF A FIELD



PRCCHR:	XOR	AL,AL		;SET [D,E]=0 SO IF WE DISPATCH
	MOV	DL,AL		;SOME FLAGS ARE ALREADY ZEROED
	MOV	DH,AL		;DON'T PRINT "+" TWICE
PLSFIN:	CALL	PLSPRT		;ALLOW FOR MULTIPLE PLUSES
				;IN A ROW
	MOV	DH,AL		;SET "+" FLAG
	MOV	AL,BYTE PTR [BX]	;GET A NEW CHARACTER
	INC	BX
	CMP	AL,LOW "!"	;CHECK FOR A SINGLE CHARACTER
	JNZ	SHORT ??L002
	JMP	SMSTRF		;STRING FIELD
??L002:
	CMP	AL,LOW "#"	;CHECK FOR THE START OF A NUMERIC FIELD 
	JZ	SHORT NUMNUM	;GO SCAN IT
	CMP	AL,LOW "&"	;SEE IF ITS A VARIABLE LENGTH STRING FIELD
	JNZ	SHORT ??L003
	JMP	VARSTR		;GO PRINT ENTIRE STRING
??L003:
	DEC	CH		;ALL THE OTHER POSSIBILITIES
				;REQUIRE AT LEAST 2 CHARACTERS
	JNZ	SHORT ??L004
	JMP	REUSIN		;IF THE VALUE LIST IS NOT EXHAUSTED
??L004:
				;GO REUSE "USING" STRING
	CMP	AL,LOW "+"	;A LEADING "+" ?
	MOV	AL,LOW 8	;SETUP [D] WITH THE PLUS-FLAG ON IN
	JZ	SHORT PLSFIN	;CASE A NUMERIC FIELD STARTS
	DEC	BX		;POINTER HAS ALREADY BEEN INCREMENTED
	MOV	AL,BYTE PTR [BX]	;GET BACK THE CURRENT CHARACTER
	INC	BX		;REINCREMENT THE POINTER
	CMP	AL,LOW "."	;NUMERIC FIELD WITH TRAILING DIGITS
	JZ	SHORT DOTNUM	;IF SO GO SCAN WITH [E]=
				;NUMBER OF DIGITS BEFORE THE "."=0
	CMP	AL,LOW "_"	;CHECK FOR LITERAL CHARACTER DECLARATION
	JNZ	SHORT ??L005
	JMP	LITCHR
??L005:
	CMP	AL,LOW OFFSET CSTRNG	;CHECK FOR A BIG STRING FIELD STARTER
	JZ	SHORT BGSTRF	;GO SEE IF IT REALLY IS A STRING FIELD
	CMP	AL,BYTE PTR [BX]	;SEE IF THE NEXT CHARACTER MATCHES THE
				;CURRENT ONE
	JNZ	SHORT NEWUCH	;IF NOT, CAN'T HAVE $$ OR ** SO ALL THE
				;POSSIBILITIES ARE EXHAUSTED
	CMP	AL,LOW OFFSET CURNCY	;IS IT $$ ?
	JZ	SHORT DOLRNM	;GO SET UP THE FLAG BIT
	CMP	AL,LOW "*"	;IS IT ** ?
	JNZ	SHORT NEWUCH	;IF NOT, ITS NOT PART
				;OF A FIELD SINCE ALL THE POSSIBILITIES
				;HAVE BEEN TRIED
	INC	BX		;CHECK FOR $
	MOV	AL,CH		;SEE IF THE "USING" STRING IS LONG
	CMP	AL,LOW 2	;ENOUGH FOR THE SPECIAL CASE OF
	JB	SHORT NOTSPC	; **$
	MOV	AL,BYTE PTR [BX]
	CMP	AL,LOW OFFSET CURNCY	;IS THE NEXT CHARACTER $ ?
NOTSPC:	MOV	AL,LOW 32	;SET THE ASTERISK BIT
	JNZ	SHORT SPCNUM	;IF IT NOT THE SPECIAL CASE, DON'T
				;SET THE DOLLAR SIGN FLAG
	DEC	CH		;DECREMENT THE "USING" STRING CHARACTER COUNT
				;TO TAKE THE $ INTO CONSIDERATION
	INC	DL		;INCREMENT THE FIELD WIDTH FOR THE
				;FLOATING DOLLAR SIGN
	DB	276O	; SKIP	;"CPI" OVER THE NEXT BYTE
				;MVI SI,  IN 8086
DOLRNM:	XOR	AL,AL		;CLEAR [A]
	ADD	AL,LOW 16	;SET BIT FOR FLOATING DOLLAR SIGN FLAG
	INC	BX		;POINT BEYOND THE SPECIAL CHARACTERS
SPCNUM:	INC	DL		;SINCE TWO CHARACTERS SPECIFY
				;THE FIELD SIZE, INITIALIZE [E]=1
	ADD	AL,DH		;PUT NEW FLAG BITS IN [A]
	MOV	DH,AL		;INTO [D]. THE PLUS FLAG MAY HAVE
				;ALREADY BEEN SET
NUMNUM:	INC	DL		;INCREMENT THE NUMBER OF DIGITS BEFORE
				;THE DECIMAL POINT
	MOV	CL,LOW 0	;SET THE NUMBER OF DIGITS AFTER
				;THE DECIMAL POINT = 0
	DEC	CH		;SEE IF THERE ARE MORE CHARACTERS
	JZ	SHORT ENDNUS	;IF NOT, WE ARE DONE SCANNING THIS
				;NUMERIC FIELD
	MOV	AL,BYTE PTR [BX]	;GET THE NEW CHARACTER
	INC	BX		;ADVANCE THE POINTER AT THE "USING" STRING DATA
	CMP	AL,LOW "."	;DO WE HAVE TRAILING DIGITS?
	JZ	SHORT AFTDOT	;IF SO, USE SPECIAL SCAN LOOP
	CMP	AL,LOW "#"	;MORE LEADING DIGITS ?
	JZ	SHORT NUMNUM	;INCREMENT THE COUNT AND KEEP SCANNING
	CMP	AL,LOW 54O	;DOES HE WANT A COMMA
				;EVERY THREE DIGITS?
	JNZ	SHORT FINNUM	;NO MORE LEADING DIGITS, CHECK FOR ^^^
	MOV	AL,DH		;TURN ON THE COMMA BIT
	OR	AL,LOW 64
	MOV	DH,AL
	JMP	SHORT NUMNUM	;GO SCAN SOME MORE
;
; HERE WHEN A "." IS SEEN IN THE "USING" STRING
; IT STARTS A NUMERIC FIELD IF AND ONLY IF
; IT IS FOLLOWED BY A "#"
;
DOTNUM:	MOV	AL,BYTE PTR [BX]	;GET THE CHARACTER THAT FOLLOWS
	CMP	AL,LOW "#"	;IS THIS A NUMERIC FIELD?
	MOV	AL,LOW "."	;IF NOT, GO BACK AND PRINT "."
	JZ	SHORT ??L006
	JMP	NEWUCH
??L006:
	MOV	CL,LOW 1	;INITIALIZE THE NUMBER OF
				;DIGITS AFTER THE DECIMAL POINT
	INC	BX
AFTDOT:	INC	CL		;INCREMENT THE NUMBER OF DIGITS
				;AFTER THE DECIMAL POINT
	DEC	CH		;SEE IF THE "USING" STRING HAS MORE
	JZ	SHORT ENDNUS	;CHARACTERS, AND IF NOT, STOP SCANNING
	MOV	AL,BYTE PTR [BX]	;GET THE NEXT CHARACTER
	INC	BX
	CMP	AL,LOW "#"	;MORE DIGITS AFTER THE DECIMAL POINT?
	JZ	SHORT AFTDOT	;IF SO, INCREMENT THE COUNT AND KEEP
				;SCANNING
;
; CHECK FOR THE "^^^^" THAT INDICATES SCIENTIFIC NOTATION
;
FINNUM:	PUSH	DX		;SAVE [D]=FLAGS AND [E]=LEADING DIGITS
	MOV	DX,OFFSET NOTSCI	;PLACE TO GO IF ITS NOT SCIENTIFIC
	PUSH	DX		;NOTATION
	MOV	DH,BH		;REMEMBER [H,L] IN CASE
	MOV	DL,BL		;ITS NOT SCIENTIFIC NOTATION
	CMP	AL,LOW "^"	;IS THE FIRST CHARACTER "^" ?
	JZ	SHORT $+3
	RET
	CMP	AL,BYTE PTR [BX]	;IS THE SECOND CHARACTER "^" ?
	JZ	SHORT $+3
	RET
	INC	BX
	CMP	AL,BYTE PTR [BX]	;IS THE THIRD CHARACTER "^" ?
	JZ	SHORT $+3
	RET
	INC	BX
	CMP	AL,BYTE PTR [BX]	;IS THE FOURTH CHARACTER "^" ?
	JZ	SHORT $+3
	RET
	INC	BX
	MOV	AL,CH		;WERE THERE ENOUGH CHARACTERS FOR "^^^^"
	SUB	AL,LOW 4	;IT TAKES FOUR
	JNB	SHORT $+3
	RET
	POP	DX		;POP OFF THE NOTSCI RETURN ADDRESS
	POP	DX		;GET BACK [D]=FLAGS [E]=LEADING DIGITS
	MOV	CH,AL		;MAKE [B]=NEW CHARACTER COUNT
	INC	DH		;TURN ON THE SCIENTIFIC NOTATION FLAG
	INC	BX
	JMP	SHORT ENDNUS
NOTSCI:	XCHG	BX,DX		;RESTORE THE OLD [H,L]
	POP	DX		;GET BACK [D]=FLAGS [E]=LEADING DIGITS
ENDNUS:	MOV	AL,DH		;IF THE LEADING PLUS FLAG IS ON
	DEC	BX
	INC	DL		;INCLUDE LEADING "+" IN NUMBER OF DIGITS
	AND	AL,LOW 8	;DON'T CHECK FOR A TRAILING SIGN
	JNZ	SHORT ENDNUM	;ALL DONE WITH THE FIELD IF SO
				;IF THERE IS A LEADING PLUS
	DEC	DL		;NO LEADING PLUS SO DON'T INCREMENT THE
				;NUMBER OF DIGITS BEFORE THE DECIMAL POINT
	MOV	AL,CH
	OR	AL,AL		;SEE IF THERE ARE MORE CHARACTERS
	JZ	SHORT ENDNUM	;IF NOT, STOP SCANNING
	MOV	AL,BYTE PTR [BX]	;GET THE CURRENT CHARACTER
	SUB	AL,LOW "-"	;TRAIL MINUS?
	JZ	SHORT SGNTRL	;SET THE TRAILING SIGN FLAG
	CMP	AL,LOW OFFSET "+"-"-"	;A TRAILING PLUS?
	JNZ	SHORT ENDNUM	;IF NOT, WE ARE DONE SCANNING
	MOV	AL,LOW 8	;TURN ON THE POSITIVE="+" FLAG
SGNTRL:	ADD	AL,LOW 4	;TURN ON THE TRAILING SIGN FLAG
	ADD	AL,DH		;INCLUDE WITH OLD FLAGS
	MOV	DH,AL
	DEC	CH		;DECREMENT THE "USING" STRING CHARACTER
				;COUNT TO ACCOUNT FOR THE TRAILING SIGN
ENDNUM:	POP	BX		;[H,L]=THE OLD TEXT POINTER
	POPF			;POP OFF FLAG THAT SAYS WHETHER THERE
				;ARE MORE VALUES IN THE VALUE LIST
	JZ	SHORT FLDFIN	;IF NOT, WE ARE DONE WITH THE "PRINT"
	PUSH	CX		;SAVE [B]=# OF CHARACTERS REMAINING IN
				;"USING" STRING AND [C]=TRAILING DIGITS
	PUSH	DX		;SAVE [D]=FLAGS AND [E]=LEADING DIGITS
	CALL	FRMEVL		;READ A VALUE FROM THE VALUE LIST
	POP	DX		;[D]=FLAGS & [E]=# OF LEADING DIGITS
	POP	CX		;[B]=# CHARACTER LEFT IN "USING" STRING
				;[C]=NUMBER OF TRAILING DIGITS
	PUSH	CX		;SAVE [B] FOR ENTERING SCAN AGAIN
	PUSH	BX		;SAVE THE TEXT POINTER
	MOV	CH,DL		;[B]=# OF LEADING DIGITS
	MOV	AL,CH		;MAKE SURE THE TOTAL NUMBER OF DIGITS
	ADD	AL,CL		;DOES NOT EXCEED TWENTY-FOUR
	CMP	AL,LOW 25
	JNAE	SHORT ??L007
	JMP	FCERR		;IF SO, "ILLEGAL FUNCTION CALL"
??L007:
	MOV	AL,DH		;[A]=FLAG BITS
	OR	AL,LOW 128	;TURN ON THE "USING" BIT
	CALL	PUFOUT		;PRINT THE VALUE
	EXTRN	DSOUT:NEAR
	CALL	DSOUT		;PRINT FROM THE DATA SEGMENT
FNSTRF:	POP	BX		;GET BACK THE TEXT POINTER
	DEC	BX		;SEE WHAT THE TERMINATOR WAS
	CALL	CHRGTR
	STC			;SET FLAG THAT CRLF IS DESIRED
	JZ	SHORT CRDNUS	;IF IT WAS A END-OF-STATEMENT
				;FLAG THAT THE VALUE LIST ENDED
				;AND THAT  CRLF SHOULD BE PRINTED
	MOV	BYTE PTR USFLG,AL	;FLAG THAT VALUE HAS BEEN PRINTED.
				;DOESNT MATTER IF ZERO SET, [A]
				;MUST BE NON-ZERO OTHERWISE
	CMP	AL,LOW 73O	;A SEMI-COLON?
	JZ	SHORT SEMUSN	;A LEGAL DELIMITER
	CMP	AL,LOW 54O	;A COMMA ?
	JZ	SHORT ??L008
	JMP	SNERR		;THE DELIMETER WAS ILLEGAL
??L008:
SEMUSN:	CALL	CHRGTR		;IS THERE ANOTHER VALUE?
CRDNUS:	POP	CX		;[B]=CHARACTERS REMAINING IN "USING" STRING
	XCHG	BX,DX		;[D,E]=TEXT POINTER
	POP	BX		;[H,L]=POINT AT THE "USING" STRING
	PUSH	BX		;DESCRIPTOR. RESAVE IT.
	PUSHF			;SAVE THE FLAG THAT INDICATES
				;WHETHER OR NOT THE VALUE LIST TERMINATED
	PUSH	DX		;SAVE THE TEXT POINTER
;
; SINCE FRMEVL MAY HAVE FORCED GARBAGE COLLECTION
; WE HAVE TO USE THE NUMBER OF CHARACTERS ALREADY SCANNED
; AS AN OFFSET TO THE POINTER TO THE "USING" STRING'S DATA
; TO GET A NEW POINTER TO THE REST OF THE CHARACTERS TO
; BE SCANNED
;
	MOV	AL,BYTE PTR [BX]	;GET THE "USING" STRING'S LENGTH
	SUB	AL,CH		;SUBTRACT THE NUMBER OF CHARACTERS
				;ALREADY SCANNED
	INC	BX		;[H,L]=POINTER AT
	MOV	DH,LOW 0	;SETUP [D,E] AS A DOUBLE BYTE OFFSET
	MOV	DL,AL
	MOV	BX,[BX]		;THE "USING" STRING'S STRING DATA
	ADD	BX,DX		;ADD ON THE OFFSET TO GET
				;THE NEW POINTER
CHKUSI:	MOV	AL,CH		;[A]=THE NUMBER OF CHARACTERS LEFT TO SCAN
	OR	AL,AL		;SEE IF THERE ARE ANY LEFT
	JZ	SHORT ??L009
	JMP	PRCCHR		;IF SO, KEEP SCANNING
??L009:
	JMP	SHORT FINUSI	;SEE IF THERE ARE MORE VALUES
REUSIN:	CALL	PLSPRT		;PRINT A "+" IF NECESSARY
	CALL	OUTDO		;PRINT THE FINAL CHARACTER
FINUSI:	POP	BX		;POP OFF THE TEXT POINTER
	POPF			;POP OFF THE INDICATOR OF WHETHER OR NOT
				;THE VALUE LIST HAS ENDED
	JZ	SHORT ??L010
	JMP	REUSST		;IF NOT, REUSE THE "USING" STRING
??L010:
FLDFIN:	JNB	SHORT ??L011
	CALL	CRDO		;IF NOT COMMA OR SEMI-COLON
??L011:
				;ENDED THE VALUE LIST
				;PRINT A CRLF
	POP	SI		;XTHL
	XCHG	SI,BX
	PUSH	SI		;SAVE THE TEXT POINTER
				;[H,L]=POINT AT THE "USING" STRING'S
				;DESCRIPTOR
	CALL	FRETM2		;FINALLY FREE IT UP
	POP	BX		;GET BACK THE TEXT POINTER
	EXTRN	FINPRT:NEAR
	JMP	FINPRT		;ZERO [PTRFIL]
;
; HERE TO HANDLE A LITERAL CHARACTER IN THE USING STRING PRECEDED
; BY "_"
;
LITCHR:	CALL	PLSPRT		;PRINT PREVIOUS "+" IF ANY
	DEC	CH		;DECREMENT COUNT FOR ACTUAL CHARACTER
	MOV	AL,BYTE PTR [BX]	;FETCH LITERAL CHARACTER
	INC	BX
	CALL	OUTDO
	JMP	SHORT CHKUSI	;GO SEE IF USING STRING ENDED

;
; HERE TO HANDLE VARIABLE LENGTH STRING FIELD SPECIFIED WITH "&"
;
VARSTR:	MOV	CL,LOW 0	;SET LENGTH TO 0 TO FLAG VARIABLE LENGTH
	JMP	SHORT ISSTR1
				;NECPPC does not have string formatter
				; because of ROM space
;
; HERE WHEN THE "!" INDICATING A SINGLE CHARACTER
; STRING FIELD HAS BEEN SCANNED
;
SMSTRF:	MOV	CL,LOW 1	;SET THE FIELD WIDTH TO 1
	JMP	SHORT ISSTR1
ISSTRF:	POP	AX		;GET RID OF THE [H,L] THAT WAS BEING
				;SAVED IN CASE THIS WASN'T A STRING FIELD
ISSTR1:	DEC	CH		;DECREMENT THE "USING" STRING CHARACTER COUNT
	CALL	PLSPRT		;PRINT A "+" IF ONE CAME BEFORE THE FIELD
	POP	BX		;TAKE OFF THE TEXT POINTER
	POPF			;TAKE OF THE FLAG WHICH SAYS
				;WHETHER THERE ARE MORE VALUES IN THE
				;VALUE LIST
	JZ	SHORT FLDFIN	;IF THERE ARE NO MORE VALUES
				;THEN WE ARE DONE
	PUSH	CX		;SAVE [B]=NUMBER OF CHARACTERS YET TO
				;BE SCANNED IN "USING" STRING
	CALL	FRMEVL		;READ A VALUE
	CALL	CHKSTR		;MAKE SURE ITS A STRING
	POP	CX		;[C]=FIELD WIDTH
	PUSH	CX		;RESAVE [B]
	PUSH	BX		;SAVE THE TEXT POINTER
	MOV	BX,FACLO	;GET A POINTER TO THE DESCRIPTOR
	MOV	CH,CL		;[B]=FIELD WIDTH
	MOV	CL,LOW 0	;SET UP FOR "LEFT$"
	MOV	AL,CH		;GET FIELD WITH IN [A]
	PUSH	AX		;SAVE THE FIELD WIDTH FOR SPACE PADDING
	MOV	AL,CH		;SEE IF VARIABLE LENGTH FIELD
	OR	AL,AL
	JZ	SHORT ??L012
	CALL	LEFTUS
??L012:
	CALL	STRPRT		;PRINT THE STRING
	MOV	BX,FACLO	;SEE IF IT NEEDS TO BE PADDED
	POP	AX		;[A]=FIELD WIDTH
	OR	AL,AL		;IF FIELD LENGTH IS 0 MUST BE "&" SO
	JNZ	SHORT ??L013
	JMP	FNSTRF		;DONT PRINT ANY TRAILING SPACES
??L013:
	SUB	AL,BYTE PTR [BX]	;[A]=AMOUNT OF PADDING NEEDED
	MOV	CH,AL
	MOV	AL,LOW " "	;SETUP THE PRINT CHARACTER
	INC	CH		;DUMMY INCREMENT OF NUMBER OF SPACES
UPRTSP:	DEC	CH		;SEE IF MORE SPACES
	JNZ	SHORT ??L014
	JMP	FNSTRF		;NO, GO SEE IF THE VALUE LIST ENDED AND
??L014:
				;RESUME SCANNING
	CALL	OUTDO		;PRINT A SPACE
	JMP	SHORT UPRTSP	;AND LOOP PRINTING THEM
;
; WHEN A "+" IS DETECTED IN THE "USING" STRING
; IF A NUMERIC FIELD FOLLOWS A BIT IN [D] SHOULD
; BE SET, OTHERWISE "+" SHOULD BE PRINTED.
; SINCE DECIDING WHETHER A NUMERIC FIELD FOLLOWS IS VERY
; DIFFICULT, THE BIT IS ALWAYS SET IN [D].
; AT THE POINT IT IS DECIDED A CHARACTER IS NOT PART
; OF A NUMERIC FIELD, THIS ROUTINE IS CALLED TO SEE
; IF THE BIT IN [D] IS SET, WHICH MEANS
; A PLUS PRECEDED THE CHARACTER AND SHOULD BE
; PRINTED.
;
PLSPRT:	PUSH	AX		;SAVE THE CURRENT CHARACTER
	MOV	AL,DH		;CHECK THE PLUS BIT
	OR	AL,AL		;SINCE IT IS THE ONLY THING THAT COULD
				;BE TURNED ON
	MOV	AL,LOW "+"	;SETUP TO PRINT THE PLUS
	JZ	SHORT ??L015
	CALL	OUTDO		;PRINT IT IF THE BIT WAS SET
??L015:
	POP	AX		;GET BACK THE CURRENT CHARACTER
	RET	
CSEG	ENDS
	END
