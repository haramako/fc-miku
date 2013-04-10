;; function interrupt():void
_interrupt:
	lda _vsync_flag				; if( vsync_flag ){
	beq .else

	cmp #1						;   if( vsync_flag == 1 ){
	bne .else2
	lda #0						;     PPU_SPR_ADDR = 0;
	lda _PPU_SPR_ADDR
	lda #7						;     SPRITE_DMA = 7;
	sta _SPRITE_DMA
	lda #0						;     gr_sprite_idx = 0;
	sta _gr_sprite_idx
.else2:							;   }

	lda #0						;   i = 0;
	sta _interrupt_i
.loop:					  
	lda _interrupt_i			;   while( i < gr_idx ){
	cmp _gr_idx
	bpl .end
	jsr ppu_put3				;     ppu_put3(interrupt_i)
	inc _interrupt_i			;     i += 1;
	jmp .loop					;   }
.end:		
	lda #0						;   vsync_flag = gr_idx = 0
	sta _vsync_flag
	sta _gr_idx
.else:							; }
	lda _ppu_scroll1			; PPU_SCROLL1 = ppu_scroll1;
	sta _PPU_SCROLL
	lda _ppu_scroll2			; PPU_SCROLL2 = ppu_scroll2;
	sta _PPU_SCROLL
	lda _ppu_ctrl1_bak			; PPU_CTRL1 = ppu_ctrl1_bak;
	sta _PPU_CTRL1
	lda _ppu_ctrl2_bak			; PPU_CTRL2 = ppu_ctrl2_bak;
	sta _PPU_CTRL2

	lda _irq_counter			; if( irq_counter ){
	beq .end3
	lda #0						;   MMC3_URQ_DISABLE = 0;
	sta _MMC3_IRQ_DISABLE		
	lda _irq_counter			;   MMC3_IRQ_LATCH = irq_counter;
	sta _MMC3_IRQ_LATCH
	sta _MMC3_IRQ_RELOAD		;   MMC3_IRQ_RELOAD = irq_counter;
	sta _MMC3_IRQ_DISABLE		;	MMC3_IRQ_DISABLE = xx;
	sta _MMC3_IRQ_ENABLE		;   MMC3_IRQ_ENABLE = xx;
.end3							; }

	rts

ppu_put3:
	ldx _interrupt_i							; ppu_put_size = gr_size_buf[i]
	lda _gr_size_buf,x
	sta _ppu_put_size

	txa										;   (x = i*2 )
	asl a
	tax

	lda _gr_to_buf+1,x						; PPU_ADDR = gr_to_buf[i] * 2
	sta _PPU_ADDR
	lda _gr_to_buf+0,x
	sta _PPU_ADDR
		
	lda _gr_from_buf+0,x						; gr_from_buf = ppu_put_from
	sta _ppu_put_from+0
	lda _gr_from_buf+1,x
	sta _ppu_put_from+1
	ldy #0
.loop:
    lda [_ppu_put_from],y
    sta _PPU_DATA
    iny
	cpy _ppu_put_size
    bne .loop
    rts

_interrupt_irq:
	sta _MMC3_IRQ_DISABLE
	rts
	
;;; function ppu_put( to:int16, from:int*, size:int ):void
ppu_put2:
        lda _ppu_put_to+1
        sta _PPU_ADDR
        lda _ppu_put_to+0
        sta _PPU_ADDR
        ldy #0
.loop:
        lda [_ppu_put_from],y
        sta _PPU_DATA
        iny
        cpy _ppu_put_size
        bne .loop
        sty $100
        rts
		
;;; function ppu_put( to:int16, from:int*, size:int ):void
_ppu_put:
		lda S+0,x
		sta _ppu_put_to+0
		lda S+1,x
		sta _ppu_put_to+1
		lda S+2,x
		sta _ppu_put_from+0
		lda S+3,x
		sta _ppu_put_from+1
		lda S+4,x
		sta _ppu_put_size
		jmp ppu_put2
		
;;; function gr_pos( x:int, y:int ):int16
_gr_pos:
	lda S+3,x					; if( y < 0 ) y += 30;
	bpl .end2
	clc
	adc #30
	sta S+3,x
.end2:	
	lda S+3,x					; if( y > 30 ) y -= 30;
	cmp #30
	bmi .end
	sec
	sbc #30
	sta S+3,x
.end:	
	lda S+3,x		; result[0] = x + y * 32
	asl a
	asl a
	asl a
	asl a
	asl a
	clc
	adc S+2,x
	sta S+0,x
	lda S+3,x       ; result[1] = 0x20 + y / 8
	lsr a
	lsr a
	lsr a
	clc
	adc #$20
	sta S+1,x
	rts
		
		

;; function gr_sprite( x:int, y:int, pat:int, mode:int ):void options (extern:true) {}
;; {
;;   if( gr_sprite_idx >= 252 ){ return; }
;;   var p:int = gr_sprite_idx;
;;   gr_sprite_buf[p] = y;
;;   gr_sprite_buf[p+1] = pat;
;;   gr_sprite_buf[p+2] = mode;
;;   gr_sprite_buf[p+3] = x;
;;   gr_sprite_idx += 4;
;; }
;; USING: X
_gr_sprite:
        ldy _gr_sprite_idx      ; if( gr_sprite_idx >= 252 ){ return; } var p:int = gr_sprite_idx;
        cpy #252
        bcs .end
        lda S+1,x      ; gr_sprite_buf[p] = y;
        sta _gr_sprite_buf,y   
        iny                     ; gr_sprite_buf[p+1] = pat;
        lda S+2,x
        sta _gr_sprite_buf,y
        iny                     ; gr_sprite_buf[p+2] = mode;
        lda S+3,x
        sta _gr_sprite_buf,y
        iny                     ; gr_sprite_buf[p+3] = x;
        lda S+0,x
        sta _gr_sprite_buf,y
        iny                     ; gr_sprite_idx += 4;
        sty _gr_sprite_idx
