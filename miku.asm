;; function interrupt():void
.proc _interrupt
	lda _util_vsync_flag				; if( vsync_flag ){
	beq @else

	cmp #1						;   if( vsync_flag == 1 ){
	bne @else2
	lda #0						;     PPU_SPR_ADDR = 0;
	lda _nes_PPU_SPR_ADDR
	lda #7						;     SPRITE_DMA = 7;
	sta _nes_SPRITE_DMA
	lda #0						;     gr_sprite_idx = 0;
	sta _util_gr_sprite_idx
@else2:							;   }

	lda #0						;   i = 0;
	sta _util_interrupt_i
@loop:					  
	lda _util_interrupt_i			;   while( i < gr_idx ){
	cmp _util_gr_idx
	bpl @end
	jsr ppu_put3				;     ppu_put3(interrupt_i)
	inc _util_interrupt_i			;     i += 1;
	jmp @loop					;   }
@end:		
	lda #0						;   vsync_flag = gr_idx = 0
	sta _util_vsync_flag
	sta _util_gr_idx
@else:							; }
	lda _util_ppu_scroll1			; PPU_SCROLL1 = ppu_scroll1;
	sta _nes_PPU_SCROLL
	lda _util_ppu_scroll2			; PPU_SCROLL2 = ppu_scroll2;
	sta _nes_PPU_SCROLL
	lda _util_ppu_ctrl1_bak			; PPU_CTRL1 = ppu_ctrl1_bak;
	sta _nes_PPU_CTRL1
	lda _util_ppu_ctrl2_bak			; PPU_CTRL2 = ppu_ctrl2_bak;
	sta _nes_PPU_CTRL2

	lda _util_irq_counter			; if( irq_counter ){
	beq @end3
	lda #0						;   MMC3_URQ_DISABLE = 0;
	sta _mmc3_IRQ_DISABLE		
	lda _util_irq_counter			;   MMC3_IRQ_LATCH = irq_counter;
	sta _mmc3_IRQ_LATCH
	sta _mmc3_IRQ_RELOAD		;   MMC3_IRQ_RELOAD = irq_counter;
	sta _mmc3_IRQ_DISABLE		;	MMC3_IRQ_DISABLE = xx;
	sta _mmc3_IRQ_ENABLE		;   MMC3_IRQ_ENABLE = xx;
@end3:							; }

	rts
.endproc

.proc ppu_put3
	ldx _util_interrupt_i							; ppu_put_size = gr_size_buf[i]
	lda _util_gr_size_buf,x
	sta _util_ppu_put_size

	txa										;   (x = i*2 )
	asl a
	tax

	lda _util_gr_to_buf+1,x						; PPU_ADDR = gr_to_buf[i] * 2
	sta _nes_PPU_ADDR
	lda _util_gr_to_buf+0,x
	sta _nes_PPU_ADDR
		
	lda _util_gr_from_buf+0,x						; gr_from_buf = ppu_put_from
	sta _util_ppu_put_from+0
	lda _util_gr_from_buf+1,x
	sta _util_ppu_put_from+1
	ldy #0
@loop:
    lda (_util_ppu_put_from),y
    sta _nes_PPU_DATA
    iny
	cpy _util_ppu_put_size
    bne @loop
    rts
.endproc

.proc _interrupt_irq
	sta _mmc3_IRQ_DISABLE
	rts
.endproc
	
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
.proc _miku_en_bul_process
    ldy #0						; i = 0
@loop:							; while(...

    lda _en_bul_type,y			; if( en_bul_type[i] ){
    bne @then4
    jmp @end4
@then4:
    lda _en_bul_vy,y       ; en_bul_y[i] += en_bul_vy[i] / 4;
	clc
	adc _common_giff16
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
	adc _common_giff16
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
    adc _common_anim
    sta S+2,x
    lda #1                  
    sta S+3,x
	tya
	pha
    jsr _util_gr_sprite
	pla
	tay
    lda _common_my_muteki         ; if( my_muteki == 0 && my_x + 8 - en_bul_x[i] < 16 && my_y + 8 - en_bul_y[i] < 16 ){
    bne @end3
    lda _common_my_x              
    clc
    adc #8
    sec
    sbc _en_bul_x,y
    cmp #16
    bcs @end3
    lda _common_my_y
    clc
    adc #8
    sec
    sbc _en_bul_y,y
    cmp #16
    bcs @end3
    lda #1					; my_bang = 1;
    sta _common_my_bang
	jsr @killed
	jmp @loop_end			; break
@end3:
    lda _en_bul_y,y			; if( en_bul_y[i] < 8 || en_bul_y[i] > 248 || en_bul_x[i] < 8 || en_bul_x[i] > 248 ){
    cmp #8
    bcc @kill
    cmp #240
    bcs @kill
    lda _en_bul_x,y
    cmp #8
    bcc @kill
    cmp #240
    bcs @kill
    jmp @loop_end
@kill:
	jsr @killed
@end4:
@loop_end:        
    iny						; i += 2;
    cpy #_en_BUL_MAX		; while( i<EN_BUL_MAX ){
    bcs @loop_end2          
    jmp @loop
@loop_end2:
    rts
	
@killed:
    lda #0                  ; en_bul_type[i] = 0;
    sta _en_bul_type,y
	lda _en_bul_free		; en_bul_x[i] = _en_bul_free
	sta _en_bul_x,y
	sty _en_bul_free		; en_bul_free = i
	rts
.endproc        
        