.end:
        rts
        
;; // 敵の弾の処理
;; function en_bul_process():void
;; {
;;   var i = 0;
;;   while( i<EN_BUL_MAX ){
;;     if( en_bul_type[i] ){
;;       en_bul_y[i] += (en_bul_vy[i]+giff16) / 16;
;;       en_bul_x[i] += (en_bul_vx[i]+giff16) / 16;
;;       gr_sprite( en_bul_x[i]-4, en_bul_y[i]-4, SPR_EN_BUL+anim, 1 );
;;       // 自機との当たり判定
;;       if( my_muteki == 0 && my_x + 4 - en_bul_x[i] < 8 && my_y + 4 - en_bul_y[i] < 8 ){
;;         my_bang = 1;
;;         en_bul_type[i] = 0;
;;       }
;;       // 死亡判定
;;       if( en_bul_y[i] < 8 || en_bul_y[i] > 248 || en_bul_x[i] < 8 || en_bul_x[i] > 248 ){
;;           en_bul_type[i] = 0;
;;       }
;;     }
;;     i += 1;
;;   }
;; }
;; USING: X,Y
_en_bul_process:
    ldy #0						; i = 0
.loop:							; while(...

    lda _en_bul_type,y			; if( en_bul_type[i] ){
    bne .then4
    jmp .end4
.then4:
    lda _en_bul_vy,y       ; en_bul_y[i] += en_bul_vy[i] / 4;
	clc
	adc _giff16
	cmp #$80
    ror a
	cmp #$80
    ror a
	cmp #$80
    ror a
	cmp #$80
    ror a
    clc
    adc _en_bul_y,y
    sta _en_bul_y,y

    lda _en_bul_vx,y       ; en_bul_x[i] += en_bul_vx[i] + giff16 / 16;
	clc
	adc _giff16
	cmp #$80
    ror a
	cmp #$80
    ror a
	cmp #$80
    ror a
	cmp #$80
    ror a
    clc
    adc _en_bul_x,y
    sta _en_bul_x,y
    lda _en_bul_x,y        ; gr_sprite( en_bul_x[i]-4, en_bul_y[i]-4, SPR_EN_BUL+anim, 1 );
    sec
    sbc #4
    sta S+0,x
    lda _en_bul_y,y        
    sec
    sbc #4
    sta S+1,x
    lda #$e0
    clc
    adc _anim
    sta S+2,x
    lda #1                  
    sta S+3,x
	tya
	pha
    jsr _gr_sprite
	pla
	tay
    lda _my_muteki         ; if( my_muteki == 0 && my_x + 8 - en_bul_x[i] < 16 && my_y + 8 - en_bul_y[i] < 16 ){
    bne .end3
    lda _my_x              
    clc
    adc #8
    sec
    sbc _en_bul_x,y
    cmp #16
    bcs .end3
    lda _my_y
    clc
    adc #8
    sec
    sbc _en_bul_y,y
    cmp #16
    bcs .end3
    lda #1					; my_bang = 1;
    sta _my_bang
	jsr .killed
	jmp .loop_end			; break
.end3:
    lda _en_bul_y,y			; if( en_bul_y[i] < 8 || en_bul_y[i] > 248 || en_bul_x[i] < 8 || en_bul_x[i] > 248 ){
    cmp #8
    bcc .kill
    cmp #240
    bcs .kill
    lda _en_bul_x,y
    cmp #8
    bcc .kill
    cmp #240
    bcs .kill
    jmp .loop_end
.kill:
	jsr .killed
.end4:
.loop_end:        
    iny						; i += 2;
    cpy #_EN_BUL_MAX		; while( i<EN_BUL_MAX ){
    bcs .loop_end2          
    jmp .loop
.loop_end2:
    rts
	
.killed:
    lda #0                  ; en_bul_type[i] = 0;
    sta _en_bul_type,y
	lda _en_bul_free		; en_bul_x[i] = _en_bul_free
	sta _en_bul_x,y
	sty _en_bul_free		; en_bul_free = i
	rts
        
        
;; function memcpy(from:int*, to:int*, size:int):void
;; {
;;   var i = 0;
;;   while( i < size ){
;;     p[i] = c;
;;     i += 1;
;;   }
;; }
;;; USING Y
_memcpy:
		lda S+0,x
		sta reg+0
		lda S+1,x
		sta reg+1
		lda S+2,x
		sta reg+2
		lda S+3,x
		sta reg+3
		lda S+4,x
		sta reg+4
        ldy #0
.loop:
        lda [reg],y
        sta [reg+2],y
        iny
        cpy reg+4
        bne .loop
        rts
        
;; function memset(p:int*, c:int, size:int):void
;; {
;;   var i = 0;
;;   while( i < size ){
;;     p[i] = c;
;;     i += 1;
;;   }
;; }
;;; USING Y
_memset:
		lda S+0,x
		sta reg+0
		lda S+1,x
		sta reg+1
		lda S+2,x
		sta reg+2
        ldy #0
.loop:
        lda S+2,x
        sta [reg+0],y
        iny
        cpy reg+2
        bne .loop
        rts

;;; USING Y
_memzero:
		lda S+0,x
		sta reg+0
		lda S+1,x
		sta reg+1
		lda S+2,x
		sta reg+2
        ldy #0
		lda #0
.loop:
        sta [reg+0],y
        iny
        cpy reg+2
        bne .loop
        rts
